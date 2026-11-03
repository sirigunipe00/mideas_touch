"""Bundle original Google Fonts TTFs so the application works without font HTTP requests."""
from pathlib import Path
import urllib.request, re, json
catalog=json.loads(Path('supabase/seed/artifact.json').read_text())
Path('assets/fonts').mkdir(parents=True,exist_ok=True)
for family in catalog['fonts']:
    weights=[400,600,700] if family in ['Poppins','Hind'] else [400,700] if family in ['Playfair Display','Noto Sans Devanagari'] else [600] if family=='Baloo 2' else [400]
    for weight in weights:
        url='https://fonts.googleapis.com/css?family='+urllib.parse.quote(family)+':'+str(weight)+'&subset=latin,devanagari'
        css=urllib.request.urlopen(url,timeout=30).read().decode()
        fonts=re.findall(r'url\((https:[^)]+\.ttf)\)',css)
        if not fonts: raise RuntimeError('No TTF for '+family)
        suffix={400:'Regular',600:'SemiBold',700:'Bold'}[weight]
        path=Path('assets/fonts')/(family.replace(' ','')+'-'+suffix+'.ttf')
        if not path.exists(): path.write_bytes(urllib.request.urlopen(fonts[-1],timeout=30).read())
        print(path)

licenses=[]
for family in catalog['fonts']:
    slug=family.lower().replace(' ','')
    license_url='https://raw.githubusercontent.com/google/fonts/main/ofl/'+slug+'/OFL.txt'
    license_text=urllib.request.urlopen(license_url,timeout=30).read().decode()
    licenses.append('## '+family+'\n\nSource: '+license_url+'\n\n'+license_text)
Path('assets/fonts/OFL-LICENSES.txt').write_text('\n\n'.join(licenses))
print('Bundled original font licenses.')
