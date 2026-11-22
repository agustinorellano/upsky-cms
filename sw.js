// UP SKY · panel de contenido: service worker de notificaciones push.
// Solo muestra los avisos que envía la función "push" de Supabase y abre el panel al tocarlos.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; } catch (e) { d = { body: event.data ? event.data.text() : '' }; }
  const title = String(d.title || 'UP SKY').slice(0, 80);
  event.waitUntil(self.registration.showNotification(title, {
    body: String(d.body || '').slice(0, 200),
    icon: 'favicon-192.png',
    badge: 'favicon-96.png',
    tag: String(d.tag || 'upsky'),
    data: { url: typeof d.url === 'string' && d.url.startsWith('/') ? d.url : '/' },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL((event.notification.data && event.notification.data.url) || '/', self.location.origin).href;
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    for (const c of list) if (c.url.startsWith(self.location.origin) && 'focus' in c) return c.focus();
    return self.clients.openWindow(url);
  }));
});
