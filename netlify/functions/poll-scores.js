// netlify/functions/poll-scores.js
// Scheduled function — runs every 10 minutes via netlify.toml cron.
// Fetches today's World Cup scores from API-Football and writes them
// directly to Supabase matches table (home_score, away_score, status).
// Does NOT set confirmed=true — that requires admin action.

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://jrdjdqjepffdcjdfuarc.supabase.co';

const TEAM_MAP = {
  'Korea Republic':         'South Korea',
  'Bosnia and Herzegovina': 'Bosnia/Herzeg',
  'Czech Republic':         'Czech Rep',
  'United States':          'USA',
  'IR Iran':                'Iran',
  'Côte d\'Ivoire':         'Ivory Coast',
  'Republic of Ireland':    'Ireland',
};

function normalise(name) {
  return TEAM_MAP[name] || name;
}

exports.handler = async function(event, context) {
  const API_KEY      = process.env.API_FOOTBALL_KEY;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY; // service role key — add to Netlify env vars

  if (!API_KEY || !SUPABASE_KEY) {
    console.error('Missing env vars: API_FOOTBALL_KEY or SUPABASE_SERVICE_KEY');
    return { statusCode: 500, body: 'Missing env vars' };
  }

  const db = createClient(SUPABASE_URL, SUPABASE_KEY);

  // Only run during match windows: 11:00–23:30 UTC
  const nowUTC = new Date();
  const hour = nowUTC.getUTCHours();
  if (hour < 11 || hour >= 24) {
    console.log('Outside match window, skipping poll.');
    return { statusCode: 200, body: 'Outside window' };
  }

  const today = nowUTC.toISOString().split('T')[0];
  const url = `https://v3.football.api-sports.io/fixtures?league=1&season=2026&date=${today}`;

  let fixtures = [];
  try {
    const res = await fetch(url, { headers: { 'x-apisports-key': API_KEY } });
    const data = await res.json();
    fixtures = data.response || [];
  } catch (err) {
    console.error('API fetch error:', err.message);
    return { statusCode: 500, body: err.message };
  }

  if (!fixtures.length) {
    console.log('No fixtures today.');
    return { statusCode: 200, body: 'No fixtures' };
  }

  // Load today's DB matches (with team names for matching)
  const tomorrow = new Date(nowUTC); tomorrow.setUTCDate(nowUTC.getUTCDate() + 1);
  const tomorrowStr = tomorrow.toISOString().split('T')[0];

  const { data: dbMatches, error: dbErr } = await db.from('matches')
    .select('id, confirmed, home_team:teams!matches_home_team_id_fkey(name), away_team:teams!matches_away_team_id_fkey(name)')
    .gte('kickoff', today + 'T00:00:00Z')
    .lt('kickoff', tomorrowStr + 'T00:00:00Z');

  if (dbErr) {
    console.error('Supabase error:', dbErr.message);
    return { statusCode: 500, body: dbErr.message };
  }

  // Index DB matches by sorted team pair
  const dbByTeams = {};
  (dbMatches || []).forEach(m => {
    if (!m.home_team || !m.away_team) return;
    const key = [m.home_team.name, m.away_team.name].sort().join('|');
    dbByTeams[key] = m;
  });

  let updated = 0;
  for (const f of fixtures) {
    const apiHome  = normalise(f.teams?.home?.name || '');
    const apiAway  = normalise(f.teams?.away?.name || '');
    const homeGoals = f.goals?.home;
    const awayGoals = f.goals?.away;
    const apiStatus = f.fixture?.status?.short || '';

    const isFT   = apiStatus === 'FT';
    const isLive = ['1H','2H','HT','ET','P'].includes(apiStatus);

    if (!isFT && !isLive) continue; // skip NS/PST/etc
    if (homeGoals === null || awayGoals === null) continue;

    const key = [apiHome, apiAway].sort().join('|');
    const dbMatch = dbByTeams[key];
    if (!dbMatch) { console.warn('No DB match for:', apiHome, 'vs', apiAway); continue; }
    if (dbMatch.confirmed) { console.log('Already confirmed, skipping:', apiHome, 'vs', apiAway); continue; }

    const newStatus = isFT ? 'complete' : 'live';
    const { error } = await db.from('matches').update({
      home_score: homeGoals,
      away_score: awayGoals,
      status: newStatus
    }).eq('id', dbMatch.id);

    if (error) { console.error('Update error for', apiHome, 'vs', apiAway, ':', error.message); }
    else { updated++; console.log('Updated:', apiHome, homeGoals, '-', awayGoals, apiAway, '(' + newStatus + ')'); }
  }

  console.log('Poll complete. Updated', updated, 'match(es).');
  return { statusCode: 200, body: 'Updated ' + updated };
};
