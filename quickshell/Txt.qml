// Text in the shell's font. `heading: true` switches to the display font (Theme.typeface),
// in italic or capitals when the chosen pairing asks for it.
import QtQuick

Text {
    property bool heading: false
    color: Theme.text
    font.family: heading ? Theme.display : Theme.font
    font.pixelSize: Theme.fontSize
    font.weight: heading ? Font.DemiBold : Font.Normal
    font.italic: heading && Theme.displayItalic
    font.capitalization: heading && Theme.displayCaps ? Font.AllUppercase : Font.MixedCase
    font.features: { "tnum": 1 } // digits all the same width, so clocks and % don't wobble
    verticalAlignment: Text.AlignVCenter
}
