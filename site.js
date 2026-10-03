/* ============================================================
   MaketPles ENB — shared page chrome and behaviour
   ------------------------------------------------------------
   Loaded by index.html, shop.html and about.html, after
   shop-data.js. Each page defines its own boot() and then calls
   Site.start(boot).

   What lives here, so the pages can never drift apart:
     - the icon sprite
     - the basket drawer, checkout and the phone shop bar
     - the product card used everywhere
     - the sample-data notice
     - scroll reveal, count-up numbers, header and progress line
   ============================================================ */

const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const sme = getSme;
let SMES = [], P = [];

/* ---------- markup injected into every page ---------- */
const SPRITE = `<svg style="position:absolute;width:0;height:0;overflow:hidden" aria-hidden="true" focusable="false">
  <symbol id="ic-search" viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></symbol>
  <symbol id="ic-bag" viewBox="0 0 24 24"><path d="M6 8h12l-1.2 12.5a1 1 0 0 1-1 .5H8.2a1 1 0 0 1-1-.5L6 8Z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/></symbol>
  <symbol id="ic-grid" viewBox="0 0 24 24"><rect x="4" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.5"/></symbol>
  <symbol id="ic-lock" viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></symbol>
  <symbol id="ic-shield" viewBox="0 0 24 24"><path d="M12 3 4.5 6v5.5c0 4.6 3.2 8.2 7.5 9.5 4.3-1.3 7.5-4.9 7.5-9.5V6L12 3Z"/><path d="m8.8 12 2.2 2.2 4.3-4.4"/></symbol>
  <symbol id="ic-card" viewBox="0 0 24 24"><rect x="3" y="5.5" width="18" height="13" rx="2"/><line x1="3" y1="10" x2="21" y2="10"/><line x1="6.5" y1="14.5" x2="10" y2="14.5"/></symbol>
  <symbol id="ic-home" viewBox="0 0 24 24"><path d="M3.5 11 12 4l8.5 7"/><path d="M5.5 9.5V20h13V9.5"/><path d="M12 17.2s-3-1.9-3-3.9a1.6 1.6 0 0 1 3-.8 1.6 1.6 0 0 1 3 .8c0 2-3 3.9-3 3.9Z"/></symbol>
  <symbol id="ic-people" viewBox="0 0 24 24"><circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><circle cx="17" cy="9" r="2.4"/><path d="M15.8 14.2A5 5 0 0 1 21 19"/></symbol>
  <symbol id="ic-retail" viewBox="0 0 24 24"><path d="M4 9.5 5.2 4h13.6l1.2 5.5"/><path d="M4 9.5v10h16v-10"/><path d="M9.5 19.5v-5h5v5"/></symbol>
  <symbol id="ic-wholesale" viewBox="0 0 24 24"><path d="M21 8 12 3 3 8v8l9 5 9-5V8Z"/><path d="M3 8l9 5 9-5"/><path d="M12 13v8"/></symbol>
  <symbol id="ic-tailoring" viewBox="0 0 24 24"><circle cx="6" cy="6.5" r="2.3"/><circle cx="6" cy="17.5" r="2.3"/><line x1="8.4" y1="8" x2="20" y2="19"/><line x1="8.4" y1="16" x2="20" y2="5"/></symbol>
  <symbol id="ic-crafts" viewBox="0 0 24 24"><ellipse cx="12" cy="12" rx="9" ry="7"/><circle cx="15.2" cy="15" r="2" fill="var(--sand)" stroke="none"/><circle cx="8" cy="9" r="1.1" fill="currentColor" stroke="none"/><circle cx="12" cy="6.8" r="1.1" fill="currentColor" stroke="none"/><circle cx="16" cy="9" r="1.1" fill="currentColor" stroke="none"/></symbol>
  <symbol id="ic-processing" viewBox="0 0 24 24"><path d="M10 3h4"/><path d="M10 3v5.2L5.3 17a2 2 0 0 0 1.8 3h9.8a2 2 0 0 0 1.8-3L14 8.2V3"/><line x1="7.8" y1="14.5" x2="16.2" y2="14.5"/></symbol>
  <symbol id="ic-produce" viewBox="0 0 24 24"><path d="M4.5 11h15l-1.8 9H6.3l-1.8-9Z"/><circle cx="9" cy="9" r="1.9"/><circle cx="13" cy="7" r="2.2"/><circle cx="16.3" cy="9.8" r="1.5"/></symbol>
  <symbol id="ic-foodcrops" viewBox="0 0 24 24"><line x1="12" y1="21" x2="12" y2="9"/><path d="M12 9 9.2 6.2 M12 9 14.8 6.2 M12 13 9.2 10.2 M12 13 14.8 10.2 M12 17 9.2 14.2 M12 17 14.8 14.2"/></symbol>
  <symbol id="ic-help" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M9.6 9.3a2.5 2.5 0 0 1 4.8 1c0 1.7-2.4 2.2-2.4 3.7"/><circle cx="12" cy="17" r=".6" fill="currentColor"/></symbol>
</svg>`;
const OVERLAYS = `<!-- BASKET -->
<div class="ovl" id="ovl" onclick="closeCart()"></div>
<aside class="drawer" id="drawer" aria-label="Basket">
  <div class="dhd">
    <h3>Your basket</h3>
    <button onclick="closeCart()" aria-label="Close">×</button>
  </div>
  <div class="ribbon" aria-hidden="true"></div>
  <div class="ditems" id="ditems"></div>
  <div class="dfoot" id="dfoot">
    <div class="srow"><span>Subtotal</span><span id="sub">K0.00</span></div>
    <div class="srow"><span>Delivery</span><span id="del">K0.00</span></div>
    <div class="srow tot"><span>Total</span><span id="tot">K0.00</span></div>
    <p class="dnote" id="dnote"></p>
    <button class="co-btn" onclick="openCo()">Proceed to checkout</button>
  </div>
</aside>

<!-- CHECKOUT -->
<div class="movl" id="movl">
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="coTitle">
    <div class="mhd">
      <h3 id="coTitle">Checkout</h3>
      <button onclick="closeCo()" aria-label="Close">×</button>
    </div>

    <form class="mbd" id="coForm" onsubmit="placeOrder(event)" novalidate>
      <div class="tabs" role="tablist">
        <button type="button" class="tab on" id="tSelf" role="tab" aria-selected="true" onclick="tab('self')">For myself</button>
        <button type="button" class="tab" id="tHome" role="tab" aria-selected="false" onclick="tab('home')">Send home</button>
      </div>

      <div class="fr"><label for="coName">Your full name</label><input id="coName" autocomplete="name" required></div>
      <div class="fr"><label for="coPhone">Mobile number</label><input id="coPhone" type="tel" inputmode="tel" autocomplete="tel" placeholder="+675 7XX XXXXX" required></div>
      <div class="fr"><label for="coEmail">Email <small>(optional)</small></label><input id="coEmail" type="email" autocomplete="email"></div>

      <div id="rcp" hidden>
        <div class="fr"><label for="coRName">Who is it for?</label><input id="coRName" placeholder="Recipient's name"></div>
        <div class="fr"><label for="coRPhone">Their mobile number (PNG)</label><input id="coRPhone" type="tel" inputmode="tel" placeholder="+675 7XX XXXXX"></div>
      </div>

      <div class="fr">
        <label for="coFulfil">How will it be received?</label>
        <select id="coFulfil" onchange="coUpdate()">
          <option value="sme_pickup">Collect from the business</option>
          <option value="agent_handoff">Collect from a local agent</option>
          <option value="delivery">Delivery — Kokopo and Rabaul urban areas</option>
        </select>
      </div>
      <div id="coDelivery" hidden>
        <div class="fr"><label for="coAddr">Delivery address</label><input id="coAddr" autocomplete="street-address" placeholder="Section, lot, street or landmark"></div>
        <div class="fr"><label for="coDist">District</label>
          <select id="coDist"><option>Kokopo</option><option>Rabaul</option><option>Gazelle</option><option>Pomio</option></select></div>
      </div>

      <fieldset class="paychoice">
        <legend>How will you pay?</legend>
        <label class="pc"><input type="radio" name="coPay" value="agent_cash" checked onchange="coUpdate()">
          <span><b>Cash through a local agent</b><small>Pay at a trade store or market agent. Your order number is all they need.</small></span></label>
        <label class="pc"><input type="radio" name="coPay" value="bank_transfer" onchange="coUpdate()">
          <span><b>Bank transfer</b><small>Pay into the MaketPles account using your order number as the reference.</small></span></label>
        <label class="pc" id="coCardOpt"><input type="radio" name="coPay" value="card" disabled>
          <span><b>Card or BSP Pay</b><small id="coCardNote">Coming soon.</small></span></label>
      </fieldset>

      <div class="cosum">
        <div class="srow"><span>Items</span><span id="coSub">K0.00</span></div>
        <div class="srow"><span>Delivery</span><span id="coDel">K0.00</span></div>
        <div class="mtot"><span>Total</span><span id="mtot">K0.00</span></div>
      </div>
      <div class="coerr" id="coErr" role="alert" hidden></div>
      <button class="co-btn" id="coBtn" type="submit">Place order</button>
      <div class="mnote" id="coNote">You pay after the order is placed. Nothing is charged now.</div>
      <div class="mnote coterms">By placing an order you agree to the <a href="legal.html#terms">Terms of use</a> and <a href="legal.html#refunds">Refunds policy</a>. <a href="legal.html#privacy">How we use your details</a>.</div>
    </form>

    <div class="mbd" id="coDone" hidden tabindex="-1"></div>
  </div>
</div>`;
const MBAR = `
<nav class="mbar" aria-label="Shop">
  <a href="index.html" data-p="home"><svg class="icon" aria-hidden="true"><use href="#ic-retail"/></svg>Home</a>
  <a href="shop.html" data-p="shop"><svg class="icon" aria-hidden="true"><use href="#ic-grid"/></svg>Shop</a>
  <button onclick="mSearch()"><svg class="icon" aria-hidden="true"><use href="#ic-search"/></svg>Search</button>
  <button onclick="openCart()"><svg class="icon" aria-hidden="true"><use href="#ic-bag"/></svg>Basket<span class="bcount" id="bcount2">0</span></button>
</nav>`;

