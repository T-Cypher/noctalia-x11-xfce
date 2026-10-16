// Shared helpers: time formatting (noctalia's "{:%H:%M}" chrono and plain strftime syntax),
// fuzzy matching, a safe calculator, and small formatting utilities.
.pragma library

function pad(n, width, ch) {
    var s = String(n);
    while (s.length < width)
        s = (ch === undefined ? "0" : ch) + s;
    return s;
}

function isoWeek(d) {
    var date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    var dayNum = date.getUTCDay() || 7;
    date.setUTCDate(date.getUTCDate() + 4 - dayNum);
    var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
    return {
        week: Math.ceil((((date - yearStart) / 86400000) + 1) / 7),
        year: date.getUTCFullYear()
    };
}

// strftime subset. `locale` is a Qt.locale() object (optional).
function strftime(fmt, d, locale) {
    var out = "";
    for (var i = 0; i < fmt.length; i++) {
        var c = fmt.charAt(i);
        if (c !== "%" || i === fmt.length - 1) {
            out += c;
            continue;
        }
        var f = fmt.charAt(++i);
        // GNU flags: %-d (no padding), %_d (space padding)
        var noPad = false, spacePad = false;
        if (f === "-" || f === "_") {
            noPad = f === "-";
            spacePad = f === "_";
            f = fmt.charAt(++i);
        }
        var p2 = function (n) {
            return noPad ? String(n) : pad(n, 2, spacePad ? " " : "0");
        };
        var h12 = d.getHours() % 12 === 0 ? 12 : d.getHours() % 12;
        switch (f) {
        case "a": out += locale ? locale.dayName(d.getDay(), 1) : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()]; break;
        case "A": out += locale ? locale.dayName(d.getDay(), 0) : ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][d.getDay()]; break;
        case "b":
        case "h": out += locale ? locale.monthName(d.getMonth(), 1) : ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][d.getMonth()]; break;
        case "B": out += locale ? locale.monthName(d.getMonth(), 0) : ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][d.getMonth()]; break;
        case "c": out += d.toLocaleString(locale); break;
        case "C": out += p2(Math.floor(d.getFullYear() / 100)); break;
        case "d": out += p2(d.getDate()); break;
        case "D": out += strftime("%m/%d/%y", d, locale); break;
        case "e": out += noPad ? String(d.getDate()) : pad(d.getDate(), 2, " "); break;
        case "F": out += strftime("%Y-%m-%d", d, locale); break;
        case "G": out += isoWeek(d).year; break;
        case "H": out += p2(d.getHours()); break;
        case "I": out += p2(h12); break;
        case "j": {
            var start = new Date(d.getFullYear(), 0, 0);
            var day = Math.floor((d - start) / 86400000);
            out += noPad ? String(day) : pad(day, 3);
            break;
        }
        case "k": out += noPad ? String(d.getHours()) : pad(d.getHours(), 2, " "); break;
        case "l": out += noPad ? String(h12) : pad(h12, 2, " "); break;
        case "m": out += p2(d.getMonth() + 1); break;
        case "M": out += p2(d.getMinutes()); break;
        case "n": out += "\n"; break;
        case "p": out += d.getHours() < 12 ? "AM" : "PM"; break;
        case "P": out += d.getHours() < 12 ? "am" : "pm"; break;
        case "r": out += strftime("%I:%M:%S %p", d, locale); break;
        case "R": out += strftime("%H:%M", d, locale); break;
        case "s": out += Math.floor(d.getTime() / 1000); break;
        case "S": out += p2(d.getSeconds()); break;
        case "t": out += "\t"; break;
        case "T": out += strftime("%H:%M:%S", d, locale); break;
        case "u": out += d.getDay() === 0 ? 7 : d.getDay(); break;
        case "V": out += p2(isoWeek(d).week); break;
        case "w": out += d.getDay(); break;
        case "x": out += locale ? d.toLocaleDateString(locale, 1) : d.toLocaleDateString(); break;
        case "X": out += locale ? d.toLocaleTimeString(locale, 1) : d.toLocaleTimeString(); break;
        case "y": out += p2(d.getFullYear() % 100); break;
        case "Y": out += d.getFullYear(); break;
        case "z": {
            var off = -d.getTimezoneOffset();
            out += (off >= 0 ? "+" : "-") + pad(Math.floor(Math.abs(off) / 60), 2) + pad(Math.abs(off) % 60, 2);
            break;
        }
        case "Z": {
            var m = /\(([^)]+)\)/.exec(d.toString());
            out += m ? m[1] : "";
            break;
        }
        case "%": out += "%"; break;
        default: out += "%" + f;
        }
    }
    return out;
}

// noctalia time formats use C++ std::format chrono syntax: "{:%H:%M}" possibly mixed with text,
// e.g. "{:%H:%M}\n{:%d/%m}". Formats without "{:" are treated as plain strftime strings.
function formatTime(fmt, d, locale) {
    if (!fmt)
        return "";
    var s = String(fmt);
    if (s.indexOf("{:") < 0)
        return strftime(s, d, locale);
    return s.replace(/\{:([^}]*)\}/g, function (_, spec) {
        return strftime(spec, d, locale);
    });
}

