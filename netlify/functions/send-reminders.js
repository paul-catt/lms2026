// LMS 2026 — Netlify Scheduled Function
// Runs every hour. If a round deadline is 55–75 mins away,
// sends a web push to every player who hasn't picked yet.
//
// Schedule defined in netlify.toml:
//   [functions."send-reminders"]
//   schedule = "0 * * * *"

const webpush = require('web-push');
const { createClient } = require('@supabase/supabase-js');

exports.handler = async function() {
  const SUPABASE_URL        = process.env.SUPABASE_URL        || 'https://jrdjdqjepffdcjdfuarc.supabase.co';
  const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
  const VAPID_PUBLIC_KEY    = process.env.VAPID_PUBLIC_KEY;
  const VAPID_PRIVATE_KEY   = process.env.VAPID_PRIVATE_KEY;
  const VAPID_SUBJECT       = process.env.VAPID_SUBJECT;

  if (!SUPABASE_SERVICE_KEY || !VAPID_PUBLIC_KEY || !VAPID_PRIVATE_KEY) {
    console.error('Missing env vars');
    return { statusCode: 500, body: 'Missing env vars' };
  }

  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);

  const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // Find rounds whose deadline is 55–75 minutes from now
  const now     = new Date();
  const windowStart = new Date(now.getTime() + 55 * 60 * 1000);
  const windowEnd   = new Date(now.getTime() + 75 * 60 * 1000);

  const { data: rounds, error: roundsErr } = await db
    .from('rounds')
    .select('id, name, deadline')
    .eq('is_complete', false)
    .neq('name', '3rd Place')
    .gte('deadline', windowStart.toISOString())
    .lte('deadline', windowEnd.toISOString());

  if (roundsErr) { console.error('rounds error', roundsErr); return { statusCode: 500 }; }
  if (!rounds || rounds.length === 0) {
    console.log('No deadlines in window — nothing to do');
    return { statusCode: 200, body: 'No deadlines in window' };
  }

  const round = rounds[0];
  console.log(`Deadline approaching: ${round.name} at ${round.deadline}`);

  // Players who haven't picked in this round and aren't eliminated
  const { data: allPlayers } = await db
    .from('players')
    .select('id, name, slug')
    .eq('is_eliminated', false);

  const { data: existingPicks } = await db
    .from('picks')
    .select('player_id')
    .eq('round_id', round.id);

  const pickedIds = new Set((existingPicks || []).map(p => p.player_id));
  const needReminder = (allPlayers || []).filter(p => !pickedIds.has(p.id));

  if (needReminder.length === 0) {
    console.log('Everyone has picked — no reminders needed');
    return { statusCode: 200, body: 'All picked' };
  }

  console.log(`Sending reminders to ${needReminder.length} players`);

  // Fetch their push subscriptions
  const playerIds = needReminder.map(p => p.id);
  const { data: subs } = await db
    .from('push_subscriptions')
    .select('player_id, subscription')
    .in('player_id', playerIds);

  if (!subs || subs.length === 0) {
    console.log('No push subscriptions found for unpicked players');
    return { statusCode: 200, body: 'No subscriptions' };
  }

  // Build a map of player_id → slug for deep link
  const slugMap = {};
  (allPlayers || []).forEach(p => { slugMap[p.id] = p.slug; });

  const deadline = new Date(round.deadline);
  const minsLeft = Math.round((deadline - now) / 60000);

  let sent = 0, failed = 0;
  for (const sub of subs) {
    const playerSlug = slugMap[sub.player_id] || '';
    const payload = JSON.stringify({
      title: 'LMS 2026 ⏰',
      body:  `${round.name} deadline in ~${minsLeft} mins — you haven't picked yet!`,
      url:   '/' + playerSlug,
      icon:  '/apple-touch-icon.png'
    });

    try {
      await webpush.sendNotification(sub.subscription, payload);
      sent++;
    } catch(err) {
      console.error(`Failed for player ${sub.player_id}:`, err.statusCode, err.body);
      // If subscription is expired/invalid, remove it
      if (err.statusCode === 410 || err.statusCode === 404) {
        await db.from('push_subscriptions').delete().eq('player_id', sub.player_id);
        console.log(`Removed stale subscription for ${sub.player_id}`);
      }
      failed++;
    }
  }

  console.log(`Done — sent: ${sent}, failed: ${failed}`);
  return { statusCode: 200, body: `sent:${sent} failed:${failed}` };
};