(function mountChrome(){
  document.body.insertAdjacentHTML('afterbegin', SPRITE);
  document.body.insertAdjacentHTML('beforeend', MBAR + OVERLAYS);
  const page = document.body.dataset.page;
  document.querySelectorAll(`nav.main a[data-p="${page}"], .mbar a[data-p="${page}"]`)
    .forEach(a => a.classList.add('on'));
})();

/* ---------- small helpers ---------- */
function go(id){
  const el = document.getElementById(id);
  if(el) el.scrollIntoView({behavior: reduce ? 'auto' : 'smooth'});
}
function ph(msg){ alert(msg); }
const money = n => 'K' + Number(n||0).toLocaleString('en-US',{minimumFractionDigits:2, maximumFractionDigits:2});
function mSearch(){
  const box = document.getElementById('mq');
  if(box){
    box.scrollIntoView({behavior: reduce ? 'auto' : 'smooth', block:'center'});
    setTimeout(()=>box.focus({preventScroll:true}), reduce ? 0 : 400);
  } else {
    location.href = 'shop.html?focus=search';
  }
}

/* ---------- categories, used by the home tiles and the shop chips ---------- */
const CATS = [
  {c:"produce",    n:"Fresh Produce",       bg:"#E2F0E2", fg:"#24662F"},   // leaf green
  {c:"foodcrops",  n:"Food Crops & Spices", bg:"#FBF0D2", fg:"#7D5A0C"},   // kumul gold
  {c:"crafts",     n:"Arts & Crafts",       bg:"#FBE1EC", fg:"#9C2A5D"},   // Sulka pink
  {c:"tailoring",  n:"Tailoring",           bg:"#F8E0DA", fg:"#A8281A"},   // tubuan red
  {c:"processing", n:"Processed Goods",     bg:"#F1E4D8", fg:"#5B3220"},   // Gazelle cocoa
  {c:"retail",     n:"Retail",              bg:"#DCEEEF", fg:"#0F5C68"},   // harbour teal
  {c:"wholesale",  n:"Wholesale & Bulk",    bg:"#ECE8E3", fg:"#4F4943"},   // Tavurvur ash
];
const DISTRICT_NAMES = ["Rabaul","Kokopo","Gazelle","Pomio"];

