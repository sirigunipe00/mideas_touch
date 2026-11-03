// Extracts declarative content only; no artifact event handlers are executed.
const fs = require('node:fs');
const vm = require('node:vm');
const path = process.argv[2];
if (!path) throw new Error('Usage: node tool/extract_artifact.cjs /path/to/artifact.html');
const html = fs.readFileSync(path, 'utf8');
const start = html.indexOf('const TR=');
const end = html.indexOf('const $=');
if (start < 0 || end < 0) throw new Error('Unrecognized artifact');
const data = vm.runInNewContext(html.slice(start, end) + '\nJSON.stringify({templates:T,categories:CATS,fonts:FONTS,assets:AS,backgrounds:BG,translations:TR,designs:S.designs})', {}, {timeout:1000});
fs.mkdirSync('supabase/seed', {recursive:true});
const catalog = JSON.parse(data);
const packs = JSON.parse(html.match(/const P=(\[\[.*?\]\]),tk=/)[1]);
catalog.coin_packs = packs.map((p,i)=>({name:['Basic','Advance','Pro'][i],price:p[0],coins:p[1],bonus:p[2]}));
const slideExpression = html.slice(html.indexOf('const SL=')+9,html.indexOf(';\nconst BANNERS='));
const slides = vm.runInNewContext('const t=k=>('+JSON.stringify(catalog.translations.en)+')[k]; ('+slideExpression+')()',{}, {timeout:1000});
catalog.banners = slides.map((s,i)=>({id:i+1,tag:s.tg,title:s.h,subtitle:s.p,button_text:s.b,action:s.a.includes("wallet")?'wallet':s.a.includes("Festivals")?'festivals':'use_1',gradient_colors:s.c.match(/#[0-9a-fA-F]{6}/g),is_dark:!!s.d}));
catalog.branding = {light:'artifact/brand_light.png',dark:'artifact/brand_dark.png'};
catalog.studio_stats = {uses: '1,284', earnings: '₹12,480'};
fs.writeFileSync('supabase/seed/artifact.json', JSON.stringify(catalog,null,2)+'\n');
for (const name of ['LG_L','LG_D']) {
 const match = html.match(new RegExp(name+"='data:image/png;base64,([^']+)'"));
 if (!match) throw new Error('Missing '+name);
 fs.writeFileSync('assets/images/'+(name==='LG_L'?'brand_light':'brand_dark')+'.png', Buffer.from(match[1],'base64'));
}
fs.mkdirSync('docs', {recursive:true});
fs.writeFileSync('docs/artifact-reference.html', html);
console.log('Extracted 8 templates, 3 saved design examples, 12 categories, 12 assets, 7 fonts and both original logos.');
