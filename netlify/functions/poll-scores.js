// netlify/functions/poll-scores.js
// Scheduled function — runs every 10 minutes via netlify.toml cron.
// Fetches live/finished World Cup scores from football-data.org
// and writes provisional scores to Supabase (unconfirmed).
// No npm dependencies — plain fetch throughout.

const SUPABASE_URL = 'https://jrdjdqjepffdcjdfuarc.supabase.co';

// football-data.org name → your DB name (only mismatches needed)
const TEAM_MAP = {
  'United States':       'USA',
  'Bosnia-Herzegovina':  'Bosnia/Herzeg',
  'Czechia':             'Czech Rep',
  'Congo DR':            'DR Congo',
  'Cape Verde Islands':  'Cape Verde',
};

function normalise(name) {
  return TEAM_MAP[name] || name;
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
  const FD_KEY        = process.env.FOOTBALL_DATA_KEY;
  const SUPABASE_KEY  = process.env.SUPABASE_SERVICE_KEY;

  if (!FD_KEY || !SUPABASE_KEY) {
    console.error('Missing env vars');
    return { statusCode: 500, body: 'Missing env vars' };
  }

  // Only run during match windows: 11:00–23:59 UTC
  const nowUTC = new Date();
  const hour = nowUTC.getUTCHours();
  if (hour < 11) {
    console.log('Outside match window, skipping.');
    return { statusCode: 200, body: 'Outside window' };
  }

  const today = nowUTC.toISOString().split('T')[0];
  const tomorrow = new Date(nowUTC);
  tomorrow.setUTCDate(nowUTC.getUTCDate() + 1);
  const tomorrowStr = tomorrow.toISOString().split('T')[0];

  // Fetch from football-data.org
  let fixtures = [];
  try {
    const res = await fetch(
      `https://api.football-data.org/v4/competitions/WC/matches?dateFrom=${today}&dateTo=${today}`,
      { headers: { 'X-Auth-Token': FD_KEY } }
    );
    if (!res.ok) throw new Error('football-data.org returned HTTP ' + res.status);
    const data = await res.json();
    fixtures = data.matches || [];
  } catch (err) {
    console.error('football-data.org error:', err.message);
    return { statusCode: 500, body: err.message };
  }

  if (!fixtures.length) {
    console.log('No fixtures today.');
    return { statusCode: 200, body: 'No fixtures' };
  }

  // Fetch today's unconfirmed matches from Supabase
  let dbMatches = [];
  try {
    dbMatches = await supabaseGet(
      'matches?select=id,confirmed,home_team:teams!matches_home_team_id_fkey(name),away_team:teams!matches_away_team_id_fkey(name)' +
      '&kickoff=gte.' + today + 'T00:00:00Z' +
      '&kickoff=lt.'  + tomorrowStr + 'T00:00:00Z',
      SUPABASE_KEY
    );
  } catch (err) {
    console.error('Supabase fetch error:', err.message);
    return { statusCode: 500, body: err.message };
  }

  // Index by sorted team pair
  const dbByTeams = {};
  dbMatches.forEach(m => {
    if (!m.home_team || !m.away_team) return;
    const key = [m.home_team.name, m.away_team.name].sort().join('|');
    dbByTeams[key] = m;
  });

  // football-data.org status mapping
  // IN_PLAY, PAUSED → live
  // FINISHED        → complete
  // TIMED, SCHEDULED → skip
  function mapStatus(fdStatus) {
    if (fdStatus === 'FINISHED')               return 'complete';
    if (fdStatus === 'IN_PLAY' || fdStatus === 'PAUSED') return 'live';
    return null; // not started or unknown — skip
  }

  let updated = 0;
  for (const f of fixtures) {
    const apiHome   = normalise(f.homeTeam?.name || '');
    const apiAway   = normalise(f.awayTeam?.name || '');
    const homeGoals = f.score?.fullTime?.home;
    const awayGoals = f.score?.fullTime?.away;
    const fdStatus  = f.status || '';
    const dbStatus  = mapStatus(fdStatus);

    if (!dbStatus) continue;
    if (homeGoals === null || homeGoals === undefined) continue;
    if (awayGoals === null || awayGoals === undefined) continue;

    const key     = [apiHome, apiAway].sort().join('|');
    const dbMatch = dbByTeams[key];

    if (!dbMatch) {
      console.warn('No DB match for:', apiHome, 'vs', apiAway);
      continue;
    }
    if (dbMatch.confirmed) {
      console.log('Already confirmed, skipping:', apiHome, 'vs', apiAway);
      continue;
    }

    try {
      await supabasePatch(
        'matches?id=eq.' + dbMatch.id,
        SUPABASE_KEY,
        {
          home_score:       homeGoals,
          away_score:       awayGoals,
          status:           dbStatus,
          elapsed_minutes:  dbStatus === 'live' ? (f.minute ?? null) : null
        }
      );
      updated++;
      console.log('Updated:', apiHome, homeGoals, '-', awayGoals, apiAway, '(' + fdStatus + ')');
    } catch (err) {
      console.error('Update error for', apiHome, 'vs', apiAway, ':', err.message);
    }
  }

  console.log('Poll complete. Updated', updated, 'match(es).');
  return { statusCode: 200, body: 'Updated ' + updated };
};
