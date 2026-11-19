// Plain helpers for Launcher.qml: fuzzy matching, frecency and a small safe calculator.
// No QML here, so it loads once and is shared (`.pragma library`).
.pragma library

// ---- fuzzy matching ----
// How well `q` (lower case) matches `s`: 0 = not at all, 100 = exactly.
// Order: exact > starts with > a word starts with > contains > initials / letters in order.
// `loose` allows the letters-in-order match (names only: on long keyword lists it matches junk).
function fuzzy(q, s, loose) {
    if (!q || !s) return 0;
    s = String(s).toLowerCase();
    if (s === q) return 100;
    // a whole first word ("obs" → "OBS Studio") beats a longer word that starts the same ("Obsidian")
    if (s.startsWith(q)) return (/[\s\-_.:/(]/.test(s[q.length]) ? 91 : 90) - Math.min(s.length - q.length, 30) * 0.2;
    const i = s.indexOf(q);
    if (i > 0) return /[\s\-_.:/(]/.test(s[i - 1]) ? 78 : 62;
    // punctuation and spaces don't count: "wifi" → "Wi-Fi", "localsend" → "Local Send"
    const sq = s.replace(/[\s\-_.]/g, ""), qq = q.replace(/[\s\-_.]/g, "");
    if (qq.length > 1 && sq !== s) {
        if (sq === qq) return 97;
        if (sq.startsWith(qq)) return 86 - Math.min(sq.length - qq.length, 30) * 0.2;
    }
    if (!loose || q.length < 2) return 0;
    // letters in order: "vsc" → "Visual Studio Code"; word starts count extra, gaps count against
    let from = 0, starts = 0, gaps = 0;
    for (const c of q) {
        if (c === " ") continue;
        const k = s.indexOf(c, from);
        if (k < 0) return 0;
        if (k === 0 || /[\s\-_.:/(]/.test(s[k - 1])) starts++;
        gaps += k - from;
        from = k + 1;
    }
    // Only a tidy match counts: mostly word starts ("vsc"), or letters close together. Before,
    // any name with the letters somewhere in order matched ("term" → "Fcitx 5 Wayland Launcher").
    const v = 25 + starts * 8 - gaps * 1.5;
    return v >= 22 ? Math.min(50, v) : 0;
}

// Best score of an item: `fields` is [[text, weight, loose], ...]. Several words ("wifi off")
// must each match one of the fields; the whole query matching one field scores higher.
function score(q, fields) {
    let best = 0;
    for (const [t, w, loose] of fields) best = Math.max(best, fuzzy(q, t, loose) * w);
    const words = q.split(/\s+/).filter(x => x);
    if (words.length > 1) {
        let worst = 100;
        for (const word of words) {
            let b = 0;
            for (const [t, w] of fields) b = Math.max(b, fuzzy(word, t, false) * w);
            worst = Math.min(worst, b);
        }
        best = Math.max(best, worst * 0.85);
    }
    return best;
}

// ---- frecency ----
// Bonus from how often and how lately you picked something: { n: times, t: last time (ms) }
function frecency(rec, now) {
    if (!rec) return 0;
    const days = (now - rec.t) / 86400000;
    const fresh = days < 1 ? 1 : days < 7 ? 0.8 : days < 30 ? 0.5 : 0.3;
    return Math.min(25, 6 * Math.log2(1 + rec.n)) * fresh;
}

// ---- calculator (used when qalc isn't installed, and instantly while qalc thinks) ----
// Recursive descent over numbers, + - * / % ^, brackets, a few functions and constants.
// Never uses eval. Returns a number, or null when the text isn't a sum.
const FUNCS = {
    sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
    ln: Math.log, log: Math.log10, log2: Math.log2, exp: Math.exp
};
const CONSTS = { pi: Math.PI, e: Math.E, tau: 2 * Math.PI };

function calc(text) {
    const src = String(text).toLowerCase().replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, "");
    if (!/\d/.test(src) || !/[-+*/^%()]|[a-z]/.test(src)) return null; // a bare number isn't a sum
    let pos = 0;
    const peek = () => { while (src[pos] === " ") pos++; return src[pos] };
    const eat = c => { if (peek() === c) { pos++; return true } return false };

    function primary() {
        const c = peek();
        if (c === "(") { pos++; const v = expr(); if (!eat(")")) throw 0; return v }
        if (c === "-") { pos++; return -power() }
        if (c === "+") { pos++; return power() }
        const num = /^(\d+\.?\d*|\.\d+)(e[-+]?\d+)?/.exec(src.slice(pos));
        if (num) { pos += num[0].length; return parseFloat(num[0]) }
        const id = /^[a-z][a-z0-9]*/.exec(src.slice(pos));
        if (id) {
            pos += id[0].length;
            if (id[0] in CONSTS) return CONSTS[id[0]];
            if (id[0] in FUNCS) {
                if (peek() === "(") { pos++; const v = expr(); if (!eat(")")) throw 0; return FUNCS[id[0]](v) }
                return FUNCS[id[0]](power());
            }
        }
        throw 0;
    }
    function postfix() { // 5! and 20%
        let v = primary();
        for (;;) {
            if (peek() === "!") { pos++; let f = 1; for (let i = 2; i <= v; i++) f *= i; v = f }
            else break;
        }
        return v;
    }
    function power() { const b = postfix(); return eat("^") ? Math.pow(b, unary()) : b }
    function unary() { return eat("-") ? -unary() : power() }
    function term() {
        let v = unary();
        for (;;) {
            if (eat("*")) v *= unary();
            else if (eat("/")) v /= unary();
            else if (eat("%")) v %= unary();
            else if (/[\d(a-z.]/.test(peek() ?? "")) v *= unary(); // 2pi, 3(4+1)
            else return v;
        }
    }
    function expr() {
        let v = term();
        for (;;) {
            if (eat("+")) v += term();
            else if (eat("-")) v -= term();
            else return v;
        }
    }
    try {
        const v = expr();
        if (peek() !== undefined || !isFinite(v)) return null;
        return v;
    } catch (e) { return null }
}

// 0.30000000000000004 → "0.3"; big and tiny numbers in e-notation
function formatNumber(v) {
    if (Number.isInteger(v) && Math.abs(v) < 1e15) return String(v);
    const a = Math.abs(v);
    if (a !== 0 && (a >= 1e15 || a < 1e-6)) return v.toExponential(8).replace(/\.?0+e/, "e");
    return String(parseFloat(v.toPrecision(12)));
}

// Does the text look like a sum or a conversion (worth asking qalc)? "2+2", "10 km to mi", "sqrt 2"
function looksMathy(q) {
    return /\d/.test(q) && (/[-+*/^%()!×÷]/.test(q) || /\b(to|in|sqrt|sin|cos|tan|log|ln|mod)\b/i.test(q))
        && !/^\d{1,3}(\.\d{1,3}){3}$/.test(q); // not an IP address
}

// A web address typed in full or as "example.com/page"
function looksLikeUrl(q) {
    if (/\s/.test(q)) return false;
    if (/^https?:\/\/\S+$/i.test(q) || /^localhost(:\d+)?(\/\S*)?$/i.test(q)) return true;
    // a bare name needs a real web ending: "readme.md" and "notes.txt" are file names, not sites
    return /^[\w-]+(\.[\w-]+)*\.(com|org|net|io|dev|app|ai|co|uk|my|me|gov|edu|sh|so|gg|tv|fm|xyz|tech|cloud|info|jp|de|fr|us|ca|au|sg)(:\d+)?(\/\S*)?$/i.test(q);
}
