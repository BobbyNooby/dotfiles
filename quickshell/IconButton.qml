// A small button: an icon and an optional label (Quick settings footer).
import QtQuick
import QtQuick.Layouts

Clicky {
    id: btn
    property string icon
    property string label
    implicitWidth: btnRow.implicitWidth + 24
    implicitHeight: 40
    radius: Theme.r(12)
    base: Theme.bgHigh
    RowLayout {
        id: btnRow
        anchors.centerIn: parent
        spacing: 6
        Icon { name: btn.icon; size: 15; color: Theme.textDim }
        Txt { visible: btn.label !== ""; text: btn.label; font.pixelSize: 12; font.weight: Font.DemiBold }
    }
}
