// A list of shortcuts: key chips on the left, what they do on the right.
// rows: [[keys, label], [heading], ...] (see Shortcuts.qml). `mono` shows the keys in the code font.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: list
    property var rows: []
    property int keyWidth: 150
    property bool mono: false
    spacing: 6

    Repeater {
        model: list.rows
        RowLayout {
            id: row
            required property var modelData
            required property int index
            readonly property bool heading: modelData.length === 1
            Layout.fillWidth: true
            Layout.topMargin: heading && index > 0 ? 8 : 0
            spacing: 10

            Txt {
                visible: row.heading
                text: row.modelData[0]
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.accent
            }
            Rectangle {
                visible: !row.heading
                Layout.preferredWidth: list.keyWidth
                Layout.alignment: Qt.AlignTop
                implicitHeight: keyText.implicitHeight + 6
                radius: 6
                color: Theme.bgHighest
                Txt {
                    id: keyText
                    anchors.centerIn: parent
                    width: parent.width - 10
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: row.modelData[0]
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.family: list.mono ? Theme.mono : Theme.font
                }
            }
            Txt {
                visible: !row.heading
                Layout.fillWidth: true
                text: row.modelData[1] ?? ""
                font.pixelSize: 12
                color: Theme.textDim
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}
