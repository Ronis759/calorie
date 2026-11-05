const VERSION='v9.4',C='cal-'+VERSION,F=['./','index.html','manifest.json','help.html','icon-180.png','icon-192.png','icon-512.png'];

self.addEventListener('install',e=>{
  e.waitUntil(caches.open(C).then(c=>c.addAll(F).then(()=>c.add('zxing.min.js').catch(()=>{}))).then(()=>self.skipWaiting()));
});

self.addEventListener('activate',e=>{
  e.waitUntil(
    caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x))))
    .then(()=>self.clients.claim())
  );
});

const put=(r,x)=>{if(x&&x.ok&&x.type==='basic'){const y=x.clone();caches.open(C).then(c=>c.put(r,y))}return x};

self.addEventListener('fetch',e=>{
  const r=e.request;
  if(r.method!=='GET'||new URL(r.url).origin!==location.origin)return;

  if(r.mode==='navigate'){
    // сеть с таймаутом 3 с, иначе кэш (на плохой связи приложение не «висит»)
    const net=fetch(r).then(x=>put(r,x));
    const slow=new Promise((_,no)=>setTimeout(no,3000));
    e.respondWith(
      Promise.race([net,slow]).catch(()=>
        caches.match(r).then(m=>m||caches.match('index.html')).then(m=>m||net)
      )
    );
  } else {
    e.respondWith(
      caches.match(r).then(m=>m||fetch(r).then(x=>put(r,x)))
    );
  }
});
