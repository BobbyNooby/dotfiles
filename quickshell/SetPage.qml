// One page of the Settings window (SettingsWindow.qml): a title, a line under it, and the
// content stacked in a scrolling column. The pages are Set*Page.qml files.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: page
    property string title
    property string subtitle
    default property alias content: col.data
    contentHeight: col.implicitHeight + 40
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    ScrollBar.vertical: ScrollBar { policy: page.contentHeight > page.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
    SmoothWheel { flick: page }

    ColumnLayout {
        id: col
        x: 32
        y: 28
        width: page.width - 64
        spacing: 14
        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: 4
            Txt { heading: true; text: page.title; font.pixelSize: 24 }
            Txt { visible: page.subtitle !== ""; Layout.fillWidth: true; text: page.subtitle; color: Theme.textDim; wrapMode: Text.Wrap }
        }
    }
}
