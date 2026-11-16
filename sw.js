const VERSION='v12.20',C='cal-'+VERSION,
// На GitHub Pages './' и 'index.html' — один и тот же файл, поэтому кэшируем его один раз.
// Навигация по корню тоже попадёт в этот ключ: fetch-обработчик кладёт ответ под 'index.html'.
F=['index.html','manifest.json','help.html','icon-180.png','icon-192.png','icon-512.png','VERSION'];

self.addEventListener('install',e=>{
  // Кэш наполняется ПОЛНОСТЬЮ до того, как SW станет готов к активации.
  // skipWaiting здесь не вызываем: новый SW ждёт в состоянии waiting,
  // а приложение решает, когда перезагрузиться (см. сообщение ниже).
  // Раньше skipWaiting стоял прямо в install — SW активировался и стирал старый кэш,
  // пока страница ещё работала на старой версии. Из-за этого PWA «зависало» на старом коде.
  e.waitUntil(
    caches.open(C)
      .then(c=>c.addAll(F))
      .then(()=>caches.open(C).then(c=>c.add('zxing.min.js').catch(()=>{})))
  );
});

self.addEventListener('activate',e=>{
  e.waitUntil(
    caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x))))
    .then(()=>self.clients.claim())
  );
});

self.addEventListener('message',e=>{
  if(e.data==='SKIP_WAITING')self.skipWaiting();
});

const put=(r,x)=>{if(x&&x.ok&&x.type==='basic'){const y=x.clone();caches.open(C).then(c=>c.put(r,y))}return x};

self.addEventListener('fetch',e=>{
  const r=e.request;
  if(r.method!=='GET'||new URL(r.url).origin!==location.origin)return;

  if(r.mode==='navigate'){
    // Сеть с таймаутом 3 с, иначе кэш. Ответ всегда кладём и под ключ навигации, и под index.html,
    // чтобы работал и запуск по корню '/calorie/', и прямой переход на index.html.
    const net=fetch(r).then(x=>{put(r,x);if(x&&x.ok){const y=x.clone();caches.open(C).then(c=>c.put('index.html',y).catch(()=>{}))}return x});
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
