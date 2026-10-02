/* ============================================================
   MaketPles ENB — shared shop data & basket
   ------------------------------------------------------------
   Used by index.html, sme.html and product.html, so all three
   pages see the exact same businesses, products and basket.

   DATA
   The site looks for a file called `data.json` next to this
   one, produced by the SME Intake tool. If it is found, the
   sample data below is replaced entirely. If not, the sample
   set below is used and a preview notice is shown.

   PRODUCT IDENTITY
   A product's id is its position in the P array (0, 1, 2…).
   That is fine while the catalogue is a single shared file —
   every page loads the same array in the same order. Once the
   site is reading from Supabase instead, this becomes the
   product's real database id and nothing that calls getProduct()
   needs to change.

   BASKET
   Held in localStorage so it survives moving between pages —
   add something on a stall page, it is still there on checkout.
   This is a plain file the user hosts themselves (GitHub Pages),
   not a Claude-hosted preview, so normal browser storage applies.
   ============================================================ */

const CONFIG_DEFAULT = { photoBase: "photos/", slideMs: 7000 };

const SAMPLE_SMES = [
  {id:"abuta",    n:"Abuta Agro Services",         d:"Gazelle", f:"Fresh produce · cocoa nursery",
   llg:"Rakunai Village, Central Gazelle LLG",
   about:"A family-run cocoa nursery at Rakunai Village in Central Gazelle, raising healthy bagged cocoa seedlings for smallholder growers across the Gazelle Peninsula. Every seedling is grown under shade cloth and hardened off before sale, so it is ready to plant out the day it leaves the nursery. Bulk orders for new blocks and replanting are welcome.",
   photo:"GAZELLE_Abuta_business_01.jpg"},
  {id:"vunamami", n:"Vunamami Growers Collective", d:"Kokopo",  f:"Fresh produce · food crops",
   about:"Smallholder growers from Vunamami village supplying fresh garden produce, vanilla and food crops across Kokopo District."},
  {id:"weavers",  n:"Rabaul Weavers Guild",        d:"Rabaul",  f:"Arts & crafts · tailoring",
   about:"A collective of weavers and tailors in Rabaul producing fine bilum, shellcraft and hand-finished garments."},
  {id:"kerevat",  n:"Kerevat Mill Co.",            d:"Gazelle", f:"Downstream processing · wholesale",
   about:"Processing cocoa, coffee and copra grown around Kerevat, with bulk supply for trade stores across Gazelle District."},
  {id:"pomio",    n:"Pomio Forest Crafts",         d:"Pomio",   f:"Arts & crafts · downstream processing",
   about:"Carvers and honey producers working from inland Pomio, bringing forest-sourced goods to the wider province."},
  {id:"toma",     n:"Toma Tailoring Centre",       d:"Gazelle", f:"Tailoring · garment production",
   about:"A tailoring workshop in Toma producing made-to-measure garments and school uniforms for families across Gazelle."},
  {id:"ktrade",   n:"Kokopo Trade Supplies",       d:"Kokopo",  f:"Retail · wholesale",
   about:"A long-established trade store in Kokopo supplying household goods, stationery and bulk essentials."},
];

const U = "https://images.unsplash.com/";
const Qp = "?fm=jpg&q=72&w=820&auto=format&fit=crop";