/* ---------- images sized for where they are shown ----------
   Cards, thumbnails and covers use a 480px copy:
     - local photos: photos/sm/<same filename>  (falls back to the full photo if missing)
     - Unsplash: the same image requested at 480px wide
   Full-size photos are kept for the product and stall pages. */
function thumbURL(ref){
  const full = photoURL(ref);
  if(!full) return null;
  if(/^https?:\/\/images\.unsplash\.com/i.test(full)) return {src: full.replace(/([?&])w=\d+/, '$1w=480'), full};
  if(/^(data:|https?:)/i.test(full)) return {src: full, full};
  return {src: full.replace(/([^/]+)$/, 'sm/$1'), full};
}
function imgTag(ref, alt){
  const t = thumbURL(ref);
  if(!t) return '';
  const fallback = t.src !== t.full ? ` onerror="this.onerror=null;this.src='${esc(t.full)}'"` : '';
  return `<img src="${esc(t.src)}" alt="${esc(alt||'')}" loading="lazy" decoding="async"${fallback}>`;
}

/* ---------- the product card, shared by every list of products ---------- */
function cardHTML(p, i){
  const s = sme(p.s);
  const img = photoURL(p.ph);
  const tag = (p.stock != null && p.stock <= 5) ? `<span class="stk low">Only ${p.stock} left</span>`
            : p.fresh ? `<span class="stk fresh">Fresh</span>` : '';
  return `<article class="card">
    <a class="ph" href="product.html?p=${i}" tabindex="-1" aria-hidden="true">
      ${p.b ? `<span class="badge">${p.b}</span>` : ''}${tag}
      ${img ? imgTag(p.ph, clean(p.n)) : catIcon(p.c)}
    </a>
    <div class="bd">
      <a class="sme" href="sme.html?s=${p.s}">${s ? s.n : ''}</a>
      <h3><a href="product.html?p=${i}">${p.n}</a></h3>
      <span class="dist">${s ? s.d + ' District' : ''}</span>
      <div class="pr-row"><span class="price">${money(p.p)}</span>${p.u ? `<span class="unit">${p.u}</span>` : ''}</div>
      <button class="addb" onclick="add('${i}')" aria-label="Add ${clean(p.n)} to basket"><svg class="icon" aria-hidden="true"><use href="#ic-bag"/></svg><span>Add to basket</span></button>
    </div>
  </article>`;
}

