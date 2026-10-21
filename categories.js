/* ============================================================
   MaketPles ENB — business categories
   The Division's "Type of MSME listing": six main categories, each
   with its own sub-categories. Every page reads this one list, so a
   change here changes the register form, shop, seller portal and
   Division panel together. tools/build-form.py has the same list for
   the paper form — keep the two in step.

   key   — stored in the database (smes.primary_industry,
           products.category; sub-categories in .subcategory)
   bg/fg — tile and chip colours on the home and shop pages
   ============================================================ */
const CATEGORIES = [
  {key:"agriculture", label:"Agriculture, Farming & Agribusiness", short:"Agriculture & Farming",
   icon:"ic-agriculture", bg:"#E2F0E2", fg:"#24662F",                // leaf green
   subs:[
     {key:"cocoa",   label:"Cocoa Production & Processing", set:"supply"},
     {key:"copra",   label:"Copra & Coconut Products", set:"supply"},
     {key:"galip",   label:"Galip Nut Industry", set:"supply"},
     {key:"produce", label:"Fresh Produce & Horticulture", set:"supply"},
   ]},
  {key:"tourism", label:"Tourism & Hospitality", short:"Tourism & Hospitality",
   icon:"ic-tourism", bg:"#FBE1EC", fg:"#9C2A5D",                    // Sulka pink
   subs:[
     {key:"accommodation", label:"Accommodation & Guest Houses", set:"stay", mode:"book"},
     {key:"tours",         label:"Tour and Travel Services", set:"tours", mode:"book"},
     {key:"food_service",  label:"Restaurants, Cafes & Kaibars", set:"food", mode:"quote"},
     {key:"arts_crafts",   label:"Arts, Crafts & Tailoring", set:"crafts"},
   ]},
  {key:"fisheries", label:"Fisheries & Marine Resources", short:"Fisheries & Marine",
   icon:"ic-fisheries", bg:"#DCEEEF", fg:"#0F5C68",                  // harbour teal
   subs:[
     {key:"coastal_fishing", label:"Coastal Fishing & Trading", set:"fish"},
     {key:"fish_farming",    label:"Inland Fish Farming", set:"fish"},
   ]},
  {key:"trade", label:"Retail, Wholesale & General Trade", short:"Retail & Wholesale",
   icon:"ic-retail", bg:"#FBF0D2", fg:"#7D5A0C",                     // kumul gold
   subs:[
     {key:"trade_stores", label:"Trade Stores & Supermarkets", set:"trade"},
     {key:"distribution", label:"Local Distributorships", set:"trade"},
   ]},
  {key:"transport", label:"Transport & Logistics", short:"Transport & Logistics",
   icon:"ic-transport", bg:"#ECE8E3", fg:"#4F4943",                  // Tavurvur ash
   subs:[
     {key:"pmv_taxi",     label:"PMV (Public Motor Vehicles) & Taxi Services", set:"pmv", mode:"quote"},
     {key:"cargo_rental", label:"Cargo & Freight/Car Rentals", set:"cargo", mode:"book"},
   ]},
  {key:"services", label:"Professional, Construction & Technical Services", short:"Professional & Technical",
   icon:"ic-services", bg:"#F1E4D8", fg:"#5B3220",                   // Gazelle cocoa
   subs:[
     {key:"construction", label:"Building & Civil Construction", set:"build", mode:"quote"},
     {key:"it_office",    label:"Information Technology & Office Services", set:"office", mode:"quote"},
   ]},
];

/* ------------------------------------------------------------
   Questions for each type of business. The register form shows the
   set for the chosen sub-category, and the answers are saved with the
   application (seller_applications.details). The paper form's page 3
   asks the same questions — see tools/build-form.py.

   goods    true = a products table (price, per what, how many);
            false = a services table (price per night, trip, job...)
   q        k: key saved in details · t: text | num | yesno | pick | checks
   ------------------------------------------------------------ */
