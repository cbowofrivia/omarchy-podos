import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "cbowofrivia.podos"
  ipcTarget: "cbowofrivia.podos"
  manageIpc: false

  readonly property Item panelFlick: panel.loadedContent ? panel.loadedContent.panelFlick : null
  readonly property Item rowColumn: panel.loadedContent ? panel.loadedContent.rowColumn : null

  property int rowIndex: 0
  property string tab: "notifications"
  property bool cursorActive: false
  property real now: Date.now()

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var tabs: podos.tasksProject !== "" ? ["notifications", "tasks"] : ["notifications"]
  readonly property bool tasksTab: tab === "tasks"
  // Rows the cursor walks: notification groups, or tasks on the Tasks tab.
  readonly property var rows: tasksTab ? podos.tasks : podos.visibleGroups
  // Notification rows with a heading inserted wherever the day changes.
  readonly property var entries: {
    var out = []
    if (tasksTab) {
      // The helper sorts Doing before Need, so a heading goes in where the status changes.
      var status = ""
      for (var t = 0; t < rows.length; t++) {
        if (rows[t].status !== status) {
          status = rows[t].status
          out.push({ kind: "day", label: strings.t("status." + status).arg(taskCount(status)) })
        }
        out.push({ kind: "task", item: rows[t], index: t })
      }
      return out
    }
    var last = ""
    for (var i = 0; i < rows.length; i++) {
      var label = dayLabel(rows[i].createdAt)
      if (label !== last) { out.push({ kind: "day", label: label }); last = label }
      out.push({ kind: "notification", item: rows[i], index: i })
    }
    return out
  }
  readonly property int count: podos.visibleUnread
  readonly property int doingCount: taskCount("doing")
  readonly property string countText: count > 99 || (podos.more && count >= 99) ? "99+" : String(count)

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function taskCount(status) {
    var n = 0
    for (var i = 0; i < podos.tasks.length; i++) if (podos.tasks[i].status === status) n++
    return n
  }

  function ago(iso) {
    var then = Date.parse(String(iso || ""))
    if (!isFinite(then)) return ""
    var s = Math.max(0, Math.round((now - then) / 1000))
    if (s < 60) return strings.t("time.now")
    if (s < 3600) return strings.t("time.minutes").arg(Math.floor(s / 60))
    if (s < 86400) return strings.t("time.hours").arg(Math.floor(s / 3600))
    return strings.t("time.days").arg(Math.floor(s / 86400))
  }

  function dayLabel(iso) {
    var then = new Date(Date.parse(String(iso || "")))
    if (!isFinite(then.getTime())) return ""
    var today = new Date(now)
    today.setHours(0, 0, 0, 0)
    var day = new Date(then.getTime())
    day.setHours(0, 0, 0, 0)
    var days = Math.round((today.getTime() - day.getTime()) / 86400000)
    var locale = Qt.locale(Commons.I18n.formatLocale)
    if (days <= 0) return strings.t("day.today")
    if (days === 1) return strings.t("day.yesterday")
    if (days < 7) return then.toLocaleDateString(locale, "dddd")
    return then.toLocaleDateString(locale, days < 300 ? "d MMMM" : "d MMMM yyyy")
  }

  function selected() {
    if (rows.length === 0) return null
    return rows[Math.max(0, Math.min(rowIndex, rows.length - 1))]
  }

  function setTab(value) {
    if (value === tab || tabs.indexOf(value) < 0) return
    tab = value
    rowIndex = 0
    if (panelFlick) panelFlick.contentY = 0
  }

  function stepTab(direction) {
    var i = tabs.indexOf(tab)
    setTab(tabs[(i + direction + tabs.length) % tabs.length])
  }

  function activate(item) {
    if (tasksTab) podos.openTask(item)
    else podos.openGroup(item)
  }

  function toggleRead(group) {
    if (!tasksTab) podos.toggleRead(group)
  }

  function openPodos() {
    if (tasksTab) podos.openBoard()
    else podos.openInbox()
  }

  function setRow(index) {
    cursorActive = true
    rowIndex = Math.max(0, Math.min(rows.length - 1, index))
    scrollIntoView()
  }

  function scrollIntoView() {
    if (!panelFlick || !rowColumn) return
    var target = null
    for (var i = 0; i < rowColumn.children.length; i++) {
      var child = rowColumn.children[i]
      if (child.entry && child.entry.kind !== "day" && child.entry.index === rowIndex) { target = child; break }
    }
    if (!target) return
    Qt.callLater(function() {
      if (!target || !panelFlick) return
      var margin = Style.space(6)
      var top = target.mapToItem(panelFlick.contentItem, 0, 0).y
      var bottom = top + target.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < panelFlick.contentY + margin) panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > panelFlick.contentY + panelFlick.height - margin)
        panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    rowIndex = 0
    tab = "notifications"
    now = Date.now()
    if (panelFlick) panelFlick.contentY = 0
    podos.refresh()
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  }
  onRowsChanged: if (rowIndex >= rows.length) rowIndex = Math.max(0, rows.length - 1)
  onTabsChanged: if (tabs.indexOf(tab) < 0) tab = "notifications"

  Service {
    id: podos
    settings: root.settings
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.opened
    onTriggered: root.now = Date.now()
  }

  ShellIpc {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    // e.g. `omarchy-shell cbowofrivia.podos showTab tasks`
    function showTab(name: string): void {
      if (!root.opened) root.open()
      Qt.callLater(function() { root.setTab(name) })
    }
    function refresh(): string { podos.refresh(); return "ok" }
    function status(): string { return podos.state + " " + podos.visibleUnread }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        PodosIcon {
          x: (parent.width - width) / 2
          y: (parent.height - height) / 2
          iconSize: button.iconSize
          // Lit in the theme's active bar colour, like the other widgets.
          color: root.count > 0 ? button.activeColor : root.barForeground
        }
      }
    }
    labelText: root.count > 0 ? root.countText : ""
    // Widen the slot to fit the count, as the battery widget does for its
    // percentage, so the number stays inside this widget's own space
    // instead of spilling toward the neighbour on its left.
    slotSize: labelText !== "" && !vertical
      ? Style.bar.iconSlot + countMetrics.advanceWidth + Style.space(4)
      : Style.bar.iconSlot

    TextMetrics {
      id: countMetrics
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      text: button.labelText
    }
    active: root.count > 0
    dimmed: podos.state !== "ready" && podos.state !== "loading"
    tooltipText: ""
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) podos.refresh()
      else if (buttonCode === Qt.MiddleButton) podos.openInbox()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(600))

    content: PanelKeyCatcher {
      id: keyCatcher
      property alias panelFlick: panelFlick
      property alias rowColumn: rowColumn
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) { root.stepTab(dx < 0 ? -1 : 1); return }
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.setRow(root.rowIndex + dy)
      }
      onActivateRequested: if (root.cursorActive) root.activate(root.selected())
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var k = String(t).toLowerCase()
        if (k === "r") podos.refresh()
        else if (k === "m" && root.cursorActive) root.toggleRead(root.selected())
        else if (k === "a" && !root.tasksTab) podos.markAllRead()
        else if (k === "i") root.openPodos()
        else if (k === "n") root.setTab("notifications")
        else if (k === "t") root.setTab("tasks")
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(10)

          // Header: the PodOS mark, the tabs, and the actions for this tab.
          RowLayout {
            width: parent.width
            spacing: Style.space(10)

            PodosIcon {
              iconSize: Style.font.heading
              color: root.foreground
              Layout.alignment: Qt.AlignVCenter
            }

            ButtonGroup {
              value: root.tab
              focusable: false
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              Layout.alignment: Qt.AlignVCenter
              options: {
                var out = [
                  { value: "notifications", label: root.count > 0 ? strings.t("tab.notificationsCount").arg(root.countText) : strings.t("tab.notifications") }
                ]
                if (podos.tasksProject !== "")
                  out.push({ value: "tasks", label: root.doingCount > 0 ? strings.t("tab.tasksCount").arg(root.doingCount) : strings.t("tab.tasks") })
                return out
              }
              onChanged: function(value) { root.setTab(value) }
            }

            Item { Layout.fillWidth: true; implicitHeight: 1 }

            PanelActionButton {
              iconText: "󰑐"
              tooltipText: strings.t("refresh")
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !podos.loading
              onClicked: podos.refresh()
            }
            PanelActionButton {
              visible: !root.tasksTab
              iconText: "󰸞"
              tooltipText: strings.t("markAllRead")
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: root.count > 0
              onClicked: podos.markAllRead()
            }
            PanelActionButton {
              iconText: "󰏌"
              tooltipText: root.tasksTab ? strings.t("openBoard") : strings.t("openInbox")
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.openPodos()
            }
          }

          PlainLabel {
            visible: text !== ""
            width: parent.width
            text: podos.actionStatus !== "" ? podos.actionStatus
              : (podos.state !== "ready" && podos.state !== "loading" ? podos.message : "")
            color: podos.actionStatus !== "" ? root.dim : root.urgent
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PlainLabel {
            visible: podos.state === "ready" && root.rows.length === 0
            width: parent.width
            topPadding: Style.space(12)
            bottomPadding: Style.space(12)
            text: root.tasksTab ? strings.t("emptyTasks") : strings.t("empty")
            color: root.dim
            horizontalAlignment: Text.AlignHCenter
          }

          PlainLabel {
            visible: podos.state === "loading" && root.rows.length === 0
            width: parent.width
            text: strings.t("loading")
            color: root.dim
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            id: rowColumn
            width: parent.width
            spacing: Style.space(2)

            Repeater {
              model: root.entries
              Item {
                id: entryItem
                required property var modelData
                readonly property var entry: modelData
                width: rowColumn.width
                implicitHeight: dayHeader.visible ? dayHeader.implicitHeight
                  : (notificationRow.visible ? notificationRow.implicitHeight : taskRow.implicitHeight)
                height: implicitHeight

                PanelSectionHeader {
                  id: dayHeader
                  visible: entryItem.entry.kind === "day"
                  width: parent.width
                  topPadding: Style.space(10)
                  bottomPadding: Style.space(2)
                  leftPadding: Style.spacing.rowPaddingX
                  text: visible ? entryItem.entry.label : ""
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }

                NotificationRow {
                  id: notificationRow
                  visible: entryItem.entry.kind === "notification"
                  width: parent.width
                  group: visible ? entryItem.entry.item : null
                  rowIndex: visible ? entryItem.entry.index : -1
                }

                TaskRow {
                  id: taskRow
                  visible: entryItem.entry.kind === "task"
                  width: parent.width
                  task: visible ? entryItem.entry.item : null
                  rowIndex: visible ? entryItem.entry.index : -1
                }
              }
            }
          }
        }
      }
    }
  }

  component PlainLabel: Text {
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
  }

  component NotificationRow: CursorSurface {
    id: row
    property var group: null
    property int rowIndex: -1
    readonly property bool isUnread: group !== null && group.unread > 0
    // Unread threads count what is new; read ones count everything.
    readonly property int shownCount: group ? (isUnread ? group.unread : group.count) : 0
    readonly property real padY: Style.spacing.lg

    hasCursor: root.cursorActive && root.rowIndex === rowIndex
    foreground: root.foreground
    implicitHeight: Math.max(rowContent.implicitHeight, avatar.height) + padY * 2

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onEntered: { root.cursorActive = true; root.rowIndex = row.rowIndex }
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) root.toggleRead(row.group)
        else root.activate(row.group)
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.rightMargin: Style.spacing.rowPaddingX
      anchors.topMargin: row.padY
      anchors.bottomMargin: row.padY
      spacing: Style.space(10)

      Avatar {
        id: avatar
        size: Style.space(32)
        name: row.group ? row.group.title : ""
        source: row.group && row.group.avatar ? row.group.avatar : ""
        foreground: root.foreground
        fontFamily: root.fontFamily
        opacity: row.isUnread ? 1 : 0.7
        Layout.alignment: Qt.AlignTop

        // Unread marker on the avatar's corner, in the theme's accent,
        // ringed in the panel colour so it reads against any photo.
        Rectangle {
          visible: row.isUnread
          width: Style.space(10)
          height: width
          radius: width / 2
          x: -Style.space(2)
          y: -Style.space(2)
          color: Commons.Color.accent
          border.width: Math.max(1, Style.space(2))
          border.color: Commons.Color.popups.background
        }
      }

      ColumnLayout {
        id: rowContent
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Style.spacing.labelGap

        PlainLabel {
          Layout.fillWidth: true
          text: row.group ? row.group.title : ""
          font.bold: row.isUnread
          color: row.isUnread ? root.foreground : Qt.darker(root.foreground, 1.2)
        }

        PlainLabel {
          Layout.fillWidth: true
          visible: text !== ""
          text: row.group ? row.group.body : ""
          color: root.dim
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          maximumLineCount: 2
        }
      }

      // One fixed column on the right: time over count, swapped for the
      // read/unread button on the row under the cursor.
      Item {
        Layout.alignment: Qt.AlignTop
        Layout.fillHeight: true
        implicitWidth: Math.max(meta.implicitWidth, toggle.width)

        ColumnLayout {
          id: meta
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: Style.spacing.labelGap
          opacity: row.hasCursor ? 0 : 1
          Behavior on opacity { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }

          PlainLabel {
            Layout.alignment: Qt.AlignRight
            text: row.group ? root.ago(row.group.createdAt) : ""
            color: root.dim
            font.pixelSize: Style.font.caption
          }
          PlainLabel {
            Layout.alignment: Qt.AlignRight
            visible: row.shownCount > 1
            text: "×" + row.shownCount
            color: row.isUnread ? root.urgent : root.dim
            font.pixelSize: Style.font.caption
          }
        }

        PanelActionButton {
          id: toggle
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          iconText: row.isUnread ? "󰄬" : "󰇮"
          tooltipText: row.isUnread ? strings.t("markRead") : strings.t("markUnread")
          foreground: root.foreground
          fontFamily: root.fontFamily
          opacity: row.hasCursor ? 1 : 0
          enabled: row.hasCursor
          onClicked: root.toggleRead(row.group)
          Behavior on opacity { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
        }
      }
    }
  }

  component TaskRow: CursorSurface {
    id: taskItem
    property var task: null
    property int rowIndex: -1

    hasCursor: root.cursorActive && root.rowIndex === rowIndex
    foreground: root.foreground
    implicitHeight: taskContent.implicitHeight + Style.spacing.lg * 2

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: { root.cursorActive = true; root.rowIndex = taskItem.rowIndex }
      onClicked: root.activate(taskItem.task)
    }

    ColumnLayout {
      id: taskContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.rightMargin: Style.spacing.rowPaddingX
      spacing: Style.spacing.md

      PlainLabel {
        Layout.fillWidth: true
        text: taskItem.task ? taskItem.task.title : ""
        wrapMode: Text.WordWrap
        maximumLineCount: 2
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        PlainLabel {
          text: taskItem.task ? "#" + taskItem.task.displayId : ""
          color: root.dim
          font.pixelSize: Style.font.caption
        }

        // Work progress, drawn like the shell's own sliders: the theme's
        // selected fill for the track and its accent for the fill.
        Rectangle {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          implicitHeight: Math.max(4, Math.round(Style.spacing.controlHeight * 0.11))
          radius: height / 2
          color: root.bar ? Style.selectedFillFor(root.bar.foreground, Commons.Color.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)

          Rectangle {
            width: parent.width * (taskItem.task ? taskItem.task.progress : 0) / 100
            height: parent.height
            radius: parent.radius
            color: Commons.Color.accent
          }
        }

        PlainLabel {
          text: {
            if (!taskItem.task) return ""
            var parts = [taskItem.task.progress + "%"]
            if (taskItem.task.estimate !== null && taskItem.task.estimate !== undefined)
              parts.push(strings.t("estimate").arg(Commons.I18n.formatNumber(taskItem.task.estimate, 0)))
            return parts.join(" · ")
          }
          color: root.dim
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
