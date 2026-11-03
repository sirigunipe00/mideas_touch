"""Upload only missing original assets after the target schema has been inspected/applied.
Use a service role key locally in the environment; never put it in Flutter config.
"""
import json, os, urllib.request, urllib.error
from pathlib import Path
url=os.environ['SUPABASE_URL'].rstrip('/')
key=os.environ['SUPABASE_SERVICE_ROLE_KEY']
headers={'apikey':key,'Authorization':'Bearer '+key}
for name in ['brand_light.png','brand_dark.png']:
    path='artifact/'+name
    public=url+'/storage/v1/object/public/design-assets/'+path
    try:
        urllib.request.urlopen(urllib.request.Request(public,method='HEAD'),timeout=30)
        print('Preserved existing asset:',path)
        continue
    except urllib.error.HTTPError as error:
        if error.code not in (400,404): raise
    request=urllib.request.Request(url+'/storage/v1/object/design-assets/'+path,
        data=Path('assets/images',name).read_bytes(),method='POST',
        headers={**headers,'Content-Type':'image/png','x-upsert':'false'})
    with urllib.request.urlopen(request,timeout=30) as response:
        print('Uploaded original:',path,response.status)
