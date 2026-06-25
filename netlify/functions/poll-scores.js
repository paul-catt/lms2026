// netlify/functions/poll-scores.js
// Scheduled function — runs every minute via netlify.toml cron.
// Uses football-data.org (same API as the admin Live Scores tab).
// No npm dependencies — plain fetch for both football-data and Supabase REST.
//
// Writes to matches (unconfirmed only):
//   home_score / away_score  — current or final score (after ET if applicable;
//                              for pens, the level after-120 score)
//   status                   — 'live' while in play, 'complete' when finished
//   api_status               — IN_PLAY | PAUSED | FINISHED | FINISHED_ET |
//                              FINISHED_PENS_HOME | FINISHED_PENS_AWAY | FINISHED_PENS
//   elapsed_minutes          — match minute if the API provides it, else null
//
// Requires: ALTER TABLE matches ADD COLUMN IF NOT EXISTS api_status text;
// Env vars: FOOTBALL_DATA_KEY, SUPABASE_SERVICE_KEY

const SUPABASE_URL = 'https://jrdjdqjepffdcjdfuarc.supabase.co';

// football-data.org name → DB name (mismatches only)
// Keep in sync with LIVE_SCORES_TEAM_MAP in admin.html
const TEAM_MAP = {
  'United States':       'USA',
  'Bosnia-Herzegovina':  'Bosnia/Herzeg',
  'Czechia':             'Czech Rep',
  'Congo DR':            'DR Congo',
  'Cape Verde Islands':  'Cape Verde',
  "Côte d'Ivoire":       'Ivory Coast',
  'Cura\u00e7ao':        'Cura\u00e7ao',
};

function normalise(name) {
  return TEAM_MAP[name] || name;
}

function isoDate(d) {
  return d.toISOString().split('T')[0];
}

async function supabaseGet(path, key) {
  const res = await fetch(SUPABASE_URL + '/rest/v1/' + path, {
    headers: {
      'apikey': key,
      'Authorization': 'Bearer ' + key,
      'Content-Type': 'application/json'
    }
  });
  if (!res.ok) throw new Error('Supabase GET failed: ' + res.status);
  return res.json();
}

