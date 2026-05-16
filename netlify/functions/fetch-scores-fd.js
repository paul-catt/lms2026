// netlify/functions/fetch-scores-fd.js
// Proxies football-data.org fixtures — test alternative to API-Football.
// Free tier covers current season for major competitions.

exports.handler = async function(event, context) {
  const API_KEY = process.env.FOOTBALL_DATA_KEY;

  if (!API_KEY) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'FOOTBALL_DATA_KEY not configured in Netlify env vars.' })
    };
  }

  const params     = event.queryStringParameters || {};
  const competition = params.competition || 'WC';   // WC = World Cup, PL = Premier League etc.
  const dateFrom   = params.dateFrom || new Date().toISOString().split('T')[0];
  const dateTo     = params.dateTo   || dateFrom;

  const url = `https://api.football-data.org/v4/competitions/${competition}/matches?dateFrom=${dateFrom}&dateTo=${dateTo}`;

  try {
    const res = await fetch(url, {
      headers: {
        'X-Auth-Token': API_KEY
      }
    });

    if (!res.ok) {
      const text = await res.text();
      return {
        statusCode: res.status,
        body: JSON.stringify({ error: 'football-data.org returned HTTP ' + res.status, detail: text })
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