/* ---------- basket ---------- */
function add(i){
  cartAdd(i, 1);
  renderCart(); openCart();
  const c = document.getElementById('bcount');
  if(c && !reduce){ c.classList.remove('bump'); void c.offsetWidth; c.classList.add('bump'); }
}
function chg(idx,d){ cartChange(idx, d); renderCart(); }
function renderCart(){
  const { cart, sub, del, total } = cartTotals();
  ['bcount','bcount2'].forEach(id=>{ const e = document.getElementById(id); if(e) e.textContent = cartCount(); });
  const it = document.getElementById('ditems'), ft = document.getElementById('dfoot');
  if(!cart.length){
    it.innerHTML = '<div class="empty">Your basket is empty.<br><a class="see" href="shop.html">Browse the market →</a></div>';
    ft.style.display='none'; return;
  }
  ft.style.display='block';
  it.innerHTML = cart.map((c,idx)=>{
    const p = getProduct(c.i); if(!p) return '';
    const s = sme(p.s);
    const img = photoURL(p.ph);
    return `<div class="ditem">
      <div class="th"><a href="product.html?p=${c.i}" aria-label="${esc(clean(p.n))}">${img ? imgTag(p.ph, '') : catIcon(p.c)}</a></div>
      <div class="mt">
        <h4><a href="product.html?p=${c.i}">${p.n}</a></h4>
        <span class="sm">${s ? s.n : ''}</span>
        <div class="qty">
          <button onclick="chg(${idx},-1)" aria-label="Less">−</button>
          <span class="q">${c.q}</span>
          <button onclick="chg(${idx},1)" aria-label="More">+</button>
        </div>
      </div>
      <span class="pr">${money(p.p*c.q)}</span>
    </div>`;
  }).join('');
  const s = Shop.SETTINGS || {};
  document.getElementById('sub').textContent = money(sub);
  document.getElementById('del').textContent = del === 0 ? 'Free' : money(del) + ' if delivered';
  document.getElementById('tot').textContent = money(sub);
  document.getElementById('dnote').textContent = (s.min_order && sub < Number(s.min_order))
    ? `Minimum order is ${money(s.min_order)}.` : 'Collection is free. Delivery is chosen at checkout.';
}
function openCart(){document.getElementById('drawer').classList.add('on');document.getElementById('ovl').classList.add('on');}
function closeCart(){document.getElementById('drawer').classList.remove('on');document.getElementById('ovl').classList.remove('on');}

