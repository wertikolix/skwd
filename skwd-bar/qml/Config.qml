pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: config

    function _resolve(path) { return path ? path.replace("~", homeDir) : "" }

    
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string configDir: Quickshell.env("SKWD_CONFIG")
        || (Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")) + "/skwd"
    readonly property string installDir: Quickshell.env("SKWD_BAR_INSTALL") || Quickshell.env("SKWD_INSTALL") || configDir
    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/skwd"
    readonly property string scriptsDir: _resolve(_data.paths?.scripts) || (installDir + "/scripts")
    readonly property string cacheDir: _resolve(_data.paths?.cache)
        || Quickshell.env("SKWD_CACHE")
        || (Quickshell.env("XDG_CACHE_HOME") || (homeDir + "/.cache")) + "/skwd"

    property var _data: ({})

    property var _configFile: FileView {
        path: configDir + "/data/config.json"
        preload: true
        watchChanges: true
        onLoaded: config._reparse()
        onFileChanged: { reload(); config._reparse() }
    }

    function _reparse() {
        var raw = _configFile.text() || ""
        if (!raw) return
        try { config._data = JSON.parse(raw) } catch (e) {}
    }

    
    readonly property string compositor: _data.compositor ?? "niri"

    
    readonly property string mainMonitor: _data.monitor ?? ""
    readonly property int weatherPollMs: _data.intervals?.weatherPollMs ?? 0
    readonly property int wifiPollMs: _data.intervals?.wifiPollMs ?? 0
    readonly property bool devMode: _data.dev === true


    property var _bar: _data.components?.bar ?? {}
    readonly property bool barEnabled: _bar.enabled !== false
    readonly property bool mouseoverEnabled: _bar.mouseoverEnabled !== false

    readonly property string barStyle: _bar.style ?? "classic"
    readonly property int    barPillSideMargin: _bar.pillSideMargin ?? 12
    readonly property int    barPillTopMargin:  _bar.pillTopMargin  ?? 8

    readonly property bool brightnessEnabled: _bar.brightness !== undefined && _bar.brightness !== false && _bar.brightness?.enabled !== false
    readonly property bool batteryEnabled:    _bar.battery !== false && _bar.battery?.enabled !== false
    readonly property bool notificationsEnabled: _bar.notifications?.enabled === true
    readonly property bool notificationsHideWhenEmpty: _bar.notifications?.hideWhenEmpty === true
    readonly property bool notificationsAlwaysShowIfPresent: _bar.notifications?.alwaysShowIfPresent === true
    readonly property int  notificationsHistoryMax: _bar.notifications?.historyMax ?? 50
    property var _battery: _bar.battery ?? ({})
    readonly property var batteryNotifyRules: Array.isArray(_battery.notify) ? _battery.notify : []

    readonly property var _defaultBarLeftLayout:  ["workspaces", "window", "cpu", "gpu", "memory"]
    readonly property var _defaultBarRightLayout: ["netspeed", "tray", "weather", "bluetooth", "wifi", "brightness", "battery", "volume", "notifications", "kblayout", "clock"]
    readonly property var _allBarWidgets: ["workspaces", "window", "cpu", "gpu", "memory", "qsmem", "disk", "netspeed", "tray", "kblayout", "weather", "bluetooth", "wifi", "volume", "clock", "brightness", "battery", "notifications"]
    readonly property var barLeftLayout:  Array.isArray(_bar.leftLayout)  ? _bar.leftLayout.filter(s => _allBarWidgets.indexOf(s) !== -1)  : _defaultBarLeftLayout
    readonly property var barRightLayout: Array.isArray(_bar.rightLayout) ? _bar.rightLayout.filter(s => _allBarWidgets.indexOf(s) !== -1) : _defaultBarRightLayout
    readonly property var barWidgetOverrides: (typeof _bar.widgets === "object" && _bar.widgets !== null) ? _bar.widgets : ({})
    function barWidgetIcon(id, fallback)  { var o = barWidgetOverrides[id]; return (o && o.icon)  ? o.icon  : fallback }
    function barWidgetLabel(id, fallback) { var o = barWidgetOverrides[id]; return (o && o.label) ? o.label : fallback }
    function barWidgetMouseover(id)       { var o = barWidgetOverrides[id]; return !!(o && o.mouseover) }
    function barWidgetDisabled(id)        { var o = barWidgetOverrides[id]; return !!(o && o.disabled) }
    readonly property var weatherCities: {
        let arr = _bar.weather?.cities
        if (Array.isArray(arr) && arr.length > 0) return arr.filter(s => typeof s === "string" && s.length > 0)
        let single = Quickshell.env("SKWD_WEATHER_CITY") || _bar.weather?.city
        return single ? [single] : []
    }
    readonly property string weatherDefaultCity: {
        let env = Quickshell.env("SKWD_WEATHER_CITY")
        if (env) return env
        let def = _bar.weather?.defaultCity
        if (def) return def
        let single = _bar.weather?.city
        if (single) return single
        return weatherCities.length > 0 ? weatherCities[0] : ""
    }
    readonly property string weatherCity: weatherDefaultCity
    readonly property bool weatherEnabled: _bar.weather !== undefined && _bar.weather !== false && _bar.weather?.enabled !== false
    readonly property string wifiInterface: _bar.wifi?.interface ?? ""
    readonly property bool wifiEnabled: _bar.wifi !== undefined && _bar.wifi !== false && _bar.wifi?.enabled !== false
    readonly property bool bluetoothEnabled: _bar.bluetooth !== false
    readonly property bool volumeEnabled: _bar.volume !== false
    readonly property int  volumeScrollStep: _bar.volumeScrollStep ?? 5
    readonly property bool calendarEnabled: _bar.calendar !== false

    property var _clock: (typeof _bar.clock === "object" && _bar.clock !== null) ? _bar.clock : ({})
    readonly property bool   clockShowDate:    _clock.showDate === true
    readonly property bool   clockShowSeconds: _clock.showSeconds === true
    readonly property string clockDateFormat:  _clock.dateFormat ?? "ddd d MMM"

    property var _workspaces: (typeof _bar.workspaces === "object" && _bar.workspaces !== null) ? _bar.workspaces : ({})
    readonly property bool workspacesEnabled:        _bar.workspaces !== false && _workspaces.enabled !== false
    readonly property bool workspacesHideWhenSingle: _workspaces.hideWhenSingle === true
    readonly property bool workspacesHideEmpty:      _workspaces.hideEmpty === true
    readonly property bool workspacesAllOutputs:     _workspaces.allOutputs === true
    readonly property int  workspacesMaxShown:       _workspaces.maxShown ?? 10

    readonly property bool trayEnabled: _bar.tray !== false && _bar.tray?.enabled !== false

    property var _netspeed: (typeof _bar.netspeed === "object" && _bar.netspeed !== null) ? _bar.netspeed : ({})
    readonly property bool   netspeedEnabled:    _bar.netspeed !== false && _netspeed.enabled !== false
    readonly property int    netspeedRefreshSec: _netspeed.refreshSec ?? 2
    readonly property string netspeedInterface:  _netspeed.interface ?? ""

    readonly property bool kblayoutEnabled: _bar.kblayout !== false && _bar.kblayout?.enabled !== false

    property var _windowTitle: (typeof _bar.windowTitle === "object" && _bar.windowTitle !== null) ? _bar.windowTitle : ({})
    readonly property bool windowTitleEnabled:  _bar.windowTitle !== false && _windowTitle.enabled !== false
    readonly property int  windowTitleMaxWidth: _windowTitle.maxWidth ?? 260

    readonly property bool diskEnabled: _bar.disk !== false && _bar.disk?.enabled !== false
    readonly property bool qsmemEnabled: _bar.qsmem?.enabled !== false
    readonly property int  qsmemRefreshSec: _bar.qsmem?.refreshSec ?? 5
    readonly property bool musicEnabled: _bar.music !== undefined && _bar.music !== false && _bar.music?.enabled !== false
    readonly property string preferredPlayer: _bar.music?.preferredPlayer ?? "spotify"
    readonly property string visualizerTheme: _bar.music?.visualizer ?? "wave"
    readonly property bool visualizerTop: (_bar.music?.visualizerTop !== false)
    readonly property bool visualizerBottom: (_bar.music?.visualizerBottom !== false)
    readonly property bool musicAutohide: (_bar.music?.autohide !== false)
    readonly property bool musicShowMeta: (_bar.music?.showMeta !== false)
    readonly property bool musicShowLyrics: (_bar.music?.showLyrics !== false)
    readonly property bool musicAlwaysHoverable: (_bar.music?.alwaysHoverable === true)
    readonly property bool musicCleanVisualizer: (_bar.music?.cleanVisualizer === true)
    readonly property bool musicShowLyricsStatus: (_bar.music?.showLyricsStatus !== false)

    property var _viz: _bar.music?.viz ?? ({})
    readonly property real vizAuroraMinAmp:        _viz.aurora?.minAmp        ?? 0.22
    readonly property int  vizAuroraLayerCount:    _viz.aurora?.layerCount    ?? 4
    readonly property real vizAuroraRespPumpExp:   _viz.auroraResponsive?.pumpExp   ?? 0.45
    readonly property real vizAuroraRespPumpScale: _viz.auroraResponsive?.pumpScale ?? 1.4
    readonly property real vizAuroraRespAttack:    _viz.auroraResponsive?.attack    ?? 0.45
    readonly property real vizAuroraRespDecay:     _viz.auroraResponsive?.decay     ?? 0.10
    readonly property int  vizPulsePillWidth:      _viz.pulse?.pillWidth      ?? 3
    readonly property real vizVuPeakDecay:         _viz.vu?.peakDecay         ?? 1.6
    readonly property int  vizSpectrogramCols:     _viz.spectrogram?.cols     ?? 80
    readonly property int  vizStardustCount:       _viz.stardust?.count       ?? 60
    readonly property int  vizCometTrailLen:       _viz.comet?.trailLen       ?? 24
    readonly property real vizRippleThreshold:     _viz.ripple?.threshold     ?? 1.5
    readonly property int  vizRippleMaxAge:        _viz.ripple?.maxAge        ?? 36
}