const SAMPLE_P = [
  {n:"Cocoa Seedlings, Bagged & Ready to Plant", s:"abuta", p:3, c:"produce", b:"Local grower", ph:"GAZELLE_Abuta_seedlings_01.jpg", u:"per seedling",
   about:"Healthy cocoa seedlings raised in poly bags under shade cloth at Rakunai Village. Hardened off and ready to plant straight into the ground. Collect from the nursery in Central Gazelle, or order in bulk for delivery.", stock:4800, fresh:true},
  {n:"Cocoa Seedlings, Block Planting Pack (500)", s:"abuta", p:1500, c:"produce", b:"Bulk", ph:"GAZELLE_Abuta_seedlings_02.jpg", u:"per 500 seedlings",
   about:"Five hundred bagged cocoa seedlings for planting a new block or replacing ageing trees — the same K3 a seedling, ready in one lot. Please allow around three weeks for large orders so the nursery can set aside hardened stock.", stock:9, fresh:true},
  {n:"Single-Origin Cocoa, Hand Fermented (1kg)", s:"kerevat",  p:52,  c:"processing", b:"Signature",   ph:U+"photo-1573710661345-610f790e1218"+Qp, u:"per kg", about:"Hand-fermented at the Kerevat mill from cocoa grown within Gazelle District.", stock:34},
  {n:"Fine-Weave Bilum, Large",                   s:"weavers",  p:135, c:"crafts",     b:null,          ph:U+"photo-1601330862030-1e08c703ac04"+Qp, u:"each", about:"Hand-woven over several weeks using traditional Tolai patterns.", stock:6},
  {n:"Volcanic Soil Vanilla Beans (100g)",        s:"vunamami", p:88,  c:"foodcrops",  b:"Best seller", ph:U+"photo-1682482198446-4cbf92f85a4b"+Qp, u:"per 100g", about:"Grown in the mineral-rich volcanic soil around Kokopo.", stock:18},
  {n:"Baining Mountain Coffee (250g)",            s:"kerevat",  p:40,  c:"processing", b:"New",         ph:U+"photo-1642258632706-142d5ce17754"+Qp, u:"per bag", about:"Shade-grown coffee from the Baining ranges, roasted at Kerevat.", stock:25},
  {n:"Island Spice Blend (150g)",                 s:"vunamami", p:26,  c:"foodcrops",  b:null,          ph:U+"photo-1716816211590-c15a328a5ff0"+Qp, u:"per 150g", about:"A house blend of island-grown spices.", stock:40},
  {n:"Dried Chilli Powder (100g)",                s:"vunamami", p:18,  c:"foodcrops",  b:null,          ph:U+"photo-1547332226-395d746d139a"+Qp, u:"per 100g", about:"Sun-dried and ground chillies from the Vunamami gardens.", stock:30},
  {n:"Highlands Rice, Milled (5kg)",              s:"ktrade",   p:62,  c:"foodcrops",  b:null,          ph:U+"flagged/photo-1553617569-8ef7a8da3146"+Qp, u:"per 5kg bag", about:"Milled rice sold by the bag, ready for the trade store shelf.", stock:50},
  {n:"Meri Blouse, Made to Measure",              s:"toma",     p:95,  c:"tailoring",  b:null,          ph:U+"photo-1633655442432-620aa55d7ac1"+Qp, u:"each", about:"Made to measure at the Toma workshop — allow one week.", stock:8},
  {n:"School Uniform Set, Tailored",              s:"toma",     p:78,  c:"tailoring",  b:"Seasonal",    ph:U+"photo-1618587194716-40490bdba417"+Qp, u:"per set", about:"Tailored uniform sets, sized for primary and secondary students.", stock:15},
  {n:"Laplap, Hand-Finished",                     s:"weavers",  p:45,  c:"tailoring",  b:null,          ph:U+"photo-1718184021018-d2158af6b321"+Qp, u:"each", about:"Hand-finished laplap in a range of island prints.", stock:20},
  {n:"Wild Forest Honey (350ml)",                 s:"pomio",    p:45,  c:"processing", b:null,          ph:U+"photo-1558642452-9d2a7deb7f62"+Qp, u:"per 350ml", about:"Harvested from wild hives in the Pomio forest.", stock:12},
  {n:"Smoked Reef Fish, Whole",                   s:"vunamami", p:38,  c:"processing", b:null,          ph:U+"photo-1739484151190-e2a73842ca13"+Qp, u:"each", about:"Smoked the same day it is caught.", stock:10, fresh:true},
  {n:"Cooking Bananas (Bunch)",                   s:"vunamami", p:18,  c:"produce",    b:null,          ph:U+"photo-1706059924238-361c705b121f"+Qp, u:"per bunch", about:"Fresh-cut cooking bananas from the Vunamami gardens.", stock:22, fresh:true},
  {n:"Aibika Greens Bundle",                      s:"vunamami", p:12,  c:"produce",    b:"Fresh today", ph:null, u:"per bundle", about:"Cut fresh each morning.", stock:40, fresh:true},
  {n:"Fresh Taro (5kg bag)",                      s:"kerevat",  p:35,  c:"produce",    b:null,          ph:null, u:"per 5kg bag", stock:16, fresh:true},
  {n:"Handcarved Ebony Figure",                   s:"pomio",    p:225, c:"crafts",     b:null,          ph:null, u:"each", about:"Carved by hand from a single piece of ebony.", stock:3},
  {n:"Shell & Seed Necklace",                     s:"weavers",  p:60,  c:"crafts",     b:null,          ph:null, u:"each", stock:11},
  {n:"Cold-Pressed Copra Oil (500ml)",            s:"kerevat",  p:32,  c:"processing", b:null,          ph:null, u:"per 500ml", stock:28},
  {n:"Copra Oil, 20L Bulk Drum",                  s:"kerevat",  p:520, c:"wholesale",  b:"Bulk",        ph:null, u:"per drum", stock:4},
  {n:"Trade Store Starter Pack",                  s:"ktrade",   p:340, c:"wholesale",  b:"Bulk",        ph:null, u:"per pack", stock:7},
  {n:"Household Goods Bundle",                    s:"ktrade",   p:85,  c:"retail",     b:null,          ph:null, u:"per bundle", stock:14},
  {n:"Stationery & School Supplies Pack",         s:"ktrade",   p:55,  c:"retail",     b:null,          ph:null, u:"per pack", stock:19},
];