/* ---------- checkout ----------
   Catalogue mode: the order is placed now and paid afterwards, through an
   agent or by bank transfer. When a card gateway is switched on in
   platform_settings, the card option becomes available. Prices, fees and
   delivery are always recalculated by the database (place_order). */
function coSelected(name){ const x = document.querySelector(`input[name="${name}"]:checked`); return x ? x.value : null; }
function coUpdate(){
  const { sub } = cartTotals();
  const s = Shop.SETTINGS || {};
  const fulfil = document.getElementById('coFulfil').value;
  document.getElementById('coDelivery').hidden = fulfil !== 'delivery';
  const del = (fulfil === 'delivery' && sub < Number(s.free_delivery_over || 150)) ? Number(s.delivery_fee || 15) : 0;
  document.getElementById('coSub').textContent = money(sub);
  document.getElementById('coDel').textContent = fulfil === 'delivery' ? (del ? money(del) : 'Free') : '—';
  document.getElementById('mtot').textContent = money(sub + del);
  const card = document.querySelector('input[name="coPay"][value="card"]');
  card.disabled = !s.card_payments_enabled;
  document.getElementById('coCardNote').textContent = s.card_payments_enabled ? 'Pay securely on the bank\'s own page.' : 'Coming soon.';
}
function openCo(){
  if(!cartCount()) return;
  document.getElementById('coForm').hidden = false;
  document.getElementById('coDone').hidden = true;
  document.getElementById('coErr').hidden = true;
  document.getElementById('coNote').textContent = Shop.LIVE
    ? 'You pay after the order is placed. Nothing is charged now.'
    : 'Preview mode: no order will be sent.';
  coUpdate();
  document.getElementById('movl').classList.add('on');
  setTimeout(()=>document.getElementById('coName').focus(), 50);
}
function closeCo(){document.getElementById('movl').classList.remove('on');}
function tab(t){
  const home = t === 'home';
  document.getElementById('tSelf').classList.toggle('on', !home);
  document.getElementById('tHome').classList.toggle('on', home);
  document.getElementById('tSelf').setAttribute('aria-selected', !home);
  document.getElementById('tHome').setAttribute('aria-selected', home);
  document.getElementById('rcp').hidden = !home;
}
function coError(msg){
  const e = document.getElementById('coErr');
  e.textContent = msg; e.hidden = false;
  e.scrollIntoView({block:'nearest'});
}
async function placeOrder(ev){
  ev.preventDefault();
  const v = id => document.getElementById(id).value.trim();
  const gift = document.getElementById('tHome').classList.contains('on');
  const fulfil = v('coFulfil');
  if(v('coName').length < 2) return coError('Please enter your name.');
  if(!/^\+?[0-9 ]{7,20}$/.test(v('coPhone'))) return coError('Please enter a valid mobile number.');
  if(gift && (v('coRName').length < 2 || !/^\+?[0-9 ]{7,20}$/.test(v('coRPhone'))))
    return coError('Please enter the name and mobile number of the person receiving the order.');
  if(fulfil === 'delivery' && v('coAddr').length < 3) return coError('Please enter a delivery address.');

  const order = {
    buyer_name: v('coName'), buyer_phone: v('coPhone'), buyer_email: v('coEmail'),
    is_gift: gift, recipient_name: gift ? v('coRName') : '', recipient_phone: gift ? v('coRPhone') : '',
    fulfilment: fulfil, payment_method: coSelected('coPay'),
    delivery_address: fulfil === 'delivery' ? v('coAddr') : '',
    delivery_district: fulfil === 'delivery' ? v('coDist') : '',
    items: getCart().map(c => ({ product_id: c.i, qty: c.q }))
  };

  const btn = document.getElementById('coBtn');
  btn.disabled = true; btn.textContent = 'Placing your order…';
  document.getElementById('coErr').hidden = true;
  try{
    let result;
    if(Shop.LIVE){
      result = await dbRpc('place_order', { p_order: order });
    } else {
      const { sub } = cartTotals();
      result = { preview: true, total: sub, payment_method: order.payment_method,
                 orders: [{ order_number: 'ENB-PREVIEW', business: 'Preview', total: sub }] };
    }
    try{ localStorage.setItem('mp_last_basket', JSON.stringify({ ref: result.basket_ref, at: Date.now() })); }catch(e){}
    cartClear(); renderCart();
    showDone(result, order);
  }catch(err){
    coError(err.message || 'Something went wrong. Please try again.');
  }finally{
    btn.disabled = false; btn.textContent = 'Place order';
  }
}
function showDone(r, order){
  const s = Shop.SETTINGS || {};
  const list = (r.orders || []).map(o => `<li><b>${esc(o.order_number)}</b> — ${esc(o.business)} <span>${money(o.total)}</span></li>`).join('');
  const refs = (r.orders || []).map(o => o.order_number).join(', ');
  const how = r.payment_method === 'bank_transfer'
    ? `<h4>Pay by bank transfer</h4><p>Transfer <b>${money(r.total)}</b> and use <b>${esc(refs)}</b> as the reference.</p>` +
      (s.bank_transfer_details ? `<pre class="bankbox">${esc(s.bank_transfer_details)}</pre>`
                               : `<p>The Division will send you the account details by SMS.</p>`)
    : `<h4>Pay through a local agent</h4><p>Take your order number${(r.orders||[]).length>1?'s':''} <b>${esc(refs)}</b> to a MaketPles agent at a trade store or market and pay <b>${money(r.total)}</b> in cash.</p>`;
  const box = document.getElementById('coDone');
  box.innerHTML = `
    <div class="done-ok" aria-hidden="true">✓</div>
    <h3 class="done-h">${r.preview ? 'Preview only — no order was sent' : 'Order placed. Tenkyu tru!'}</h3>
    <p class="done-sub">${order.is_gift ? `For ${esc(order.recipient_name)}. ` : ''}We'll send updates to ${esc(order.buyer_phone)}.</p>
    <ul class="done-list">${list}</ul>
    <div class="done-pay">${how}</div>
    <p class="done-sub">Each business prepares its own part of your order once payment is confirmed.</p>
    <button class="co-btn" type="button" onclick="closeCo()">Done</button>`;
  document.getElementById('coForm').hidden = true;
  box.hidden = false; box.focus();
}
/* drop basket lines for products that no longer exist (e.g. after moving from samples to live data) */
function pruneCart(){
  const cart = getCart();
  const kept = cart.filter(c => getProduct(c.i));
  if(kept.length !== cart.length) saveCart(kept);
}
document.addEventListener('keydown', e=>{ if(e.key==='Escape'){ closeCo(); closeCart(); } });
// keep every open tab's basket in step
window.addEventListener('storage', e=>{ if(e.key === CART_KEY) renderCart(); });

