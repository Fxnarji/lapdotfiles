pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Calendar events for the calendar view, read from Radicale by
// calview from calendar/backend (settings in ~/.config/calview.conf).
//
// Events (see calview.py): { uid, title, start, end, allDay, location,
// description, calendar, color, uncertain, free }. `start`/`end` are ISO
// strings: "2026-11-02" for all-day events (end exclusive), otherwise local
// times with offset. A timed event with no length is a deadline.
Singleton {
    id: root

    // The calview binary from calendar/backend/build.sh; CALVIEW can point
    // elsewhere, also at calview.py itself.
    readonly property string calview: Quickshell.env("CALVIEW") || Quickshell.shellDir + "/calendar/backend/dist/calview"

    // ---- view state --------------------------------------------------------

    property bool open: false
    property date month: firstOfMonth(new Date())   // the month shown
    property date selected: today()                  // the day in the agenda

    function toggle() { open = !open; }
    onOpenChanged: if (open) { goToday(); refresh(); }

    function today() { const d = new Date(); return new Date(d.getFullYear(), d.getMonth(), d.getDate()); }
    function firstOfMonth(d) { return new Date(d.getFullYear(), d.getMonth(), 1); }
    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }
    function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n); }

    function showMonth(d) {
        const m = firstOfMonth(d);
        if (+m === +month && events.length > 0) return;
        month = m;
        refresh();
    }
    function shiftMonth(n) { showMonth(new Date(month.getFullYear(), month.getMonth() + n, 1)); }
    function goToday() { selected = today(); showMonth(selected); }
    function select(day) {
        selected = day;
        if (day.getMonth() !== month.getMonth() || day.getFullYear() !== month.getFullYear()) showMonth(day);
    }

    // The grid: Monday on or before the 1st, as many weeks as the month needs.
    readonly property date gridStart: addDays(month, -((month.getDay() + 6) % 7))
    readonly property int weeks: {
        const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
        return Math.ceil(((month.getDay() + 6) % 7 + days) / 7);
    }

    // ---- data --------------------------------------------------------------

    property var events: []
    property var calendars: []        // [{ name, color }]
    property string error: ""         // last failure; old events are kept meanwhile
    readonly property bool loading: listProc.running
    property date updated

    function isoDate(d) {
        const pad = n => String(n).padStart(2, "0");
        return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    }
    function isDeadline(e) { return !e.allDay && e.start === e.end; }

    // One day's events, split for drawing:
    //   allDay:    all-day events touching the day
    //   timed:     events with a length, with from/to in minutes since the
    //              day's midnight (clipped to the day) and col/cols, the
    //              column within a group of overlapping events
    //   deadlines: events with no length, with `at` in minutes
    function day(d) {
        const key = isoDate(d);
        const dayStart = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        const dayEnd = addDays(dayStart, 1);
        const minutes = t => (t - dayStart) / 60000;
        const result = { allDay: [], timed: [], deadlines: [] };
        for (const e of events) {
            if (e.allDay) {
                if (e.start <= key && key < e.end) result.allDay.push(e);
                continue;
            }
            const s = new Date(e.start), t = new Date(e.end);
            if (s.getTime() === t.getTime()) {
                if (s >= dayStart && s < dayEnd) result.deadlines.push({ event: e, at: minutes(s) });
            } else if (s < dayEnd && t > dayStart) {
                result.timed.push({ event: e, from: Math.max(0, minutes(s)), to: Math.min(1440, minutes(t)), col: 0, cols: 1 });
            }
        }
        layOut(result.timed);
        return result;
    }

    // Side by side within each group of overlapping events.
    function layOut(items) {
        items.sort((a, b) => a.from - b.from || b.to - a.to);
        let group = [], ends = [], groupEnd = -1;
        const close = () => { for (const it of group) it.cols = ends.length; };
        for (const it of items) {
            if (it.from >= groupEnd) { close(); group = []; ends = []; }
            let col = ends.findIndex(end => end <= it.from);
            if (col < 0) { col = ends.length; ends.push(0); }
            ends[col] = it.to;
            it.col = col;
            group.push(it);
            groupEnd = Math.max(groupEnd, it.to);
        }
        close();
    }

    function colorOf(e) { return e.color || Qt.rgba(0.937, 0.937, 0.937, 0.35); }

    // ---- loading -----------------------------------------------------------

    function refresh() {
        if (listProc.running) { pending = true; return; }
        // 6 weeks from the grid start covers any month. Through env, so a
        // missing interpreter is exit code 127 instead of silence.
        listProc.command = ["env", calview, "--start", isoDate(gridStart), "--days", "42"];
        listProc.running = true;
    }
    property bool pending: false

    Process {
        id: listProc
        property var result: null
        stdout: StdioCollector {
            onStreamFinished: {
                try { listProc.result = JSON.parse(text); } catch (e) { listProc.result = null; }
            }
        }
        onExited: (code, status) => {
            const result = listProc.result;
            listProc.result = null;
            if (code === 127 && !result) root.error = `${root.calview} not found (run build.sh)`;
            else if (!result) root.error = "calview gave no answer";
            else if (!result.ok) root.error = result.error;
            else {
                root.events = result.events;
                root.calendars = result.calendars;
                root.error = "";
                root.updated = new Date();
            }
            if (root.pending) { root.pending = false; root.refresh(); }
        }
    }

    // Reload while the view is open.
    Timer {
        interval: 5 * 60 * 1000
        running: root.open
        repeat: true
        onTriggered: root.refresh()
    }

    // ---- adding ------------------------------------------------------------

    // fields: { calendar, title, start, end, allDay, location }; start/end
    // as calview add takes them. Answers with added(ok, message).
    signal added(bool ok, string message)
    readonly property bool adding: addProc.running

    function add(fields) {
        if (addProc.running) return;
        const cmd = ["env", calview, "add", "--calendar", fields.calendar, "--title", fields.title,
                     "--start", fields.start];
        if (fields.end) cmd.push("--end", fields.end);
        if (fields.allDay) cmd.push("--all-day");
        if (fields.location) cmd.push("--location", fields.location);
        addProc.command = cmd;
        addProc.running = true;
    }

    Process {
        id: addProc
        property var result: null
        stdout: StdioCollector {
            onStreamFinished: {
                try { addProc.result = JSON.parse(text); } catch (e) { addProc.result = null; }
            }
        }
        onExited: (code, status) => {
            const result = addProc.result;
            addProc.result = null;
            if (result?.ok) { root.added(true, ""); root.refresh(); }
            else root.added(false, result?.error ?? (code === 127 ? `${root.calview} not found (run build.sh)` : "calview gave no answer"));
        }
    }
}