// Does the format show seconds? (used to pick the clock refresh interval)
function formatHasSeconds(fmt) {
    return /%[-_]?(S|T|r|s|c|X)/.test(String(fmt || ""));
}

function formatDuration(seconds) {
    seconds = Math.max(0, Math.floor(seconds));
    var d = Math.floor(seconds / 86400);
    var h = Math.floor((seconds % 86400) / 3600);
    var m = Math.floor((seconds % 3600) / 60);
    if (d > 0)
        return d + "d " + h + "h";
    if (h > 0)
        return h + "h " + m + "m";
    return m + "m";
}

function formatClock(seconds) {
    seconds = Math.max(0, Math.floor(seconds || 0));
    var h = Math.floor(seconds / 3600);
    var m = Math.floor((seconds % 3600) / 60);
    var s = seconds % 60;
    return (h > 0 ? h + ":" + pad(m, 2) : m) + ":" + pad(s, 2);
}

function formatBytes(bytes, decimals) {
    var units = ["B", "KiB", "MiB", "GiB", "TiB"];
    var v = Math.max(0, Number(bytes) || 0);
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024;
        i++;
    }
    var dec = decimals === undefined ? (v < 10 && i > 0 ? 1 : 0) : decimals;
    return v.toFixed(dec) + " " + units[i];
}

function formatSpeed(bytesPerSec, compact) {
    var v = Math.max(0, Number(bytesPerSec) || 0);
    var units = compact ? ["B", "K", "M", "G"] : ["B/s", "KB/s", "MB/s", "GB/s"];
    var i = 0;
    while (v >= 1000 && i < units.length - 1) {
        v /= 1000;
        i++;
    }
    return (v < 10 && i > 0 ? v.toFixed(1) : Math.round(v)) + (compact ? units[i] : " " + units[i]);
}

function relativeTime(ms, now) {
    var diff = Math.max(0, Math.floor(((now || Date.now()) - ms) / 1000));
    if (diff < 60)
        return "now";
    if (diff < 3600)
        return Math.floor(diff / 60) + "m";
    if (diff < 86400)
        return Math.floor(diff / 3600) + "h";
    return Math.floor(diff / 86400) + "d";
}

// ------------------------------------------------------------------------------------------
// Fuzzy matching (fzy-like): returns a score (higher is better) or -1 when not matching.
function fuzzyScore(needle, haystack) {
    if (!needle)
        return 0;
    var n = needle.toLowerCase();
    var h = String(haystack || "").toLowerCase();
    if (h.length === 0)
        return -1;
    var idx = h.indexOf(n);
    if (idx === 0)
        return 1000 - h.length;
    if (idx > 0) {
        var boundary = /[\s\-_.\/]/.test(h.charAt(idx - 1));
        return (boundary ? 800 : 600) - idx - h.length * 0.5;
    }
    // subsequence
    var score = 0, last = -1, consecutive = 0;
    for (var i = 0; i < n.length; i++) {
        var ch = n.charAt(i);
        var found = h.indexOf(ch, last + 1);
        if (found < 0)
            return -1;
        if (found === last + 1) {
            consecutive++;
            score += 6 * consecutive;
        } else {
            consecutive = 0;
            score -= Math.min(found - last, 10);
        }
        if (found === 0 || /[\s\-_.\/]/.test(h.charAt(found - 1)))
            score += 12;
        last = found;
    }
    return 200 + score - h.length * 0.2;
}