/* ---------- motion ---------- */
let io;
function observe(){
  if(reduce || !('IntersectionObserver' in window)){ document.querySelectorAll('.rv').forEach(e=>e.classList.add('in')); return; }
  if(!io){
    io = new IntersectionObserver(es=>{
      es.forEach(e=>{ if(e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); } });
    }, {threshold:0.12, rootMargin:'0px 0px -40px 0px'});
  }
  document.querySelectorAll('.rv:not(.in)').forEach(e=>io.observe(e));
}
function countUp(el){
  const to = +el.dataset.to, pre = el.dataset.pre || '';
  if(reduce){ el.textContent = pre+to; return; }
  const dur = 1400, t0 = performance.now();
  (function step(t){
    const k = Math.min((t-t0)/dur, 1);
    el.textContent = pre + Math.round(to*(1 - Math.pow(1-k, 3)));
    if(k < 1) requestAnimationFrame(step);
  })(t0);
}
function initMetrics(){
  const els = document.querySelectorAll('.metric .n[data-to]');
  if(!els.length) return;
  const mio = new IntersectionObserver(es=>{
    es.forEach(e=>{ if(e.isIntersecting){ countUp(e.target); mio.unobserve(e.target); } });
  }, {threshold:0.5});
  els.forEach(e=>mio.observe(e));
}
(function(){
  const bar = document.getElementById('progress');
  const hdr = document.querySelector('header.site');
  let ticking = false;
  function onScroll(){
    if(ticking) return;
    ticking = true;
    requestAnimationFrame(()=>{
      const y = window.scrollY || 0;
      const max = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
      if(bar && !reduce) bar.style.transform = 'scaleX(' + Math.min(1, y/max) + ')';
      if(hdr) hdr.classList.toggle('tight', y > 120);
      ticking = false;
    });
  }
  window.addEventListener('scroll', onScroll, {passive:true});
  window.addEventListener('resize', onScroll, {passive:true});
  onScroll();
})();

