// A group of rows on a settings page: a small heading above a rounded card.
// `trailing` puts something at the right of the heading (a Scan button, a count).
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: card
    property string title
    property alias trailing: head.data
    default property alias content: inner.data
    property int pad: 6
    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        visible: card.title !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Txt { Layout.fillWidth: true; text: card.title; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.textDim }
        RowLayout { id: head; spacing: 6; Layout.fillWidth: false }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 2 * card.pad
        radius: Theme.r(18)
        color: Theme.bgMid
        ColumnLayout {
            id: inner
            x: card.pad
            y: card.pad
            width: parent.width - 2 * card.pad
            spacing: 2
        }
    }
}