const HOURS = {k:"hours", t:"text", label:"Opening days and hours", ph:"e.g. Mon–Sat, 7am–6pm"};
const QSETS = {
  supply: {goods:true, title:"What you grow or make",
    q:[{k:"supply_month", t:"text", label:"How much can you supply each month?", ph:"e.g. 20 bags of 60kg"},
       {k:"season", t:"text", label:"Which months is it available?", ph:"All year, or e.g. March to July"}]},
  fish: {goods:true, title:"Your catch",
    q:[{k:"catch", t:"text", label:"What do you catch or farm?", ph:"e.g. reef fish, tuna, tilapia, mud crab"},
       {k:"sold_as", t:"checks", label:"Sold as", opts:["Fresh","Smoked","Frozen","Dried"]},
       {k:"per_week", t:"text", label:"How much can you sell each week?", ph:"e.g. 30kg"},
       {k:"cooler", t:"yesno", label:"Do you have a cooler or freezer to keep it fresh?"}]},
  trade: {goods:true, title:"Your shop",
    q:[HOURS,
       {k:"delivers", t:"yesno", label:"Do you deliver?"},
       {k:"delivery_area", t:"text", label:"If you deliver, where to?", ph:"e.g. anywhere in Kokopo town"}]},
  crafts: {goods:true, title:"Your work",
    q:[{k:"to_order", t:"yesno", label:"Do you make things to order?"},
       {k:"make_time", t:"text", label:"How long does one take to make?", ph:"e.g. two weeks for a large bilum"}]},
  stay: {goods:false, title:"Your rooms", item:"Room or rate", itemPh:"e.g. Double room with shower", unitPh:"per night",
    q:[{k:"rooms", t:"num", label:"Number of rooms"},
       {k:"guests", t:"num", label:"Most guests at one time"},
       {k:"meals", t:"pick", label:"Meals", opts:["Not included","Breakfast included","All meals included","On request"]},
       {k:"facilities", t:"checks", label:"Facilities", opts:["Power","Running water","Shower","Flush toilet","Wi-Fi","Air conditioning","Parking"]},
       {k:"landmark", t:"text", label:"How do guests find you?", ph:"e.g. 200m past Toma market, blue roof"}]},
  tours: {goods:false, title:"Your tours", item:"Tour", itemPh:"e.g. Half-day harbour and volcano tour", unitPh:"per person",
    q:[{k:"duration", t:"text", label:"How long is each tour?", ph:"e.g. 4 hours"},
       {k:"group", t:"num", label:"Largest group you can take"},
       {k:"days", t:"text", label:"Days offered", ph:"e.g. every day except Sunday"},
       {k:"meet", t:"text", label:"Where do guests meet you?", ph:"e.g. Rabaul market wharf"},
       {k:"included", t:"text", label:"What is included?", ph:"e.g. boat, guide, lunch, water"}]},
  food: {goods:false, title:"Your menu", item:"Dish or meal", itemPh:"e.g. Fish and chips", unitPh:"per plate",
    q:[HOURS,
       {k:"seats", t:"num", label:"How many seats?"},
       {k:"service", t:"checks", label:"You offer", opts:["Dine in","Takeaway","Catering for events"]}]},
  pmv: {goods:false, title:"Your vehicles and fares", item:"Route or trip", itemPh:"e.g. Kokopo to Rabaul", unitPh:"per person",
    q:[{k:"vehicle", t:"pick", label:"Vehicle type", opts:["PMV bus, 15 seats","PMV bus, 25 seats or more","PMV truck","Taxi","Banana boat","Other"]},
       {k:"vehicles", t:"num", label:"Number of vehicles"},
       {k:"licence", t:"text", label:"PMV or taxi licence number", ph:"From your permit"},
       HOURS]},
  cargo: {goods:false, title:"Your vehicles and rates", item:"Service", itemPh:"e.g. Truck hire with driver", unitPh:"per day · per trip · per km",
    q:[{k:"vehicle", t:"text", label:"Vehicle type and size", ph:"e.g. 5-tonne truck, Hilux twin cab"},
       {k:"vehicles", t:"num", label:"Number of vehicles"},
       {k:"areas", t:"text", label:"Areas you serve", ph:"e.g. Gazelle Peninsula, Kokopo to Kerevat"},
       {k:"driver", t:"pick", label:"Driver included?", opts:["Yes","No","Either"]},
       {k:"licence", t:"text", label:"Licence or permit number"}]},
  build: {goods:false, title:"Your work and rates", item:"Work or service", itemPh:"e.g. Build a 3-bedroom house", unitPh:"per job · per day · per m²",
    q:[{k:"work", t:"checks", label:"Work you do", opts:["Houses and buildings","Roads and civil works","Plumbing","Electrical","Carpentry and joinery","Other"]},
       {k:"licence", t:"text", label:"Licence or trade certificate", ph:"Name and number"},
       {k:"workers", t:"num", label:"How many workers?"},
       {k:"equipment", t:"text", label:"Main equipment", ph:"e.g. concrete mixer, tip truck"},
       {k:"jobs", t:"text", label:"Recent jobs", ph:"e.g. classroom at Vunadidir, 2025"}]},
  office: {goods:false, title:"Your services and prices", item:"Service", itemPh:"e.g. Colour printing, A4", unitPh:"per page · per hour · per job",
    q:[{k:"offered", t:"checks", label:"You offer", opts:["Printing and photocopying","Typing and documents","Computer repair","Phone repair","Internet access","Training","Other"]},
       HOURS]},
};
/* How a listing works on the site. Set per sub-category above (default
   "buy"); a seller can switch one listing, e.g. a bulk lot to "quote".
   The database has the same defaults: sub_mode() in db/requests.sql. */
