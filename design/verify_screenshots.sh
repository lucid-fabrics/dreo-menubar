#!/bin/bash
# Report the TRUE screenshot state of the current App Store version, and optionally
# remove duplicates.
#
# deliver appends rather than replaces, so repeated push_metadata runs pile up
# superseded screenshots. The set-listing endpoint is also cached and reports rows
# that no longer exist, so every candidate is confirmed individually.
#
#   ./design/verify_screenshots.sh          report only
#   ./design/verify_screenshots.sh --fix    also delete duplicates, keeping one per file
set -eo pipefail
cd "$(dirname "$0")/.."
: "${APP_STORE_CONNECT_API_KEY_ID:?set APP_STORE_CONNECT_API_KEY_ID}"
: "${APP_STORE_CONNECT_API_ISSUER_ID:?set APP_STORE_CONNECT_API_ISSUER_ID}"
: "${APP_STORE_CONNECT_API_KEY_CONTENT:?set APP_STORE_CONNECT_API_KEY_CONTENT}"
FIX="${1:-}"
APP_ID=6796354199 FIX="$FIX" python3 - <<'PY'
import os, time, json, urllib.request, jwt

KEY_ID = os.environ['APP_STORE_CONNECT_API_KEY_ID']
ISSUER = os.environ['APP_STORE_CONNECT_API_ISSUER_ID']
KEY    = os.environ['APP_STORE_CONNECT_API_KEY_CONTENT']
APP    = os.environ['APP_ID']
FIX    = os.environ.get('FIX') == '--fix'

def call(method, path):
    now = int(time.time())
    tok = jwt.encode({'iss': ISSUER, 'iat': now, 'exp': now + 900,
                      'aud': 'appstoreconnect-v1'}, KEY, algorithm='ES256',
                     headers={'kid': KEY_ID, 'typ': 'JWT'})
    req = urllib.request.Request('https://api.appstoreconnect.apple.com' + path,
                                 method=method,
                                 headers={'Authorization': 'Bearer ' + tok})
    try:
        raw = urllib.request.urlopen(req).read()
        return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        return {'err': e.code}

ver = call('GET', f'/v1/apps/{APP}/appStoreVersions?limit=1')['data'][0]['id']
loc = call('GET', f'/v1/appStoreVersions/{ver}/appStoreVersionLocalizations')['data'][0]['id']
sets = call('GET', f'/v1/appStoreVersionLocalizations/{loc}/appScreenshotSets')['data']
if not sets:
    print('no screenshot set yet'); raise SystemExit(0)

sid = sets[0]['id']
inc = [i for i in call('GET', f'/v1/appScreenshotSets/{sid}?include=appScreenshots')
       .get('included', []) if i['type'] == 'appScreenshots']

live = []
for i in inc:                                   # the listing lies; confirm each one
    r = call('GET', f"/v1/appScreenshots/{i['id']}")
    if 'err' not in r:
        live.append((r['data']['attributes']['fileName'], i['id']))

seen = {}
for fn, i in sorted(live):
    seen.setdefault(fn, []).append(i)
print('screenshots actually on the listing: %d' % len(live))
dupes = []
for fn, ids in sorted(seen.items()):
    print('  %-20s x%d' % (fn, len(ids)))
    dupes.extend(ids[1:])

if not dupes:
    print('no duplicates'); raise SystemExit(0)
if not FIX:
    print('\n%d duplicate(s). Re-run with --fix to remove them.' % len(dupes))
    raise SystemExit(1)
for i in dupes:
    call('DELETE', f'/v1/appScreenshots/{i}')
    print('  deleted', i[:8])
print('kept one per file')
PY
