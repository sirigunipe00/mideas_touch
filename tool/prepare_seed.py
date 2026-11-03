"""Generate SQL from the extracted artifact, preserving its original JSON."""
import json
from pathlib import Path

data = json.loads(Path('supabase/seed/artifact.json').read_text())
def sql(v):
    return "'" + str(v).replace("'", "''") + "'"
def js(v):
    return sql(json.dumps(v, ensure_ascii=False)) + '::jsonb'
lines = []
for d in data['templates']:
    values = [str(d['id']), sql(d['name']), sql(d['cat']), sql(d['desc']), js(d['bg']), sql(''), sql(d['by']), str(d['pm']).lower(), str(d['cost']), js(d['els'])]
    lines.append('INSERT INTO public.templates (id,name,category,description,bg,bi,created_by,is_premium,cost,elements) VALUES (' + ','.join(values) + ') ON CONFLICT (id) DO NOTHING;')
for b in data['banners']:
    values = [str(b['id']),sql(b['tag']),sql(b['title']),sql(b['subtitle']),sql(b['button_text']),sql(b['action']),js(b['gradient_colors']),str(b['is_dark']).lower()]
    lines.append('INSERT INTO public.banners (id,tag,title,subtitle,button_text,action,gradient_colors,is_dark) VALUES (' + ','.join(values) + ') ON CONFLICT (id) DO NOTHING;')
config = {k: v for k, v in data.items() if k not in ['templates']}
lines.append('INSERT INTO public.app_content (id,content) VALUES (\'artifact\',' + js(config) + ') ON CONFLICT (id) DO NOTHING;')
Path('supabase/seed.sql').write_text('\n'.join(lines)+'\n')
