#!/usr/bin/env python3
"""Print the calendar's events for a date range as JSON (for desktop widgets).

    calview                          # today and the next 41 days
    calview --start 2026-10-26 --days 42
    calview add --calendar Personal --title Dentist \
        --start 2026-11-03T14:00 --end 2026-11-03T14:45
    calview add --calendar Personal --title "Tax form" --start 2026-11-16T12:00
    calview add --calendar Personal --title Holiday --start 2026-11-02 --all-day

Configuration (environment variables, or KEY=value lines in
~/.config/calview.conf; CALVIEW_CONF points elsewhere):

    CALDAV_URL       e.g. https://cal.example.com
    CALDAV_USER      the read-only "agenda" account is enough to read;
                     adding events needs your own account
    CALDAV_PASSWORD
    CALDAV_OWNER     whose calendars to show (default: CALDAV_USER)

Output: {"ok": true, "calendars": [...], "events": [...]}, events sorted by
start, times in this computer's time zone. `add` prints {"ok": true, "uid":
"..."}. On failure: {"ok": false, "error": "..."} and exit code 1 (3 for
configuration errors).

`add` without --end makes a deadline (an event with no length); with
--all-day, --start and --end are dates and --end is the last day (inclusive).

Needs Python 3.9+ with icalendar and recurring-ical-events; build.sh bundles
all of it into one executable (dist/calview), so nothing is installed globally.
Recurring events are expanded here, not by the server: Radicale's CalDAV
<expand> gets daylight saving, EXDATE and moved instances wrong.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid
import xml.etree.ElementTree as ET
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import quote, unquote, urljoin

try:
    import icalendar
    import recurring_ical_events
except ImportError:  # reported as JSON in main()
    icalendar = recurring_ical_events = None

CONFIG = Path(os.environ.get("CALVIEW_CONF") or Path.home() / ".config" / "calview.conf")
KEYS = ("CALDAV_URL", "CALDAV_USER", "CALDAV_PASSWORD", "CALDAV_OWNER")
NS = {"d": "DAV:", "c": "urn:ietf:params:xml:ns:caldav", "a": "http://apple.com/ns/ical/"}
TIMEOUT = 20


class Failure(Exception):
    def __init__(self, message: str, code: int = 1):
        super().__init__(message)
        self.code = code


def load_config() -> dict[str, str]:
    config: dict[str, str] = {}
    if CONFIG.exists():
        for line in CONFIG.read_text().splitlines():
            key, sep, value = line.strip().partition("=")
            if sep and not key.startswith("#"):
                config[key.strip()] = value.strip().strip('"').strip("'")
    for key in KEYS:
        if os.environ.get(key):
            config[key] = os.environ[key]
    return config


class Client:
    def __init__(self, url: str, user: str, password: str):
        self.base = url.rstrip("/") + "/"
        token = base64.b64encode(f"{user}:{password}".encode()).decode()
        self.headers = {"Authorization": f"Basic {token}", "User-Agent": "calview",
                        "Content-Type": "application/xml; charset=utf-8"}

    def request(self, method: str, path: str, body: str, depth: str = "1") -> ET.Element:
        req = urllib.request.Request(urljoin(self.base, path.lstrip("/")), data=body.encode(),
                                     method=method, headers={**self.headers, "Depth": depth})
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                return ET.fromstring(resp.read())
        except urllib.error.HTTPError as e:
            if e.code == 401:
                raise Failure("login failed: check CALDAV_USER and CALDAV_PASSWORD", 3) from e
            if e.code in (403, 404):
                raise Failure(f"no access to {path}: check CALDAV_OWNER", 3) from e
            raise Failure(f"{method} {path}: HTTP {e.code}") from e
        except (urllib.error.URLError, OSError) as e:
            raise Failure(f"could not reach {self.base}: {getattr(e, 'reason', e)}") from e
        except ET.ParseError as e:
            raise Failure(f"{method} {path}: unreadable answer") from e

    def put(self, path: str, ical: bytes) -> None:
        """Store a new object; never overwrites one (If-None-Match: *)."""
        req = urllib.request.Request(urljoin(self.base, path.lstrip("/")), data=ical, method="PUT", headers={
            **self.headers, "Content-Type": "text/calendar; charset=utf-8", "If-None-Match": "*"})
        try:
            urllib.request.urlopen(req, timeout=TIMEOUT).close()
        except urllib.error.HTTPError as e:
            if e.code == 401:
                raise Failure("login failed: check CALDAV_USER and CALDAV_PASSWORD", 3) from e
            if e.code == 403:
                raise Failure("this account may not add events here (the agenda account is read-only)", 3) from e
            raise Failure(f"PUT {path}: HTTP {e.code}") from e
        except (urllib.error.URLError, OSError) as e:
            raise Failure(f"could not reach {self.base}: {getattr(e, 'reason', e)}") from e

    def calendars(self, owner: str) -> list[dict]:
        body = """<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:a="http://apple.com/ns/ical/">
  <d:prop><d:resourcetype/><d:displayname/><a:calendar-color/></d:prop>
