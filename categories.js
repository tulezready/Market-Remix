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
     {key:"cocoa",   label:"Cocoa Production & Processing"},
     {key:"copra",   label:"Copra & Coconut Products"},
     {key:"galip",   label:"Galip Nut Industry"},
     {key:"produce", label:"Fresh Produce & Horticulture"},
   ]},
  {key:"tourism", label:"Tourism & Hospitality", short:"Tourism & Hospitality",
   icon:"ic-tourism", bg:"#FBE1EC", fg:"#9C2A5D",                    // Sulka pink
   subs:[
     {key:"accommodation", label:"Accommodation & Guest Houses"},
     {key:"tours",         label:"Tour and Travel Services"},
     {key:"food_service",  label:"Restaurants, Cafes & Kaibars"},
     {key:"arts_crafts",   label:"Arts, Crafts & Tailoring"},
   ]},
  {key:"fisheries", label:"Fisheries & Marine Resources", short:"Fisheries & Marine",
   icon:"ic-fisheries", bg:"#DCEEEF", fg:"#0F5C68",                  // harbour teal
   subs:[
     {key:"coastal_fishing", label:"Coastal Fishing & Trading"},
     {key:"fish_farming",    label:"Inland Fish Farming"},
   ]},
  {key:"trade", label:"Retail, Wholesale & General Trade", short:"Retail & Wholesale",
   icon:"ic-retail", bg:"#FBF0D2", fg:"#7D5A0C",                     // kumul gold
   subs:[
     {key:"trade_stores", label:"Trade Stores & Supermarkets"},
     {key:"distribution", label:"Local Distributorships"},
   ]},
  {key:"transport", label:"Transport & Logistics", short:"Transport & Logistics",
   icon:"ic-transport", bg:"#ECE8E3", fg:"#4F4943",                  // Tavurvur ash
   subs:[
     {key:"pmv_taxi",     label:"PMV (Public Motor Vehicles) & Taxi Services"},
     {key:"cargo_rental", label:"Cargo & Freight/Car Rentals"},
   ]},
  {key:"services", label:"Professional, Construction & Technical Services", short:"Professional & Technical",
   icon:"ic-services", bg:"#F1E4D8", fg:"#5B3220",                   // Gazelle cocoa
   subs:[
     {key:"construction", label:"Building & Civil Construction"},
     {key:"it_office",    label:"Information Technology & Office Services"},
   ]},
];

const catByKey = k => CATEGORIES.find(c => c.key === k) || null;
const subByKey = k => { for(const c of CATEGORIES){ const s = c.subs.find(x => x.key === k); if(s) return s; } return null; };
const catOfSub = k => CATEGORIES.find(c => c.subs.some(s => s.key === k)) || null;
const catLabel = k => (catByKey(k) || {}).label || "Other";
const catShort = k => (catByKey(k) || {}).short || "Other";
const subLabel = k => (subByKey(k) || {}).label || "";
/* "Agriculture & Farming · Galip Nut Industry" */
const catLine  = (cat, sub, short) => [short === false ? catLabel(cat) : catShort(cat), subLabel(sub)].filter(Boolean).join(" · ");
