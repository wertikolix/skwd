import QtQuick
import Quickshell
import Quickshell.Widgets
import "../.."

Rectangle {
  id: root

  required property var colors

  property real contentWidth: 320
  property string side: "right"

  property bool active: false
  property var menuHandle: null
  property string title: ""

  // submenu drill-down stack of QsMenuHandle
  property var _menuStack: []
  readonly property var _currentMenu: _menuStack.length > 0 ? _menuStack[_menuStack.length - 1] : menuHandle

  signal requestClose()

  QsMenuOpener {
    id: opener
    menu: root._currentMenu
  }

  function _enterSubmenu(entry) {
    var stack = _menuStack.slice()
    stack.push(entry)
    _menuStack = stack
  }

  function _goBack() {
    if (_menuStack.length === 0) return
    var stack = _menuStack.slice()
    stack.pop()
    _menuStack = stack
  }

  readonly property real animatedHeight: _animatedHeight
  property real _targetHeight: 0
  property real _animatedHeight: _targetHeight
  Behavior on _animatedHeight {
    NumberAnimation {
      duration: 320
      easing.type: Easing.BezierSpline
      easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    }
  }

  height: _animatedHeight
  visible: _animatedHeight > 0
  clip: true
  color: Qt.rgba(root.colors.surface.r, root.colors.surface.g, root.colors.surface.b, 0.88)
  radius: Config.barStyle === "pill" ? 16 : 0
  topLeftRadius: 0
  topRightRadius: 0

  onActiveChanged: {
    if (active) _targetHeight = menuColumn.implicitHeight + 24
    else { _targetHeight = 0; _menuStack = [] }
  }

  Rectangle {
    visible: Config.barStyle !== "pill"
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 2
    color: root.colors.primary
    property real animatedWidth: root.visible ? parent.width : 0
    width: animatedWidth
    Behavior on animatedWidth {
      NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
  }

  Column {
    id: menuColumn
    anchors.left:  root.side === "left"  ? parent.left  : undefined
    anchors.right: root.side === "right" ? parent.right : undefined
    anchors.leftMargin:  root.side === "left"  ? 12 : 0
    anchors.rightMargin: root.side === "right" ? 12 : 0
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 12
    spacing: 2
    width: root.contentWidth - 24

    onImplicitHeightChanged: {
      if (root.active) root._targetHeight = menuColumn.implicitHeight + 24
    }

    opacity: root.active && root._animatedHeight > (menuColumn.implicitHeight * 0.5) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Item {
      width: parent.width
      height: 24

      Item {
        id: backBtn
        visible: root._menuStack.length > 0
        width: backRow.implicitWidth
        height: parent.height
        anchors.left: parent.left

        Row {
          id: backRow
          spacing: 4
          anchors.verticalCenter: parent.verticalCenter
          Text {
            text: "󰅁"
            color: root.colors.primary
            font.pixelSize: 14
            font.family: Style.fontFamilyNerdIcons
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "BACK"
            color: root.colors.primary
            font.pixelSize: 11
            font.family: Style.fontFamily
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
            anchors.verticalCenter: parent.verticalCenter
          }
        }
        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          cursorShape: Qt.PointingHandCursor
          onClicked: root._goBack()
        }
      }

      Text {
        text: root.title.toUpperCase()
        color: root.colors.primary
        font.pixelSize: 14
        font.family: Style.fontFamily
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        anchors.left: backBtn.visible ? backBtn.right : parent.left
        anchors.leftMargin: backBtn.visible ? 10 : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignLeft
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.18)
    }

    Item { width: 1; height: 4 }

    Text {
      visible: opener.children === null || opener.children.values.length === 0
      text: "no menu entries"
      color: Qt.rgba(root.colors.tertiary.r, root.colors.tertiary.g, root.colors.tertiary.b, 0.6)
      font.pixelSize: 12
      font.family: Style.fontFamily
      font.italic: true
    }

    Repeater {
      model: opener.children

      delegate: Item {
        id: entryRow
        required property var modelData
        readonly property bool isSep: modelData.isSeparator === true
        readonly property bool checkable: modelData.buttonType !== QsMenuButtonType.None
        readonly property bool checked: modelData.checkState === Qt.Checked

        width: menuColumn.width
        height: isSep ? 9 : 26

        Rectangle {
          visible: entryRow.isSep
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: 1
          color: Qt.rgba(root.colors.outline.r, root.colors.outline.g, root.colors.outline.b, 0.25)
        }

        Rectangle {
          visible: !entryRow.isSep
          anchors.fill: parent
          color: entryMouse.containsMouse && entryRow.modelData.enabled !== false
            ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.12)
            : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
        }

        Row {
          visible: !entryRow.isSep
          spacing: 8
          anchors.left: parent.left
          anchors.leftMargin: 6
          anchors.right: chevron.left
          anchors.rightMargin: 4
          anchors.verticalCenter: parent.verticalCenter

          Item {
            width: 14
            height: 14
            visible: entryRow.checkable
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
              anchors.fill: parent
              radius: entryRow.modelData.buttonType === QsMenuButtonType.RadioButton ? 7 : 3
              color: entryRow.checked
                ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.9)
                : "transparent"
              border.width: 1
              border.color: entryRow.checked
                ? "transparent"
                : Qt.rgba(root.colors.outline.r, root.colors.outline.g, root.colors.outline.b, 0.6)
            }
            Text {
              visible: entryRow.checked && entryRow.modelData.buttonType === QsMenuButtonType.CheckBox
              anchors.centerIn: parent
              text: "󰄬"
              font.pixelSize: 10
              font.family: Style.fontFamilyNerdIcons
              color: root.colors.primaryText
            }
          }

          IconImage {
            visible: (entryRow.modelData.icon || "") !== ""
            source: entryRow.modelData.icon || ""
            width: 14
            height: 14
            asynchronous: true
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: entryRow.modelData.text || ""
            color: entryRow.modelData.enabled === false
              ? Qt.rgba(root.colors.tertiary.r, root.colors.tertiary.g, root.colors.tertiary.b, 0.35)
              : root.colors.tertiary
            font.pixelSize: 12
            font.family: Style.fontFamily
            font.weight: Font.Medium
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Text {
          id: chevron
          visible: !entryRow.isSep && entryRow.modelData.hasChildren === true
          text: "󰅂"
          color: root.colors.primary
          font.pixelSize: 13
          font.family: Style.fontFamilyNerdIcons
          anchors.right: parent.right
          anchors.rightMargin: 4
          anchors.verticalCenter: parent.verticalCenter
        }

        MouseArea {
          id: entryMouse
          visible: !entryRow.isSep
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: entryRow.modelData.enabled !== false ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (entryRow.modelData.enabled === false) return
            if (entryRow.modelData.hasChildren === true) {
              root._enterSubmenu(entryRow.modelData)
            } else {
              entryRow.modelData.triggered()
              root.requestClose()
            }
          }
        }
      }
    }
  }
}