const MODES = {
  buy:   {btn:"Add to basket"},
  book:  {btn:"Request a booking", title:"Request a booking", kind:"booking"},
  quote: {btn:"Ask for a quote",   title:"Ask for a quote",   kind:"quote"},
};
const modeOf = p => (p && (p.mode || (subByKey(p.sub) || {}).mode)) || "buy";

const qsetFor = sub => QSETS[(subByKey(sub) || {}).set] || null;
/* The questions for a sub-category as form fields (seller portal and Division
   panel), filled with saved answers; readQs() reads them back. Field ids are
   prefixed so two forms never clash. */
const qEsc = v => String(v == null ? "" : v).replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
function qsFormHTML(sub, d, pre){
  const qs = qsetFor(sub); d = d || {};
  if(!qs) return '<div class="hint">No extra questions for this type of business.</div>';
  return qs.q.map(q => {
    const v = d[q.k], id = pre + q.k;
    const lab = `<label for="${id}">${qEsc(q.label)}</label>`;
    if(q.t === "text") return `<div class="fr full">${lab}<input id="${id}" data-qk="${q.k}" value="${qEsc(v)}" placeholder="${qEsc(q.ph || "")}" maxlength="200"></div>`;
    if(q.t === "num")  return `<div class="fr">${lab}<input id="${id}" data-qk="${q.k}" value="${qEsc(v)}" inputmode="numeric" maxlength="10"></div>`;
    if(q.t === "pick") return `<div class="fr">${lab}<select id="${id}" data-qk="${q.k}"><option value="">Choose…</option>${q.opts.map(o => `<option${o === v ? " selected" : ""}>${qEsc(o)}</option>`).join("")}</select></div>`;
    const opts = q.t === "yesno" ? ["Yes","No"] : q.opts, type = q.t === "yesno" ? "radio" : "checkbox";
    const on = o => q.t === "yesno" ? o === v : (Array.isArray(v) && v.includes(o));
    return `<div class="fr${q.t === "checks" ? " full" : ""}"><label>${qEsc(q.label)}</label><div class="qchips">${opts.map(o =>
      `<label><input type="${type}" name="${id}" data-qk="${q.k}" value="${qEsc(o)}"${on(o) ? " checked" : ""}> ${qEsc(o)}</label>`).join("")}</div></div>`;
  }).join("");
}
function readQs(root){
  const out = {};
  root.querySelectorAll("[data-qk]").forEach(el => {
    const k = el.dataset.qk;
    if(el.type === "checkbox"){ out[k] = out[k] || []; if(el.checked) out[k].push(el.value); }
    else if(el.type === "radio"){ if(el.checked) out[k] = el.value; }
    else if(el.value.trim()) out[k] = el.value.trim().slice(0, 200);
  });
  Object.keys(out).forEach(k => { if(Array.isArray(out[k]) && !out[k].length) delete out[k]; });
  return out;
}

/* one line per answer, for the Division panel */
const detailLines = (sub, d) => {
  const qs = qsetFor(sub); if(!qs || !d) return [];
  return qs.q.filter(q => d[q.k] != null && d[q.k] !== '' && !(Array.isArray(d[q.k]) && !d[q.k].length))
    .map(q => [q.label, Array.isArray(d[q.k]) ? d[q.k].join(', ') : String(d[q.k])]);
};

const catByKey = k => CATEGORIES.find(c => c.key === k) || null;
const subByKey = k => { for(const c of CATEGORIES){ const s = c.subs.find(x => x.key === k); if(s) return s; } return null; };
const catOfSub = k => CATEGORIES.find(c => c.subs.some(s => s.key === k)) || null;
const catLabel = k => (catByKey(k) || {}).label || "Other";
const catShort = k => (catByKey(k) || {}).short || "Other";
const subLabel = k => (subByKey(k) || {}).label || "";
/* "Agriculture & Farming · Galip Nut Industry" */
const catLine  = (cat, sub, short) => [short === false ? catLabel(cat) : catShort(cat), subLabel(sub)].filter(Boolean).join(" · ");
