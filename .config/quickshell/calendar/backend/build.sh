#!/bin/sh
# Build dist/calview: one executable with Python, icalendar and
# recurring-ical-events inside, so nothing has to be installed system-wide.
# Everything for the build stays in this directory (.venv, build/, dist/).
set -e
cd "$(dirname "$0")"
[ -x .venv/bin/python ] || python3 -m venv .venv
.venv/bin/pip install --quiet --upgrade pip
.venv/bin/pip install --quiet "icalendar==7.3.0" "recurring-ical-events==3.8.2" "pyinstaller==6.*"
.venv/bin/pyinstaller --onefile --name calview --clean --noconfirm \
    --distpath dist --workpath build --specpath build calview.py >/dev/null
echo "built $(pwd)/dist/calview"
