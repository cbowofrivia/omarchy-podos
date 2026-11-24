import QtQuick
import Quickshell
import Quickshell.Io

// Schedules the omarchy-podos-fetch helper and exposes its result to the panel.
// The helper owns auth, the API calls, grouping and desktop pop-ups.
Item {
  id: root

  property var settings: ({})
  property string state: "loading"
  property string message: ""
  property int unread: 0
  property bool more: false
  property var groups: []
  property var tasks: []
  // { username, firstName } from the tasks project, or null.
  property var user: null
  property string fetchedAt: ""
  property string actionStatus: ""
  // Read state flipped optimistically after a click ("read" or "unread"
  // by thread key), until the next refresh confirms it.
  property var overrides: ({})
  property bool refreshQueued: false

  readonly property bool loading: fetchProcess.running
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 60, 30, 3600)
  readonly property bool desktopNotifications: boolSetting("desktopNotifications", true)
  readonly property string tasksProject: {
    var code = String(setting("tasksProject", "")).trim()
    return /^[a-z0-9-]{1,80}$/.test(code) ? code : ""
  }
  readonly property string apiUrl: baseUrlSetting("apiUrl", "https://api.podos.io")
  readonly property string dashboardUrl: baseUrlSetting("dashboardUrl", "https://podos.io")
  readonly property string inboxUrl: dashboardUrl + "/inbox?search-notification=group%3Auser"
  readonly property string boardUrl: dashboardUrl + "/workflow" + (tasksProject ? "?project=" + tasksProject : "")
  // Unread and read threads in one list, newest first, with overrides applied.
  readonly property var visibleGroups: groups.map(function(g) {
    var state = root.overrides[g.key]
    if (state === "read") return Object.assign({}, g, { unread: 0, unreadIds: [] })
    if (state === "unread" && g.unread === 0) return Object.assign({}, g, { unread: 1, unreadIds: [g.headId] })
    return g
  })
  readonly property int visibleUnread: {
    var total = 0
    for (var i = 0; i < visibleGroups.length; i++) total += visibleGroups[i].unread
    return total
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    return Math.max(min, Math.min(max, n))
  }

  function boolSetting(name, fallback) {
    var value = setting(name, fallback)
    if (value === true || value === false) return value
    var text = String(value).toLowerCase()
    return text === "true" || text === "yes" || text === "on" || text === "1"
  }

  // An https:// base URL without a trailing slash, else the default.
  function baseUrlSetting(name, fallback) {
    var value = String(setting(name, fallback)).trim().replace(/\/+$/, "")
    return /^https:\/\/[A-Za-z0-9.-]+(:\d{1,5})?(\/[A-Za-z0-9._~\/-]*)?$/.test(value) ? value : fallback
  }

  // The helper plus the configured PodOS addresses, for every call.
  function helper() {
    return [helperPath(), "--api", apiUrl, "--dashboard", dashboardUrl]
  }

  function helperPath() {
    return decodeURIComponent(Qt.resolvedUrl("omarchy-podos-fetch").toString().replace(/^file:\/\//, ""))
  }

  function refresh() {
    if (fetchProcess.running || actionProcess.running) { refreshQueued = true; return }
    refreshQueued = false
    var argv = helper().concat(["list", "--limit", "100", "--read-groups", "20"])
    if (desktopNotifications) argv.push("--notify")
    if (tasksProject !== "") argv.push("--tasks-project", tasksProject)
    fetchProcess.command = argv
    fetchProcess.running = true
  }

  function apply(raw) {
    var data
    try { data = JSON.parse(String(raw || "")) } catch (e) {
      state = "error"; message = "PodOS returned an unreadable response."; return
    }
    state = String(data.state || "error")
    message = String(data.message || "")
    if (state !== "ready") return
    unread = Number(data.unread) || 0
    more = data.more === true
    groups = Array.isArray(data.groups) ? data.groups : []
    tasks = Array.isArray(data.tasks) ? data.tasks : []
    user = data.user && typeof data.user === "object" ? data.user : null
    fetchedAt = String(data.fetchedAt || "")
    overrides = ({})
  }

  function runAction(argv, status) {
    if (actionProcess.running) return
    actionStatus = status
    actionProcess.command = helper().concat(argv)
    actionProcess.running = true
  }

  function override(keys, state) {
    var next = {}
    for (var k in overrides) next[k] = overrides[k]
    for (var i = 0; i < keys.length; i++) next[keys[i]] = state
    overrides = next
  }

  // Opening a thread marks its unread notifications read.
  function openGroup(group) {
    if (!group) return
    if (group.unread > 0) override([group.key], "read")
    runAction(["open", String(group.url)].concat(group.unreadIds), "Opening in PodOS…")
  }

  // Unread threads become read; read threads get their newest
  // notification back as unread.
  function toggleRead(group) {
    if (!group) return
    if (group.unread > 0) {
      override([group.key], "read")
      runAction(["read"].concat(group.unreadIds), "Marking read…")
    } else {
      override([group.key], "unread")
      runAction(["unread", String(group.headId)], "Marking unread…")
    }
  }

  function markAllRead() {
    var keys = visibleGroups.filter(function(g) { return g.unread > 0 }).map(function(g) { return g.key })
    if (keys.length === 0) return
    override(keys, "read")
    runAction(["read-all"], "Marking all read…")
  }

  function openTask(task) {
    if (!task) return
    runAction(["open", String(task.url)], "Opening task…")
  }

  function openBoard() {
    runAction(["open", boardUrl], "Opening PodOS…")
  }

  function openInbox() {
    runAction(["open", inboxUrl], "Opening PodOS inbox…")
  }

  visible: false

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: statusTimer
    interval: 2500
    onTriggered: root.actionStatus = ""
  }

  Process {
    id: fetchProcess
    running: false
    stdout: StdioCollector { id: fetchOut; waitForEnd: true }
    stderr: StdioCollector { id: fetchErr; waitForEnd: true }
    onExited: function(exitCode) {
      var out = String(fetchOut.text || "")
      if (out.trim() !== "") root.apply(out)
      else { root.state = "error"; root.message = String(fetchErr.text || "PodOS refresh failed.").trim() }
      if (root.refreshQueued) Qt.callLater(root.refresh)
    }
  }

  Process {
    id: actionProcess
    running: false
    stdout: StdioCollector { id: actionOut; waitForEnd: true }
    onExited: function(exitCode) {
      var response = null
      try { response = JSON.parse(String(actionOut.text || "")) } catch (e) {}
      if (exitCode === 0) root.actionStatus = ""
      else {
        root.actionStatus = response && response.message ? String(response.message) : "PodOS action failed."
        root.overrides = ({})
        statusTimer.restart()
      }
      Qt.callLater(root.refresh)
    }
  }
}
