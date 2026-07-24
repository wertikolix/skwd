pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."


QtObject {
    id: service

    property bool started: false

    // Normalized workspaces: [{ key, focusArg, label, output, active, urgent, populated }]
    property var workspaces: []
    property string focusedTitle: ""
    property string focusedAppId: ""

    // Keyboard layouts
    property var kbLayouts: []
    property int kbLayoutIndex: -1
    property string kbEventName: ""   // hyprland: only current name comes via events
    readonly property string kbLayoutName: (kbLayoutIndex >= 0 && kbLayoutIndex < kbLayouts.length)
        ? kbLayouts[kbLayoutIndex]
        : kbEventName
    readonly property string kbLayoutShort: _shortLayout(kbLayoutName)
    readonly property bool kbAvailable: kbLayouts.length > 1 || (kbLayouts.length === 0 && kbEventName !== "")

    // niri internal state
    property var _niriWorkspaces: []
    property var _niriWindows: ({})
    property var _focusedWindowId: null

    function _shortLayout(name) {
        if (!name) return ""
        var map = {
            "english": "EN", "russian": "RU", "ukrainian": "UA", "german": "DE",
            "french": "FR", "spanish": "ES", "italian": "IT", "portuguese": "PT",
            "polish": "PL", "swedish": "SE", "norwegian": "NO", "danish": "DK",
            "finnish": "FI", "dutch": "NL", "czech": "CZ", "turkish": "TR",
            "greek": "GR", "hebrew": "HE", "arabic": "AR", "japanese": "JP",
            "korean": "KR", "chinese": "ZH", "belarusian": "BY", "kazakh": "KZ",
            "serbian": "RS", "hungarian": "HU", "romanian": "RO", "bulgarian": "BG",
            "estonian": "EE", "latvian": "LV", "lithuanian": "LT", "georgian": "GE",
            "armenian": "AM", "thai": "TH", "vietnamese": "VN"
        }
        var first = name.split(/[\s(,]/)[0].toLowerCase()
        if (map[first]) return map[first]
        return name.substring(0, 2).toUpperCase()
    }

    function start() {
        if (started) return
        started = true
        WmService.wmEvent.connect(_onWmEvent)
        WmService.workspacesReady.connect(_onWorkspacesList)
        WmService.windowsReady.connect(_onWindowsList)
        WmService.startEventStream()
        _refresh()
        if (WmService.compositor === "kwin") _kwinPollTimer.running = true
    }

    function focusWorkspace(arg) { WmService.focusWorkspace(arg) }

    function cycleWorkspace(dir) {
        var list = workspaces
        if (list.length === 0) return
        var cur = 0
        for (var i = 0; i < list.length; i++) if (list[i].active) { cur = i; break }
        var next = Math.max(0, Math.min(list.length - 1, cur + dir))
        if (next === cur) return
        focusWorkspace(list[next].focusArg)
    }

    function switchKbLayout() {
        switch (WmService.compositor) {
        case "niri":
            _run(["niri", "msg", "action", "switch-layout", "next"]);
            break
        case "hyprland":
            _run(["sh", "-c",
                "dev=$(hyprctl devices -j | sed -n 's/.*\"identifier\": \"\\([^\"]*keyboard[^\"]*\\)\".*/\\1/p' | head -1); " +
                "hyprctl switchxkblayout \"${dev:-all}\" next"]);
            break
        case "sway":
            _run(["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"]);
            break
        }
    }

    function _refresh() {
        WmService.listWorkspaces()
        WmService.listWindows()
    }

    // ---- event handling ----

    function _onWmEvent(line) {
        var trimmed = (line || "").trim()
        if (trimmed === "") return

        if (WmService.compositor === "niri") {
            var ev
            try { ev = JSON.parse(trimmed) } catch (e) { return }
            _handleNiriEvent(ev)
            return
        }

        if (WmService.compositor === "hyprland") {
            var sep = trimmed.indexOf(">>")
            var name = sep >= 0 ? trimmed.substring(0, sep) : trimmed
            var data = sep >= 0 ? trimmed.substring(sep + 2) : ""
            if (name === "activelayout") {
                var parts = data.split(",")
                service.kbEventName = parts.length > 1 ? parts[parts.length - 1] : data
                return
            }
            if (name === "activewindow") {
                var idx = data.indexOf(",")
                service.focusedAppId = idx >= 0 ? data.substring(0, idx) : ""
                service.focusedTitle = idx >= 0 ? data.substring(idx + 1) : data
            }
            _debounceRefresh.restart()
            return
        }

        // sway subscribe stream: any event -> refresh
        _debounceRefresh.restart()
    }

    function _handleNiriEvent(ev) {
        if (ev.WorkspacesChanged) {
            _niriWorkspaces = ev.WorkspacesChanged.workspaces || []
            _rebuildNiri()
        } else if (ev.WorkspaceActivated) {
            var id = ev.WorkspaceActivated.id
            var out = ""
            for (var i = 0; i < _niriWorkspaces.length; i++)
                if (_niriWorkspaces[i].id === id) out = _niriWorkspaces[i].output
            for (var j = 0; j < _niriWorkspaces.length; j++) {
                var ws = _niriWorkspaces[j]
                if (ws.id === id) {
                    ws.is_active = true
                    if (ev.WorkspaceActivated.focused) ws.is_focused = true
                } else {
                    if (ws.output === out) ws.is_active = false
                    if (ev.WorkspaceActivated.focused) ws.is_focused = false
                }
            }
            _rebuildNiri()
        } else if (ev.WorkspaceUrgencyChanged) {
            for (var k = 0; k < _niriWorkspaces.length; k++)
                if (_niriWorkspaces[k].id === ev.WorkspaceUrgencyChanged.id)
                    _niriWorkspaces[k].is_urgent = ev.WorkspaceUrgencyChanged.urgent
            _rebuildNiri()
        } else if (ev.WorkspaceActiveWindowChanged) {
            for (var m = 0; m < _niriWorkspaces.length; m++)
                if (_niriWorkspaces[m].id === ev.WorkspaceActiveWindowChanged.workspace_id)
                    _niriWorkspaces[m].active_window_id = ev.WorkspaceActiveWindowChanged.active_window_id
            _rebuildNiri()
        } else if (ev.WindowsChanged) {
            var wins = ev.WindowsChanged.windows || []
            var mapw = {}
            _focusedWindowId = null
            for (var w = 0; w < wins.length; w++) {
                mapw[wins[w].id] = wins[w]
                if (wins[w].is_focused) _focusedWindowId = wins[w].id
            }
            _niriWindows = mapw
            _updateNiriFocusedTitle()
            _rebuildNiri()
        } else if (ev.WindowOpenedOrChanged) {
            var win = ev.WindowOpenedOrChanged.window
            if (win) {
                var mw = _niriWindows
                mw[win.id] = win
                _niriWindows = mw
                if (win.is_focused) _focusedWindowId = win.id
                _updateNiriFocusedTitle()
                _rebuildNiri()
            }
        } else if (ev.WindowClosed) {
            var mc = _niriWindows
            delete mc[ev.WindowClosed.id]
            _niriWindows = mc
            if (_focusedWindowId === ev.WindowClosed.id) _focusedWindowId = null
            _updateNiriFocusedTitle()
            _rebuildNiri()
        } else if (ev.WindowFocusChanged) {
            _focusedWindowId = ev.WindowFocusChanged.id
            _updateNiriFocusedTitle()
        } else if (ev.KeyboardLayoutsChanged) {
            var kl = ev.KeyboardLayoutsChanged.keyboard_layouts
            if (kl) {
                service.kbLayouts = kl.names || []
                service.kbLayoutIndex = kl.current_idx ?? -1
            }
        } else if (ev.KeyboardLayoutSwitched) {
            service.kbLayoutIndex = ev.KeyboardLayoutSwitched.idx ?? -1
        }
    }

    function _updateNiriFocusedTitle() {
        var win = _focusedWindowId !== null ? _niriWindows[_focusedWindowId] : null
        service.focusedTitle = win ? (win.title || "") : ""
        service.focusedAppId = win ? (win.app_id || "") : ""
    }

    function _rebuildNiri() {
        var out = []
        var wsList = _niriWorkspaces.slice()
        wsList.sort(function(a, b) {
            if ((a.output || "") !== (b.output || "")) return (a.output || "") < (b.output || "") ? -1 : 1
            return (a.idx || 0) - (b.idx || 0)
        })
        for (var i = 0; i < wsList.length; i++) {
            var ws = wsList[i]
            out.push({
                key: String(ws.id),
                focusArg: ws.name && ws.name !== "" ? ws.name : String(ws.idx),
                label: ws.name && ws.name !== "" ? ws.name : String(ws.idx),
                output: ws.output || "",
                active: ws.is_active === true,
                urgent: ws.is_urgent === true,
                populated: ws.active_window_id !== null && ws.active_window_id !== undefined
            })
        }
        service.workspaces = out
    }

    // ---- list results (non-niri compositors, and initial refresh) ----

    function _onWorkspacesList(data) {
        if (WmService.compositor === "niri") {
            _niriWorkspaces = Array.isArray(data) ? data : []
            _rebuildNiri()
            return
        }
        var out = []
        var arr = Array.isArray(data) ? data : []
        if (WmService.compositor === "hyprland") {
            arr.sort(function(a, b) { return (a.id || 0) - (b.id || 0) })
            for (var i = 0; i < arr.length; i++) {
                var ws = arr[i]
                if ((ws.id || 0) < 0) continue // special workspaces
                out.push({
                    key: String(ws.id),
                    focusArg: String(ws.id),
                    label: ws.name && ws.name !== "" ? ws.name : String(ws.id),
                    output: ws.monitor || "",
                    active: false, // patched below via activeworkspace
                    urgent: false,
                    populated: (ws.windows || 0) > 0
                })
            }
            service.workspaces = out
            _hyprActiveProcessOut = []
            _hyprActiveProcess.running = true
        } else if (WmService.compositor === "sway") {
            for (var j = 0; j < arr.length; j++) {
                var sws = arr[j]
                out.push({
                    key: String(sws.num !== undefined ? sws.num : sws.name),
                    focusArg: sws.name,
                    label: sws.name,
                    output: sws.output || "",
                    active: sws.focused === true,
                    urgent: sws.urgent === true,
                    populated: true
                })
            }
            service.workspaces = out
        } else {
            // kwin and others: [{id, name, is_active}]
            for (var k = 0; k < arr.length; k++) {
                var kws = arr[k]
                out.push({
                    key: String(kws.id),
                    focusArg: String(kws.id),
                    label: kws.name || String(kws.id),
                    output: "",
                    active: kws.is_active === true,
                    urgent: false,
                    populated: true
                })
            }
            service.workspaces = out
        }
    }

    function _onWindowsList(data) {
        if (WmService.compositor === "niri") {
            var wins = Array.isArray(data) ? data : []
            var mapw = {}
            _focusedWindowId = null
            for (var w = 0; w < wins.length; w++) {
                mapw[wins[w].id] = wins[w]
                if (wins[w].is_focused) _focusedWindowId = wins[w].id
            }
            _niriWindows = mapw
            _updateNiriFocusedTitle()
            _rebuildNiri()
            return
        }
        var arr = Array.isArray(data) ? data : []
        for (var i = 0; i < arr.length; i++) {
            var win = arr[i]
            var focused = win.is_focused === true || win.focused === true
                || (win.focusHistoryID !== undefined && win.focusHistoryID === 0)
            if (focused) {
                service.focusedTitle = win.title || win.name || ""
                service.focusedAppId = win.app_id || win["class"] || ""
                return
            }
        }
    }

    property var _hyprActiveProcessOut: []
    property var _hyprActiveProcess: Process {
        command: ["hyprctl", "-j", "activeworkspace"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => service._hyprActiveProcessOut.push(data)
        }
        onExited: {
            try {
                var obj = JSON.parse(service._hyprActiveProcessOut.join(""))
                var id = String(obj.id)
                var list = service.workspaces.slice()
                for (var i = 0; i < list.length; i++) list[i].active = (list[i].key === id)
                service.workspaces = list
            } catch (e) {}
        }
    }

    property var _debounceRefresh: Timer {
        interval: 150
        onTriggered: service._refresh()
    }

    property var _kwinPollTimer: Timer {
        interval: 3000
        repeat: true
        onTriggered: service._refresh()
    }

    property var _cmdProcess: Process { }
    function _run(cmd) {
        _cmdProcess.command = cmd
        _cmdProcess.running = true
    }
}
