# Calendar Quickshell client

Quickshell (Hyprland) client for the self-hosted Calendar (`~/github/Calendar`):

- **Send bar** (`calendar/CalSend.qml`): select text anywhere, press the hotkey, add a
  note, Enter. The text goes to the calendar's LLM ingest API; the result arrives as a
  notification.
- **Calendar view** (`calendar/CalView.qml`): the month as a grid of mini timelines
  (09–20, bar height = duration) and the selected day's agenda, plus a form to add
  events. Deadlines, events with no length, are dashed lines with a flag chip.

It lives in this Quickshell config: the QML here and in `services/`, the backend
in `backend/`. It uses the shell's `Theme` and `Anim` singletons (`import qs`).

| File | What |
|------|------|
| `backend/calview.py` | Reads events from Radicale over CalDAV as JSON; `calview.py add` creates one |
| `backend/calsend.py` | Send bar's client for the ingest API (copy of the Calendar repo's `clients/calsend.py`) |
| `backend/build.sh` | Builds `backend/dist/calview`, a single executable of `calview.py` with its libraries |
| `calendar/CalSend.qml` | Send bar |
| `calendar/CalView.qml` | Calendar view window (month grid, agenda/form) |
| `calendar/MonthCell.qml`, `DayAgenda.qml`, `AddEvent.qml`, `IconButton.qml`, `DashedLine.qml` | Its parts |
| `services/CalendarData.qml` | Singleton: runs `calview`, view state, day layout |

## Requirements

- Quickshell, Hyprland, `wl-clipboard`, `libnotify` (`notify-send`), Python 3.9+
- For the send bar: `backend/calsend.py`, a copy of the Calendar repo's
  `clients/calsend.py` (standard library only; set `CALSEND_PY` to use another),
  configured in `~/.config/calsend.conf` (see the Calendar repo's `docs/CLIENTS.md`).
  Copy it again when the Calendar repo's version changes.

## Build

```sh
backend/build.sh
```

Makes `dist/calview` (about 11 MB), with Python, `icalendar` and
`recurring-ical-events` inside, so nothing is installed system-wide. The build uses a
venv in `backend/` (`.venv`, `build/`, `dist/`, all git-ignored); it needs Python 3
with `venv` and internet access for the pinned packages. Rebuild after changing
`calview.py`. A start takes about 0.4 s (the single file unpacks itself each time).

## Settings

`~/.config/calview.conf` (`chmod 600`):

```sh
CALDAV_URL=https://cal.<domain>
CALDAV_USER=<you>
CALDAV_PASSWORD=<your password>
# CALDAV_OWNER=<CAL_USER>    # only when CALDAV_USER is another account, e.g. agenda
```

The read-only `agenda` account is enough to view (set `CALDAV_OWNER` then); adding
events needs your own account. The view talks to Radicale (`cal.<domain>`) directly,
because the agenda web view sits behind Pangolin's browser login.

Check it from a terminal:

```sh
backend/dist/calview --start 2026-11-01 --days 7
backend/dist/calview add --calendar Personal --title Dentist --start 2026-11-03T14:00 --end 2026-11-03T14:45
```

The view runs `calendar/backend/dist/calview` in the Quickshell config. Elsewhere, set
`CALVIEW` in Quickshell's environment to its path. `CALVIEW` may also point at
`calview.py` itself, if `icalendar` and `recurring-ical-events` are installed for
`python3`.

## Setup

Done in these dotfiles already; for reference:

1. `shell.qml`: `import "calendar"`, and inside `ShellRoot`: `CalSend {}` and `CalView {}`.
2. Hyprland binds (`hypr/modules/bindings.lua`):
   ```lua
   bind(mainMod .. " + C",         hl.dsp.global("quickshell:calview"))    -- calendar view
   bind(mainMod .. " + SHIFT + C", hl.dsp.global("quickshell:calendar"))   -- send bar
   ```
3. Layer rules (`hypr/modules/rules.lua`), for the blur and fade like the launcher:
   ```lua
   hl.layer_rule({ name = "blur-qs-calendar", match = { namespace = "^qs-calendar$" },
                   blur = true, ignore_alpha = 0, animation = "fade" })
   hl.layer_rule({ name = "blur-qs-calview", match = { namespace = "^qs-calview$" },
                   blur = true, ignore_alpha = 0, animation = "fade" })
   ```

Scripts: `qs ipc call calendar toggle`, `qs ipc call calview toggle`.

## Calendar view

| Key | |
|-----|---|
| ← → ↑ ↓ | previous/next day, week |
| PgUp / PgDn | previous/next month |
| T | today |
| N or + | new event (opens the day pane) |
| Space | show/hide the day pane |
| Esc or Q | close (in the form, Esc goes back to the agenda) |

The day pane is hidden when the view opens; showing it widens the window rather
than squeezing the month, which keeps the screen's aspect ratio. Click a day to show
it in the agenda. Event bars and blocks are neutral with the
calendar's colour on the left edge; all-day events are chips under the date (and rows
above the hour grid); `?` marks events added from text that are not re-checked yet.
The view reloads every 5 minutes while open.

The new-event form has three kinds: **Event** (date, start, end), **All day** (first
and last day) and **Deadline** (date and time, no length). Times are local; events are
stored in UTC.

Recurring events are expanded in `calview.py`, not by Radicale: Radicale's CalDAV
`<expand>` (3.8.3) gets daylight saving time, `EXDATE` and moved instances wrong.
