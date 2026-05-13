// LMS 2026 — Service Worker
// Handles incoming web push notifications

self.addEventListener('push', function(event) {
  if (!event.data) return;

  let payload;
  try {
    payload = event.data.json();
  } catch(e) {
    payload = { title: 'LMS 2026', body: event.data.text() };
  }

  const title   = payload.title || 'LMS 2026';
  const options = {
    body:    payload.body  || 'Time to make your pick!',
    icon:    payload.icon  || '/apple-touch-icon.png',
    badge:   '/favicon.ico',
    tag:     'lms2026-reminder',
    renotify: true,
    data:    { url: payload.url || '/' },
    actions: [{ action: 'open', title: 'Pick now' }]
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(list) {
      for (const client of list) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.navigate(url);
          return client.focus();
        }
      }
      if (clients.openWindow) return clients.openWindow(url);
    })
  );
});
