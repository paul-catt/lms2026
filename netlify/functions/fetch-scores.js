// netlify/functions/fetch-scores.js
// Proxies API-Football today's World Cup fixtures to the admin panel.
// Keeps the API key server-side. Called by admin.html Live Scores tab.

exports.handler = async function(event, context) {
  const API_KEY = process.env.API_FOOTBALL_KEY;

  if (!API_KEY) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'API_FOOTBALL_KEY not configured in Netlify env vars.' })
    };
  }

  // Today's date in YYYY-MM-DD (UTC)
  const today = new Date().toISOString().split('T')[0];

  // League ID 1 = FIFA World Cup in API-Football
  const url = `https://v3.football.api-sports.io/fixtures?league=1&season=2026&date=${today}`;

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

    // Pass through the full response — admin.html reads data.response[]
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache'
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
