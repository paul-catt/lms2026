// netlify/functions/poll-scores.js
// Scheduled function — runs every 10 minutes via netlify.toml cron.
// No npm dependencies — uses plain fetch for both API-Football and Supabase REST API.

const SUPABASE_URL = 'https://jrdjdqjepffdcjdfuarc.supabase.co';

const TEAM_MAP = {
  'Korea Republic':         'South Korea',
  'Bosnia and Herzegovina': 'Bosnia/Herzeg',
  'Czech Republic':         'Czech Rep',
  'United States':          'USA',
  'IR Iran':                'Iran',
  "Cote d'Ivoire":          'Ivory Coast',
  'Republic of Ireland':    'Ireland',
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
  const API_KEY      = process.env.API_FOOTBALL_KEY;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;

  if (!API_KEY || !SUPABASE_KEY) {
    console.error('Missing env vars');
    return { statusCode: 500, body: 'Missing env vars' };
  }

  // Only run during match windows: 11:00-23:59 UTC
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

  // Fetch from API-Football
  let fixtures = [];
  try {
    const res = await fetch(
      'https://v3.football.api-sports.io/fixtures?league=1&season=2026&date=' + today,
      { headers: { 'x-apisports-key': API_KEY } }
    );
    const data = await res.json();
    fixtures = data.response || [];
  } catch (err) {
    console.error('API-Football error:', err.message);
    return { statusCode: 500, body: err.message };
  }

  if (!fixtures.length) {
    console.log('No fixtures today.');
    return { statusCode: 200, body: 'No fixtures' };
  }

  // Fetch today's matches from Supabase
  let dbMatches = [];
  try {
    dbMatches = await supabaseGet(
      'matches?select=id,confirmed,home_team:teams!matches_home_team_id_fkey(name),away_team:teams!matches_away_team_id_fkey(name)' +
      '&kickoff=gte.' + today + 'T00:00:00Z' +
      '&kickoff=lt.' + tomorrowStr + 'T00:00:00Z',
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

  let updated = 0;
  for (const f of fixtures) {
    const apiHome   = normalise(f.teams?.home?.name || '');
    const apiAway   = normalise(f.teams?.away?.name || '');
    const homeGoals = f.goals?.home;
    const awayGoals = f.goals?.away;
    const apiStatus = f.fixture?.status?.short || '';
    const elapsed   = f.fixture?.status?.elapsed ?? null;

    const isFT   = apiStatus === 'FT' || apiStatus === 'FT_PEN';
    const isLive = ['1H','2H','HT','ET','BT','P'].includes(apiStatus);

    if (!isFT && !isLive) continue;
    if (homeGoals === null || homeGoals === undefined) continue;
    if (awayGoals === null || awayGoals === undefined) continue;

    const key = [apiHome, apiAway].sort().join('|');
    const dbMatch = dbByTeams[key];
    if (!dbMatch) { console.warn('No DB match for:', apiHome, 'vs', apiAway); continue; }
    if (dbMatch.confirmed) { console.log('Already confirmed, skipping:', apiHome, 'vs', apiAway); continue; }

    try {
      await supabasePatch(
        'matches?id=eq.' + dbMatch.id,
        SUPABASE_KEY,
        {
          home_score: homeGoals,
          away_score: awayGoals,
          status: isFT ? 'complete' : 'live',
          elapsed_minutes: isFT ? null : elapsed
        }
      );
      updated++;
      console.log('Updated:', apiHome, homeGoals, '-', awayGoals, apiAway, elapsed ? elapsed + '\'' : '');
    } catch (err) {
      console.error('Update error for', apiHome, 'vs', apiAway, ':', err.message);
    }
  }

  console.log('Poll complete. Updated', updated, 'match(es).');
  return { statusCode: 200, body: 'Updated ' + updated };
};