</d:propfind>"""
        result = []
        for response in self.request("PROPFIND", f"/{quote(owner)}/", body).findall("d:response", NS):
            href = unquote(response.findtext("d:href", namespaces=NS) or "")
            prop = response.find("d:propstat/d:prop", NS)
            if prop is None or prop.find("d:resourcetype/c:calendar", NS) is None:
                continue
            name = prop.findtext("d:displayname", namespaces=NS) or href.rstrip("/").rsplit("/", 1)[-1]
            color = (prop.findtext("a:calendar-color", namespaces=NS) or "").strip()
            # Apple clients store #RRGGBBAA; keep #RRGGBB.
            color = color[:7] if re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", color) else None
            result.append({"path": href, "name": name, "color": color})
        result.sort(key=lambda c: c["name"].casefold())
        return result

    def objects(self, path: str, start: datetime, end: datetime) -> list[str]:
        """calendar-data of every object with an event in [start, end) (recurring ones included)."""
        s, e = (t.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ") for t in (start, end))
        body = f"""<?xml version="1.0" encoding="utf-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><c:calendar-data/></d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VEVENT"><c:time-range start="{s}" end="{e}"/></c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>"""
        root = self.request("REPORT", path, body)
        return [data for r in root.findall("d:response", NS)
                if (data := r.findtext("d:propstat/d:prop/c:calendar-data", namespaces=NS))]


# ---- iCalendar ---------------------------------------------------------------

def local(value: datetime | date) -> datetime | date:
    """Dates stay dates; times move to this computer's zone (floating ones are read as local)."""
    # astimezone() reads a naive (floating) time as local time.
    return value.astimezone() if isinstance(value, datetime) else value


def text(comp, name: str) -> str:
    value = comp.get(name)
    return str(value).strip() if value is not None else ""


def occurrences(ical: str, calendar: dict, start: datetime, end: datetime) -> list[dict]:
    """Every VEVENT instance of one stored object that overlaps [start, end)."""
    try:
        components = recurring_ical_events.of(icalendar.Calendar.from_ical(ical)).between(start, end)
    except Exception:
        return []  # one broken object should not hide the rest
    result = []
    for comp in components:
        if comp.name != "VEVENT" or comp.get("dtstart") is None:
            continue
        if text(comp, "status").upper() == "CANCELLED":
            continue
        first = local(comp["dtstart"].dt)
        all_day = not isinstance(first, datetime)
        if comp.get("dtend") is not None:
            last = local(comp["dtend"].dt)
        elif comp.get("duration") is not None:
            last = first + comp["duration"].dt
        else:
            last = first + timedelta(days=1) if all_day else first
        if isinstance(last, datetime) != isinstance(first, datetime):
            last = first + timedelta(days=1) if all_day else first  # broken event: DATE start, DATE-TIME end
        result.append({
            "uid": text(comp, "uid"),
            "title": text(comp, "summary") or "(no title)",
            "start": first.isoformat(),
            "end": max(last, first).isoformat(),
            "allDay": all_day,
            "location": text(comp, "location"),
            "description": text(comp, "description"),
            "calendar": calendar["name"],
            "color": calendar["color"],
            "uncertain": text(comp, "x-ingest-status").upper() == "UNCERTAIN",
            "free": text(comp, "transp").upper() == "TRANSPARENT",
        })
    return result


