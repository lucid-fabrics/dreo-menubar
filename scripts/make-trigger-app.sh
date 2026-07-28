#!/bin/bash
# Builds a tiny app that fires one DreoBar URL and quits.
#
# Macro key software (Corsair iCUE, Logitech G HUB, Stream Deck) binds keys to
# applications rather than URLs, and swallows the keypress so it never reaches
# DreoBar as a shortcut. Pointing a macro key at one of these apps is how a
# G-key ends up controlling a specific fan.
#
#   ./make-trigger-app.sh "Tower Fan Toggle" "dreobar://toggle?device=SERIAL"
#
# Get a fan's URL from its ... menu in the menu bar, via Copy Trigger Link.

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "usage: $0 <app name> <dreobar:// url>" >&2
    echo "example: $0 \"Fan Faster\" \"dreobar://adjust?device=SERIAL&key=windlevel&delta=1\"" >&2
    exit 1
fi

NAME="$1"
URL="$2"
DEST="${TRIGGER_APP_DIR:-$HOME/Applications}/${NAME}.app"

case "$URL" in
    dreobar://*) ;;
    *) echo "error: url must start with dreobar://" >&2; exit 1 ;;
esac

rm -rf "$DEST"
# Single quotes around the URL keep & from being read as a shell operator.
osacompile -o "$DEST" -e "do shell script \"open '${URL}'\"" >/dev/null

echo "created $DEST"
echo "  fires: $URL"
echo
echo "Now bind a key to it: in iCUE, assign the G-key to Launch Application"
echo "and pick this app."