// ------------------------------------------------------------------------------------------
// Safe calculator: + - * / % ^ (), unary minus, constants pi/e, common functions.
function calculate(expr) {
    var s = String(expr).replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, ".");
    if (s.length === 0)
        return null;
    var pos = 0;
    var funcs = {
        sqrt: Math.sqrt, abs: Math.abs, sin: Math.sin, cos: Math.cos, tan: Math.tan,
        asin: Math.asin, acos: Math.acos, atan: Math.atan, ln: Math.log, log: Math.log10 || function (x) {
            return Math.log(x) / Math.LN10;
        }, log2: Math.log2 || function (x) {
            return Math.log(x) / Math.LN2;
        }, exp: Math.exp, floor: Math.floor, ceil: Math.ceil, round: Math.round
    };
    function peek() {
        return s.charAt(pos);
    }
    function number() {
        var start = pos;
        while (/[0-9.]/.test(peek()))
            pos++;
        if (peek() === "e" && /[0-9+\-]/.test(s.charAt(pos + 1)) && start !== pos) {
            pos++;
            if (/[+\-]/.test(peek()))
                pos++;
            while (/[0-9]/.test(peek()))
                pos++;
        }
        var v = parseFloat(s.substring(start, pos));
        if (isNaN(v))
            throw "bad number";
        return v;
    }
    function primary() {
        var c = peek();
        if (c === "(") {
            pos++;
            var v = expression();
            if (peek() !== ")")
                throw "missing )";
            pos++;
            return v;
        }
        if (c === "-") {
            pos++;
            return -power();
        }
        if (c === "+") {
            pos++;
            return power();
        }
        if (/[0-9.]/.test(c))
            return number();
        if (/[a-zπ]/i.test(c)) {
            var start = pos;
            while (/[a-z0-9π]/i.test(peek()))
                pos++;
            var name = s.substring(start, pos).toLowerCase();
            if (name === "pi" || name === "π")
                return Math.PI;
            if (name === "e")
                return Math.E;
            if (funcs[name] && peek() === "(") {
                pos++;
                var arg = expression();
                if (peek() !== ")")
                    throw "missing )";
                pos++;
                return funcs[name](arg);
            }
            throw "unknown identifier";
        }
        throw "unexpected";
    }
    function postfix() {
        var v = primary();
        while (peek() === "!" || peek() === "%") {
            if (peek() === "!") {
                pos++;
                if (v < 0 || v > 170 || Math.floor(v) !== v)
                    throw "bad factorial";
                var r = 1;
                for (var i = 2; i <= v; i++)
                    r *= i;
                v = r;
            } else {
                // percent only when followed by end/operator, otherwise it's modulo
                var nxt = s.charAt(pos + 1);
                if (nxt === "" || /[+\-*\/)^]/.test(nxt)) {
                    pos++;
                    v = v / 100;
                } else
                    break;
            }
        }
        return v;
    }
    function power() {
        var base = postfix();
        if (peek() === "^") {
            pos++;
            return Math.pow(base, power());
        }
        return base;
    }
    function term() {
        var v = power();
        while (true) {
            var c = peek();
            if (c === "*") {
                pos++;
                v *= power();
            } else if (c === "/") {
                pos++;
                v /= power();
            } else if (c === "%") {
                pos++;
                v %= power();
            } else if (c === "(" || /[a-zπ]/i.test(c)) {
                v *= power(); // implicit multiplication: 2(3+4), 2pi
            } else
                break;
        }
        return v;
    }
    function expression() {
        var v = term();
        while (true) {
            var c = peek();
            if (c === "+") {
                pos++;
                v += term();
            } else if (c === "-") {
                pos++;
                v -= term();
            } else
                break;
        }
        return v;
    }
    try {
        var result = expression();
        if (pos !== s.length || !isFinite(result))
            return null;
        return result;
    } catch (e) {
        return null;
    }
}

function looksLikeMath(s) {
    var t = String(s).trim();
    return t.length > 0 && /[0-9]/.test(t) && /^[0-9+\-*\/%^().,\s!a-zπ×÷]+$/i.test(t) && /[+\-*\/%^!(]|sqrt|sin|cos|tan|log|ln|pi/i.test(t);
}

function formatNumber(v) {
    if (v === null || v === undefined)
        return "";
    if (Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-6 && v !== 0))
        return v.toExponential(6).replace(/\.?0+e/, "e");
    var r = Math.round(v * 1e10) / 1e10;
    return String(r);
}

// Escape text for QML StyledText
function escapeHtml(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Shell-quote a single argument for sh -c
function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

function basename(p) {
    var s = String(p || "");
    var i = s.lastIndexOf("/");
    return i >= 0 ? s.slice(i + 1) : s;
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

// Sunrise/sunset (NOAA approximation). Returns {sunrise: Date, sunset: Date} for the given day.
function sunTimes(date, lat, lon) {
    var rad = Math.PI / 180;
    var start = new Date(date.getFullYear(), 0, 0);
    var dayOfYear = Math.floor((date - start) / 86400000);
    var gamma = 2 * Math.PI / 365 * (dayOfYear - 1);
    var eqtime = 229.18 * (0.000075 + 0.001868 * Math.cos(gamma) - 0.032077 * Math.sin(gamma) - 0.014615 * Math.cos(2 * gamma) - 0.040849 * Math.sin(2 * gamma));
    var decl = 0.006918 - 0.399912 * Math.cos(gamma) + 0.070257 * Math.sin(gamma) - 0.006758 * Math.cos(2 * gamma) + 0.000907 * Math.sin(2 * gamma) - 0.002697 * Math.cos(3 * gamma) + 0.00148 * Math.sin(3 * gamma);
    var cosH = (Math.cos(90.833 * rad) / (Math.cos(lat * rad) * Math.cos(decl))) - Math.tan(lat * rad) * Math.tan(decl);
    if (cosH > 1 || cosH < -1)
        return null; // polar day/night
    var ha = Math.acos(cosH) / rad;
    var sunriseMin = 720 - 4 * (lon + ha) - eqtime; // minutes UTC
    var sunsetMin = 720 - 4 * (lon - ha) - eqtime;
    var utcMidnight = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
    return {
        sunrise: new Date(utcMidnight + sunriseMin * 60000),
        sunset: new Date(utcMidnight + sunsetMin * 60000)
    };
}

// Parse "HH:MM" -> minutes since midnight
function parseHm(s, fallback) {
    var m = /^(\d{1,2}):(\d{2})$/.exec(String(s || "").trim());
    if (!m)
        return fallback;
    return parseInt(m[1], 10) * 60 + parseInt(m[2], 10);
}
