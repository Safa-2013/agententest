/* S.G.D. Offline-Shell: niemals Konto-, API- oder Antwortdaten cachen. */
const SGD_SHELL='sgd-shell-freeapp-v2';
const SGD_FILES=['./index.html','./manifest.webmanifest','./sgd-icon-192.png','./sgd-icon-512.png','./sgd-apple-touch-icon.png'];
self.addEventListener('install',event=>{
  self.skipWaiting();
  event.waitUntil(caches.open(SGD_SHELL).then(cache=>Promise.allSettled(SGD_FILES.map(file=>cache.add(file)))));
});
self.addEventListener('activate',event=>{
  event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('sgd-shell-')&&key!==SGD_SHELL).map(key=>caches.delete(key)))));
  self.clients.claim();
});
self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET'||request.mode!=='navigate')return;
  const url=new URL(request.url);
  if(url.origin!==self.location.origin)return;
  event.respondWith(fetch(request).then(response=>{
    if(response.ok){const saved=response.clone();caches.open(SGD_SHELL).then(cache=>cache.put('./index.html',saved)).catch(()=>{})}
    return response;
  }).catch(async()=>{
    const cached=await caches.match('./index.html');
    return cached||new Response('Ohne Verbindung ist nur die heruntergeladene Spieloberfläche verfügbar.',{status:503,headers:{'Content-Type':'text/plain;charset=utf-8'}});
  }));
});
