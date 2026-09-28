import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// A notification, iOS-banner style: app icon, app name, summary and body,
// with the sender's action buttons along the bottom when it has any.
//
// Click invokes it (default action, or focus the app); right or middle
// click dismisses it. Hovering holds it open.
Item {
  id: view

  property var island: null
  readonly property var entry: island.notification
  // The live object, when there is one, so replaces_id updates show up.
  readonly property var live: entry && entry.ref ? entry.ref : null
  readonly property string summary: live ? Model.plainText(live.summary) : (entry ? entry.summary : "")
  readonly property string body: live ? Model.plainText(live.body) : (entry ? entry.body : "")
  readonly property var actions: entry ? entry.actions : []
  readonly property color tone: entry && entry.critical ? island.urgentColor : island.accentColor
  readonly property int pad: island.s(16)

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (!view.entry) return
      if (mouse.button === Qt.LeftButton) island.notificationOpen(view.entry.key)
      else island.notificationDismiss(view.entry.key)
    }
  }

  AlbumArt {
    id: icon
    x: view.pad
    y: island.s(16)
    width: island.s(46)
    height: width
    radius: Math.round(width * 0.28)
    source: island.notificationIcon(view.entry)
    placeholder: view.entry && view.entry.glyph ? view.entry.glyph : "󰂚"
    tint: view.tone
    fontFamily: island.fontFamily
  }

  Column {
    anchors.left: icon.right
    anchors.leftMargin: island.s(12)
    anchors.right: parent.right
    anchors.rightMargin: view.pad + island.s(4)
    y: icon.y - island.s(1)
    spacing: island.s(2)

    Item {
      width: parent.width
      height: appLabel.implicitHeight

      Text {
        id: appLabel
        anchors.left: parent.left
        anchors.right: badge.visible ? badge.left : closeButton.left
        anchors.rightMargin: island.s(6)
        text: view.entry ? (view.entry.app || "Notification") + (view.entry.replay ? "  ·  earlier" : "") : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        elide: Text.ElideRight
        font.family: island.textFamily
        font.pixelSize: island.f(11)
        color: view.entry && view.entry.critical ? island.urgentColor : island.fgDim
      }

      // × clears this one without opening it.
      Rectangle {
        id: closeButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: island.s(20)
        height: width
        radius: width / 2
        color: Util.alpha(island.fg, closeMouse.pressed ? 0.24 : (closeMouse.containsMouse ? 0.16 : 0.08))

        Text {
          anchors.centerIn: parent
          text: "󰅖"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(10)
          color: island.fg
        }

        MouseArea {
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (view.entry) island.notificationDismiss(view.entry.key)
        }
      }

      // More waiting behind this one.
      Rectangle {
        id: badge
        visible: island.notificationsPending > 0
        anchors.right: closeButton.left
        anchors.rightMargin: island.s(6)
        anchors.verticalCenter: parent.verticalCenter
        height: badgeText.implicitHeight + island.s(2)
        width: badgeText.implicitWidth + island.s(12)
        radius: height / 2
        color: Util.alpha(view.tone, 0.22)

        Text {
          id: badgeText
          anchors.centerIn: parent
          text: "+" + island.notificationsPending
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.textFamily
          font.pixelSize: island.f(10)
          font.weight: Font.DemiBold
          color: view.tone
        }
      }
    }

    Text {
      width: parent.width
      text: view.summary
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      maximumLineCount: 1
      font.family: island.textFamily
      font.pixelSize: island.f(13)
      font.weight: Font.DemiBold
      color: island.fg
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: view.body
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      maximumLineCount: 1
      font.family: island.textFamily
      font.pixelSize: island.f(12)
      color: island.fgDim
    }
  }

  Row {
    visible: view.actions.length > 0
    x: view.pad
    anchors.bottom: parent.bottom
    anchors.bottomMargin: island.s(14)
    width: parent.width - view.pad * 2
    spacing: island.s(8)

    Repeater {
      model: view.actions

      Rectangle {
        required property var modelData
        width: (parent.width - parent.spacing * (view.actions.length - 1)) / view.actions.length
        height: island.s(28)
        radius: height / 2
        color: Util.alpha(island.fg, actionMouse.pressed ? 0.2 : (actionMouse.containsMouse ? 0.14 : 0.08))

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          width: parent.width - island.s(16)
          horizontalAlignment: Text.AlignHCenter
          text: modelData.text
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          elide: Text.ElideRight
          font.family: island.textFamily
          font.pixelSize: island.f(12)
          font.weight: Font.DemiBold
          color: island.fg
        }

        MouseArea {
          id: actionMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (view.entry) island.notificationAction(view.entry.key, modelData.id)
        }
      }
    }
  }
}
