// Small helpers more than one file needs (import "Common.js" as Common).
// No QML here, so it loads once and is shared (`.pragma library`).
.pragma library

// Seconds as "2 h 05 m" (battery time left / to full)
function hm(secs) {
    const m = Math.round(secs / 60);
    return Math.floor(m / 60) + " h " + (m % 60 < 10 ? "0" : "") + m % 60 + " m";
}

// Which Icon.qml icon fits a Bluetooth device, from BlueZ's icon name
function btKind(d) {
    const i = d?.icon ?? "";
    return /audio|headset|headphone/.test(i) ? "headphones" : /input-keyboard/.test(i) ? "keyboard" : "bluetooth";
}

// `brightnessctl -m` ("amdgpu_bl2,backlight,45875,70%,65535") as 0..1, or -1 without a backlight
function brightness(text) {
    const f = String(text).trim().split(",");
    return f.length >= 5 && Number(f[4]) > 0 ? Number(f[2]) / Number(f[4]) : -1;
}

// Lists EasyEffects' output presets (the files in its presets folders), one name per line
const easyEffectsPresets = ["sh", "-c", "for d in \"$HOME/.local/share/easyeffects/output\" \"$HOME/.config/easyeffects/output\"; do [ -d \"$d\" ] && ls \"$d\"; done | sed -n 's/\\.json$//p' | sort -u"];