async function supabasePatch(path, key, body) {
  const res = await fetch(SUPABASE_URL + '/rest/v1/' + path, {
    method: 'PATCH',
    headers: {
      'apikey': key,
      'Authorization': 'Bearer ' + key,
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal'
    },
    body: JSON.stringify(body)
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error('Supabase PATCH failed: ' + res.status + ' ' + text);
  }
}

exports.handler = async function(event, context) {
  const API_KEY      = process.env.FOOTBALL_DATA_KEY;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;

  if (!API_KEY || !SUPABASE_KEY) {
    console.error('Missing env vars (FOOTBALL_DATA_KEY / SUPABASE_SERVICE_KEY)');
    return { statusCode: 500, body: 'Missing env vars' };
  }

  const now = new Date();
  const yesterday = new Date(now); yesterday.setUTCDate(now.getUTCDate() - 1);
  const tomorrow  = new Date(now); tomorrow.setUTCDate(now.getUTCDate() + 1);

  // ── 1. DB matches in a 2-day window (yesterday→today covers games running past midnight UTC)
  let dbMatches = [];
  try {
    dbMatches = await supabaseGet(
      'matches?select=id,confirmed,kickoff,home_team:teams!matches_home_team_id_fkey(name),away_team:teams!matches_away_team_id_fkey(name)' +
      '&kickoff=gte.' + isoDate(yesterday) + 'T00:00:00Z' +
      '&kickoff=lt.' + isoDate(tomorrow) + 'T00:00:00Z',
      SUPABASE_KEY
    );
  } catch (err) {
    console.error('Supabase fetch error:', err.message);
    return { statusCode: 500, body: err.message };
  }

  // ── 2. Early exit: only hit the API if an unconfirmed match could plausibly
  // be in play or recently finished (kicked off in the last 5 hours).
  const nowMs = now.getTime();
  const FIVE_HOURS = 5 * 60 * 60 * 1000;
  const relevant = dbMatches.filter(m =>
    !m.confirmed &&
    m.kickoff &&
    new Date(m.kickoff).getTime() <= nowMs + 2 * 60 * 1000 &&
    new Date(m.kickoff).getTime() >= nowMs - FIVE_HOURS
  );
  if (relevant.length === 0) {
    console.log('No unconfirmed matches in the live window — skipping API call.');
    return { statusCode: 200, body: 'Idle' };
  }

  // ── 3. Fetch from football-data.org (yesterday→tomorrow to dodge timezone edges)
  let fixtures = [];
  try {
    const url = 'https://api.football-data.org/v4/competitions/WC/matches' +
                '?dateFrom=' + isoDate(yesterday) + '&dateTo=' + isoDate(tomorrow);
    const res = await fetch(url, { headers: { 'X-Auth-Token': API_KEY } });
    if (!res.ok) {
      const text = await res.text();
      console.error('football-data.org HTTP', res.status, text);
      return { statusCode: res.status, body: 'football-data error' };
    }
    const data = await res.json();
    fixtures = data.matches || [];
  } catch (err) {
    console.error('football-data error:', err.message);
    return { statusCode: 500, body: err.message };
  }

  if (!fixtures.length) {
    console.log('No fixtures returned.');
    return { statusCode: 200, body: 'No fixtures' };
  }

  // ── 4. Index DB matches by sorted team-name pair
  const dbByTeams = {};
  dbMatches.forEach(m => {
    if (!m.home_team || !m.away_team) return;
    const key = [m.home_team.name, m.away_team.name].sort().join('|');
    dbByTeams[key] = m;
  });

  // ── 5. Walk fixtures, write live/final scores for unconfirmed matches
  let updated = 0;
  for (const f of fixtures) {
    const fdStatus = f.status || '';
    const isLive     = fdStatus === 'IN_PLAY' || fdStatus === 'PAUSED';
    const isFinished = fdStatus === 'FINISHED';
    if (!isLive && !isFinished) continue;

    const apiHome = normalise(f.homeTeam?.name || '');
    const apiAway = normalise(f.awayTeam?.name || '');

    // Score: fullTime carries the running score while live and the final
    // (incl. ET) when finished. For pens it's the level after-120 score.
    const homeGoals = f.score?.fullTime?.home;
    const awayGoals = f.score?.fullTime?.away;
    if (homeGoals === null || homeGoals === undefined) continue;
    if (awayGoals === null || awayGoals === undefined) continue;

    const key = [apiHome, apiAway].sort().join('|');
    const dbMatch = dbByTeams[key];
    if (!dbMatch) { console.warn('No DB match for:', apiHome, 'vs', apiAway); continue; }
    if (dbMatch.confirmed) continue;

    // api_status for the client live layer
    let apiStatus;
    if (isFinished) {
      const duration = f.score?.duration || 'REGULAR';
      if (duration === 'PENALTY_SHOOTOUT') {
        const w = f.score?.winner;
        apiStatus = w === 'HOME_TEAM' ? 'FINISHED_PENS_HOME'
                  : w === 'AWAY_TEAM' ? 'FINISHED_PENS_AWAY'
                  : 'FINISHED_PENS';
      } else if (duration === 'EXTRA_TIME') {
        apiStatus = 'FINISHED_ET';
      } else {
        apiStatus = 'FINISHED';
      }
    } else {
      apiStatus = fdStatus; // IN_PLAY or PAUSED
    }

    // Minute if the API provides it on this plan; null otherwise
    const minute = (typeof f.minute === 'number') ? f.minute : null;

    try {
      await supabasePatch(
        'matches?id=eq.' + dbMatch.id,
        SUPABASE_KEY,
        {
          home_score: homeGoals,
          away_score: awayGoals,
          status: isFinished ? 'complete' : 'live',
          api_status: apiStatus,
          elapsed_minutes: isFinished ? null : minute
        }
      );
      updated++;
      console.log('Updated:', apiHome, homeGoals, '-', awayGoals, apiAway, apiStatus, minute !== null ? minute + "'" : '');
    } catch (err) {
      console.error('Update error for', apiHome, 'vs', apiAway, ':', err.message);
    }
  }

  console.log('Poll complete. Updated', updated, 'match(es).');
  return { statusCode: 200, body: 'Updated ' + updated };
};