/* ============================================================
   SAMPLE-DATA NOTICE
   To publish real data: export `data.json` from the SME Intake
   tool and place it beside these pages, with the photographs in
   a `photos/` folder. Nothing here needs editing.
   ============================================================ */
let pageBoot = null;
function applyData(d){
  if(!d || !Array.isArray(d.SMES) || !Array.isArray(d.P)) throw new Error("unrecognised data file");
  Shop.SMES = d.SMES;
  Shop.P = d.P;
  if(Array.isArray(d.SLIDES) && d.SLIDES.length) Shop.SLIDES = d.SLIDES;
  if(d.config) Shop.CONFIG = Object.assign({}, Shop.CONFIG, d.config);
  Shop.IS_SAMPLE = false;
  Shop.SMES.forEach(x => { x.c = Shop.P.filter(p => p.s === x.id).length; });
  SMES = Shop.SMES; P = Shop.P;
  if(pageBoot) pageBoot();
  renderCart(); observe();
  notice(false);
}
function notice(showBar){
  let bar = document.getElementById('previewBar');
  if(!showBar){ if(bar) bar.remove(); return; }
  if(bar) return;
  bar = document.createElement('div');
  bar.id = 'previewBar';
  bar.style.cssText =
    "position:fixed;left:0;right:0;bottom:0;z-index:170;background:var(--ink);color:var(--ash);" +
    "padding:11px 18px;display:flex;gap:14px;align-items:center;justify-content:center;flex-wrap:wrap;" +
    "font-size:12px;font-family:'Space Mono',monospace;letter-spacing:0.06em;border-top:2px solid var(--leaf);";
  bar.innerHTML =
    '<span style="color:var(--leaf-gl);">SAMPLE DATA</span>' +
    '<span style="opacity:.72;letter-spacing:0;font-family:\'Plus Jakarta Sans\';">' +
      'No <b>data.json</b> found. Showing placeholder businesses and products.</span>' +
    '<button id="pickBtn" style="background:var(--ash);color:var(--ink);border:none;border-radius:100px;' +
      'padding:7px 15px;font-weight:700;font-size:11.5px;font-family:\'Plus Jakarta Sans\';cursor:pointer;">' +
      'Load a data.json</button>' +
    '<button id="dismissBtn" aria-label="Dismiss" style="background:none;border:none;color:rgba(251,248,241,.5);' +
      'font-size:16px;cursor:pointer;line-height:1;">×</button>';
  if(showBar === 'rows'){
    // live database, but the businesses shown are still the placeholder set
    bar.innerHTML =
      '<span style="color:var(--gold);">SAMPLE LISTINGS</span>' +
      '<span style="opacity:.8;letter-spacing:0;font-family:\'Plus Jakarta Sans\';">' +
        'These businesses are placeholders until the launch cohort is loaded. Orders are recorded for testing only.</span>' +
      '<button id="dismissBtn" aria-label="Dismiss" style="background:none;border:none;color:rgba(251,248,241,.6);' +
        'font-size:18px;cursor:pointer;line-height:1;min-width:44px;min-height:44px;">×</button>';
    document.body.appendChild(bar);
    document.getElementById('dismissBtn').onclick = () => bar.remove();
    return;
  }
  document.body.appendChild(bar);
  const input = document.createElement('input');
  input.type = 'file'; input.accept = '.json,application/json'; input.style.display = 'none';
  document.body.appendChild(input);
  document.getElementById('pickBtn').onclick = () => input.click();
  document.getElementById('dismissBtn').onclick = () => bar.remove();
  input.onchange = e => {
    const f = e.target.files[0]; if(!f) return;
    const r = new FileReader();
    r.onload = () => {
      try{ applyData(JSON.parse(r.result)); }
      catch(err){ alert("That file could not be read as a MaketPles data file."); }
    };
    r.readAsText(f);
  };
}

/* ---------- start: load the shop data once, then run the page ---------- */
const Site = {
  start(boot){
    pageBoot = boot;
    renderCart();
    initMetrics();
    loadShop().then(()=>{
      SMES = Shop.SMES; P = Shop.P;
      pruneCart();
      boot();
      renderCart();
      observe();
      if(Shop.IS_SAMPLE) notice(true);
      else if(Shop.HAS_SAMPLE_ROWS) notice('rows');
    });
  }
};