def collect(config: dict[str, str], first: date, days: int) -> dict:
    client = client_for(config)
    start = datetime.combine(first, datetime.min.time()).astimezone()
    end = datetime.combine(first + timedelta(days=days), datetime.min.time()).astimezone()
    calendars = client.calendars(config.get("CALDAV_OWNER") or config["CALDAV_USER"])
    events = []
    for cal in calendars:
        for data in client.objects(cal["path"], start, end):
            events.extend(occurrences(data, cal, start, end))
    events.sort(key=lambda e: (e["start"][:10], not e["allDay"], e["start"], e["title"].casefold()))
    return {"ok": True, "calendars": [{"name": c["name"], "color": c["color"]} for c in calendars],
            "events": events}


def client_for(config: dict[str, str]) -> Client:
    url, user, password = (config.get(k) for k in KEYS[:3])
    if not url or not user or not password:
        raise Failure(f"set CALDAV_URL, CALDAV_USER and CALDAV_PASSWORD (environment or {CONFIG})", 3)
    return Client(url, user, password)


def add(config: dict[str, str], args: argparse.Namespace) -> dict:
    """Create one event. Times without an offset are local time."""
    title = args.title.strip()
    if not title:
        raise Failure("the title is empty", 3)
    client = client_for(config)
    calendars = client.calendars(config.get("CALDAV_OWNER") or config["CALDAV_USER"])
    calendar = next((c for c in calendars if c["name"].casefold() == args.calendar.casefold()), None)
    if calendar is None:
        raise Failure(f"no calendar called {args.calendar!r}", 3)

    event = icalendar.Event()
    uid = f"{uuid.uuid4()}@calview"
    event.add("uid", uid)
    event.add("dtstamp", datetime.now(timezone.utc))
    event.add("summary", title)
    try:
        if args.all_day:
            first = date.fromisoformat(args.start[:10])
            last = date.fromisoformat(args.end[:10]) if args.end else first
            if last < first:
                raise Failure("the event ends before it starts", 3)
            event.add("dtstart", first)
            event.add("dtend", last + timedelta(days=1))
        else:
            # Stored in UTC: unambiguous, and needs no VTIMEZONE.
            start = datetime.fromisoformat(args.start).astimezone(timezone.utc)
            event.add("dtstart", start)
            if args.end:  # no end: a deadline, an event with no length
                end = datetime.fromisoformat(args.end).astimezone(timezone.utc)
                if end < start:
                    raise Failure("the event ends before it starts", 3)
                event.add("dtend", end)
    except ValueError as e:
        raise Failure(f"unreadable date or time: {e}", 3) from e
    if args.location and args.location.strip():
        event.add("location", args.location.strip())
    cal = icalendar.Calendar()
    cal.add("prodid", "-//calview//EN")
    cal.add("version", "2.0")
    cal.add_component(event)
    client.put(f"{calendar['path'].rstrip('/')}/{uid}.ics", cal.to_ical())
    return {"ok": True, "uid": uid}


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ["add"]:
        parser = argparse.ArgumentParser(prog="calview add", description="Add an event.")
        parser.add_argument("--calendar", required=True, help="calendar name, e.g. Personal")
        parser.add_argument("--title", required=True)
        parser.add_argument("--start", required=True, help="YYYY-MM-DDTHH:MM (local), or YYYY-MM-DD with --all-day")
        parser.add_argument("--end", help="like --start; leave out for a deadline")
        parser.add_argument("--all-day", action="store_true")
        parser.add_argument("--location")
        args = parser.parse_args(argv[1:])
        run = lambda config: add(config, args)
    else:
        parser = argparse.ArgumentParser(description="Print calendar events as JSON.")
        parser.add_argument("--start", type=date.fromisoformat, default=date.today(), help="first day (YYYY-MM-DD)")
        parser.add_argument("--days", type=int, default=42, help="number of days (default 42)")
        args = parser.parse_args(argv)
        run = lambda config: collect(config, args.start, max(1, min(args.days, 400)))
    if recurring_ical_events is None:
        print(json.dumps({"ok": False, "error": "missing Python packages: install python-recurring-ical-events "
                                                "(or pip install recurring-ical-events)"}))
        return 3
    try:
        result = run(load_config())
    except Failure as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        return e.code
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
