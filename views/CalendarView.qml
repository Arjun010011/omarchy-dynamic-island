import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// The calendar: a month on the left (today filled, the selected day ringed,
// a dot under days with events) and the selected day's events on the right.
// Click an event to open its meeting link. The + button (or the empty
// state) opens a field to paste a calendar's .ics link.
Item {
  id: view

  property var island: null
  readonly property var cal: island.calendar
  readonly property int pad: island.s(18)

  readonly property date today: new Date()
  property int year: today.getFullYear()
  property int monthIndex: today.getMonth()
  property double selected: new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime()
  property bool adding: false

  readonly property var days: cal.month(year, monthIndex)
  readonly property var dayEvents: days[Model.dayKey(selected)] || []
  readonly property bool hasCalendars: cal.sources.length > 0

  // Monday or Sunday first, whatever the locale says.
  readonly property int firstWeekday: Qt.locale().firstDayOfWeek % 7
  readonly property int leadingBlanks: (new Date(year, monthIndex, 1).getDay() - firstWeekday + 7) % 7

  // Back to today whenever it is opened.
  onVisibleChanged: {
    if (!visible) return
    var t = new Date()
    year = t.getFullYear()
    monthIndex = t.getMonth()
    selected = new Date(t.getFullYear(), t.getMonth(), t.getDate()).getTime()
    adding = !hasCalendars
  }
  onAddingChanged: island.calendarTyping = adding

  function shiftMonth(delta) {
    var d = new Date(year, monthIndex + delta, 1)
    year = d.getFullYear()
    monthIndex = d.getMonth()
  }

  function timeText(t) {
    return Qt.formatDateTime(new Date(t), island.clockFormat.indexOf("AP") !== -1 ? "h:mm AP" : "HH:mm")
  }

  // ------------------------------------------------------------ month grid
  Item {
    id: monthPane
    x: view.pad
    y: view.pad
    width: island.s(7 * 32)
    height: parent.height - view.pad * 2

    Item {
      id: header
      width: parent.width
      height: island.s(26)

      Text {
        anchors.left: parent.left
        anchors.leftMargin: island.s(4)
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.locale().standaloneMonthName(view.monthIndex) + " " + view.year
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(14)
        font.bold: true
        color: island.fg
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        IconButton {
          glyph: "󰅁"
          glyphSize: island.f(13)
          color: island.fg
          fontFamily: island.fontFamily
          onClicked: view.shiftMonth(-1)
        }

        IconButton {
          glyph: "󰅂"
          glyphSize: island.f(13)
          color: island.fg
          fontFamily: island.fontFamily
          onClicked: view.shiftMonth(1)
        }
      }
    }

    Row {
      id: weekdays
      y: header.height + island.s(6)

      Repeater {
        model: 7

        Text {
          required property int index
          width: island.s(32)
          horizontalAlignment: Text.AlignHCenter
          text: Qt.locale().dayName((view.firstWeekday + index) % 7, Locale.NarrowFormat)
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(10)
          color: island.fgDim
        }
      }
    }

    Grid {
      y: weekdays.y + weekdays.height + island.s(4)
      columns: 7

      Repeater {
        model: 42

        Item {
          id: cell
          required property int index
          readonly property date date: new Date(view.year, view.monthIndex, 1 - view.leadingBlanks + index)
          readonly property double time: date.getTime()
          readonly property bool inMonth: date.getMonth() === view.monthIndex
          readonly property bool isToday: Model.dayKey(time) === Model.dayKey(Date.now())
          readonly property bool isSelected: time === view.selected
          readonly property bool busy: !!view.days[Model.dayKey(time)]

          width: island.s(32)
          height: island.s(26)

          Rectangle {
            anchors.centerIn: parent
            width: island.s(24)
            height: width
            radius: width / 2
            color: cell.isToday ? island.accentColor
              : (dayMouse.containsMouse ? Util.alpha(island.fg, 0.1) : "transparent")
            border.width: cell.isSelected && !cell.isToday ? Math.max(1, island.s(1.5)) : 0
            border.color: island.accentColor
          }

          Text {
            anchors.centerIn: parent
            text: cell.date.getDate()
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.fontFamily
            font.pixelSize: island.f(11)
            font.bold: cell.isToday || cell.isSelected
            font.features: { "tnum": 1 }
            color: cell.isToday ? island.surface : island.fg
            opacity: cell.inMonth ? 1 : 0.3
          }

          Rectangle {
            visible: cell.busy
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: island.s(0)
            width: island.s(4)
            height: width
            radius: width / 2
            color: cell.isToday ? island.fg : island.orangeColor
            opacity: cell.inMonth ? 1 : 0.4
          }

          MouseArea {
            id: dayMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              view.selected = cell.time
              view.adding = false
              if (!cell.inMonth) view.shiftMonth(cell.date < new Date(view.year, view.monthIndex, 1) ? -1 : 1)
            }
          }
        }
      }
    }
  }

  // ----------------------------------------------------------- right column
  Item {
    id: side
    anchors.left: monthPane.right
    anchors.leftMargin: island.s(16)
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    y: view.pad
    height: parent.height - view.pad * 2

    Item {
      id: sideHeader
      width: parent.width
      height: island.s(26)

      Text {
        anchors.left: parent.left
        anchors.right: addButton.left
        anchors.verticalCenter: parent.verticalCenter
        text: view.adding ? "Calendars" : Qt.formatDate(new Date(view.selected), "dddd d")
        elide: Text.ElideRight
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(13)
        font.bold: true
        color: island.fg
      }

      IconButton {
        id: addButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        glyph: view.adding ? "󰅖" : "󰐕"
        glyphSize: island.f(13)
        color: island.fg
        fontFamily: island.fontFamily
        onClicked: view.adding = !view.adding
      }
    }

    // --- the day's events
    ListView {
      visible: !view.adding
      y: sideHeader.height + island.s(6)
      width: parent.width
      height: parent.height - y
      clip: true
      spacing: island.s(4)
      boundsBehavior: Flickable.StopAtBounds
      model: view.dayEvents

      delegate: Rectangle {
        id: eventRow
        required property var modelData
        readonly property bool past: !modelData.allDay && modelData.end < Date.now()
        width: ListView.view.width
        height: island.s(40)
        radius: island.s(12)
        color: Util.alpha(island.fg, eventMouse.containsMouse && modelData.url ? 0.1 : 0.05)
        opacity: past ? 0.5 : 1

        Rectangle {
          x: island.s(8)
          anchors.verticalCenter: parent.verticalCenter
          width: island.s(3)
          height: parent.height - island.s(16)
          radius: width / 2
          color: eventRow.modelData.allDay ? island.orangeColor : island.accentColor
        }

        Column {
          x: island.s(18)
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - island.s(26)
          spacing: island.s(1)

          Text {
            width: parent.width
            text: eventRow.modelData.title || "Busy"
            elide: Text.ElideRight
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.fontFamily
            font.pixelSize: island.f(12)
            font.bold: true
            color: island.fg
          }

          Text {
            text: eventRow.modelData.allDay ? "All day"
              : view.timeText(eventRow.modelData.start) + " – " + view.timeText(eventRow.modelData.end)
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.fontFamily
            font.pixelSize: island.f(10)
            color: island.fgDim
          }
        }

        Text {
          visible: !!eventRow.modelData.url
          anchors.right: parent.right
          anchors.rightMargin: island.s(10)
          anchors.verticalCenter: parent.verticalCenter
          text: "󰏌"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(12)
          color: island.accentColor
        }

        MouseArea {
          id: eventMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: eventRow.modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: if (eventRow.modelData.url) island.openLink(eventRow.modelData.url)
        }
      }
    }

    Text {
      visible: !view.adding && view.dayEvents.length === 0
      y: sideHeader.height + island.s(30)
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      text: view.hasCalendars ? "Nothing scheduled" : "No calendar added yet.\nTap + to add one."
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(12)
      color: island.fgDim
    }

    // --- add / remove calendars
    Column {
      visible: view.adding
      y: sideHeader.height + island.s(6)
      width: parent.width
      spacing: island.s(6)

      Rectangle {
        width: parent.width
        height: island.s(30)
        radius: height / 2
        color: Util.alpha(island.fg, 0.08)
        border.width: input.activeFocus ? 1 : 0
        border.color: island.accentColor

        TextInput {
          id: input
          anchors.left: parent.left
          anchors.leftMargin: island.s(12)
          anchors.right: parent.right
          anchors.rightMargin: island.s(12)
          anchors.verticalCenter: parent.verticalCenter
          clip: true
          font.family: island.fontFamily
          font.pixelSize: island.f(11)
          color: island.fg
          selectionColor: Util.alpha(island.accentColor, 0.5)
          renderType: Text.NativeRendering
          selectByMouse: true

          function commit() {
            var link = text.trim()
            if (!link) return
            island.addCalendar(link)
            text = ""
            view.adding = false
          }

          Keys.onReturnPressed: commit()
          Keys.onEnterPressed: commit()
          Keys.onEscapePressed: view.adding = false

          Text {
            anchors.fill: parent
            visible: input.text === ""
            text: "Paste a calendar link (.ics)"
            elide: Text.ElideRight
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font: input.font
            color: island.fgDim
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.IBeamCursor
          onClicked: input.forceActiveFocus()
          // Let the TextInput handle drags/selection once focused.
          enabled: !input.activeFocus
        }
      }

      // Calendars already added, each with its own ×.
      Repeater {
        model: view.cal.sources

        Rectangle {
          id: source
          required property var modelData
          width: parent.width
          height: island.s(26)
          radius: height / 2
          color: Util.alpha(island.fg, 0.05)

          Text {
            anchors.left: parent.left
            anchors.leftMargin: island.s(12)
            anchors.right: remove.left
            anchors.rightMargin: island.s(6)
            anchors.verticalCenter: parent.verticalCenter
            text: String(source.modelData).replace(/^[a-z]+:\/\//, "").replace(/\?.*$/, "")
            elide: Text.ElideMiddle
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.fontFamily
            font.pixelSize: island.f(10)
            color: island.fg
          }

          IconButton {
            id: remove
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glyph: "󰅖"
            glyphSize: island.f(10)
            color: island.fg
            fontFamily: island.fontFamily
            onClicked: island.removeCalendar(source.modelData)
          }
        }
      }

      Text {
        visible: view.cal.sources.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Google: Settings › your calendar › Secret address in iCal format. " +
              "iCloud: share as public calendar. Outlook: Publish a calendar › ICS."
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(10)
        lineHeight: 1.15
        color: island.fgDim
      }
    }
  }
}
