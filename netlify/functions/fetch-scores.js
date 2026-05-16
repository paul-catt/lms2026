// netlify/functions/fetch-scores.js
// Proxies API-Football fixtures to the admin panel.
// Keeps the API key server-side.
//
// Prod: called with no params — defaults to World Cup (league=1, season=2026)
// Test: ?league=39&season=2024 for Premier League etc.

exports.handler = async function(event, context) {
  const API_KEY = process.env.API_FOOTBALL_KEY;

  if (!API_KEY) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'API_FOOTBALL_KEY not configured in Netlify env vars.' })
    };
  }

  const params  = event.queryStringParameters || {};
  const league  = params.league  || '1';
  const season  = params.season  || '2026';
  const dateParam = params.date;

  const today = dateParam || new Date().toISOString().split('T')[0];

  const url = `https://v3.football.api-sports.io/fixtures?league=${league}&season=${season}&date=${today}`;

  try {
    const res = await fetch(url, {
      headers: {
        'x-apisports-key': API_KEY
      }
    });

    if (!res.ok) {
      return {
        statusCode: res.status,
        body: JSON.stringify({ error: 'API-Football returned HTTP ' + res.status })
      };
    }

    const data = await res.json();

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify(data)
    };

  } catch (err) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: err.message })
    };
  }
};