const SAMPLE_SLIDES = [
  { img:"GAZELLE_Abuta_frontpage_01.jpg",  ind:"Fresh Produce · Cocoa Nursery", biz:"Abuta Agro Services", loc:"Gazelle District" },
  { img:U+"photo-1533900298318-6b8da08a523e",  ind:"Fresh Produce",          biz:"Vunamami Growers Collective", loc:"Kokopo District"  },
  { img:U+"photo-1718184021018-d2158af6b321",  ind:"Tailoring",              biz:"Toma Tailoring Centre",       loc:"Gazelle District" },
  { img:U+"photo-1601330862030-1e08c703ac04",  ind:"Arts & Crafts",          biz:"Rabaul Weavers Guild",        loc:"Rabaul District"  },
  { img:U+"photo-1573710661345-610f790e1218",  ind:"Downstream Processing",  biz:"Kerevat Mill Co.",            loc:"Gazelle District" },
  { img:U+"photo-1663154438428-60cdc204f99b",  ind:"Retail & Wholesale",     biz:"Kokopo Trade Supplies",       loc:"Kokopo District"  },
  { img:U+"photo-1517137744310-173515c62d59",  ind:"Arts & Crafts",          biz:"Pomio Forest Crafts",         loc:"Pomio District"   },
];

/* ---------------------------------------------------------- */
/* text + formatting helpers, shared everywhere               */
/* ---------------------------------------------------------- */
const esc = s => String(s==null?"":s).replace(/[&<>"]/g,
  c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const clean = s => String(s==null?"":s).replace(/&amp;/g,'&');
const K = n => "K" + Number(n||0).toFixed(2);

const CAT_ICON = {
  retail:"ic-retail", wholesale:"ic-wholesale", tailoring:"ic-tailoring",
  crafts:"ic-crafts", processing:"ic-processing", produce:"ic-produce", foodcrops:"ic-foodcrops"
};
const catIcon = c => `<svg class="icon cat-icon" aria-hidden="true"><use href="#${CAT_ICON[c]||'ic-wholesale'}"/></svg>`;

const INDUSTRY_LABEL = {
  retail:"Retail", wholesale:"Wholesale", tailoring:"Tailoring", crafts:"Arts & Crafts",
  processing:"Small Scale Downstream Processing", produce:"Fresh Produce", foodcrops:"Food Crops — Rice & Spices"
};

/* ---------------------------------------------------------- */
/* data loading — same data.json / sample fallback as before  */
/* ---------------------------------------------------------- */
const Shop = {
  SMES: [], P: [], SLIDES: [], CONFIG: CONFIG_DEFAULT, IS_SAMPLE: true,
};

function photoURL(ref){
  if(!ref) return null;
  const r = String(ref).trim();
  if(/^https?:\/\//i.test(r)) return r;
  if(/^data:/i.test(r)) return r;
  return Shop.CONFIG.photoBase.replace(/\/?$/,'/') + r.replace(/^\/+/,'');
}

function getSme(id){ return Shop.SMES.find(s => s.id === id) || null; }
function getProduct(id){
  const i = parseInt(id, 10);
  return (Number.isInteger(i) && Shop.P[i]) ? Shop.P[i] : null;
}
function productsForSme(smeId){
  return Shop.P.map((p,i)=>({p,i})).filter(({p}) => p.s === smeId);
}

/* resolves with Shop populated; same object every time (singleton) */
let _loadPromise = null;
function loadShop(){
  if(_loadPromise) return _loadPromise;
  _loadPromise = fetch('data.json', {cache:'no-store'})
    .then(r => { if(!r.ok) throw new Error('no data.json'); return r.json(); })
    .then(d => {
      if(!d || !Array.isArray(d.SMES) || !Array.isArray(d.P)) throw new Error('bad data.json');
      Shop.SMES = d.SMES;
      Shop.P = d.P;
      Shop.SLIDES = Array.isArray(d.SLIDES) ? d.SLIDES : [];
      Shop.CONFIG = Object.assign({}, CONFIG_DEFAULT, d.config || {});
      Shop.IS_SAMPLE = false;
      return Shop;
    })
    .catch(() => {
      Shop.SMES = SAMPLE_SMES;
      Shop.P = SAMPLE_P;
      Shop.SLIDES = SAMPLE_SLIDES;
      Shop.CONFIG = CONFIG_DEFAULT;
      Shop.IS_SAMPLE = true;
      return Shop;
    })
    .then(shop => {
      shop.SMES.forEach(x => { x.c = shop.P.filter(p => p.s === x.id).length; });
      return shop;
    });
  return _loadPromise;
}

/* ---------------------------------------------------------- */
/* basket — persisted so it survives moving between pages      */
/* ---------------------------------------------------------- */
const CART_KEY = 'mp_cart_v1';

function getCart(){
  try{
    const raw = window.localStorage.getItem(CART_KEY);
    const arr = raw ? JSON.parse(raw) : [];
    return Array.isArray(arr) ? arr : [];
  }catch(e){ return []; }
}
function saveCart(cart){
  try{ window.localStorage.setItem(CART_KEY, JSON.stringify(cart)); }catch(e){ /* storage unavailable — basket just won't persist */ }
}
function cartAdd(i, qty){
  qty = qty || 1;
  const cart = getCart();
  const e = cart.find(c => c.i === i);
  if(e) e.q += qty; else cart.push({i, q: qty});
  saveCart(cart);
  return cart;
}
function cartChange(idx, delta){
  const cart = getCart();
  if(!cart[idx]) return cart;
  cart[idx].q += delta;
  if(cart[idx].q <= 0) cart.splice(idx, 1);
  saveCart(cart);
  return cart;
}
function cartClear(){
  saveCart([]);
}
function cartCount(){
  return getCart().reduce((a,c) => a + c.q, 0);
}
function cartTotals(){
  const cart = getCart();
  const sub = cart.reduce((a,c) => { const p = getProduct(c.i); return a + (p ? p.p*c.q : 0); }, 0);
  const del = (sub > 150 || sub === 0) ? 0 : 15;
  return { cart, sub, del, total: sub + del };
}
