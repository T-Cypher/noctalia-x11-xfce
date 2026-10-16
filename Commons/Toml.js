// Minimal TOML 1.0 parser for Noctalia-X11 configuration files.
// Supports: tables, dotted/quoted keys, arrays of tables, inline tables,
// basic/literal/multi-line strings, integers (dec/hex/oct/bin), floats,
// booleans, arrays (multi-line, trailing commas, comments). Date/time
// values are returned as plain strings.
.pragma library

function TomlError(message, line) {
    this.message = message;
    this.line = line;
}
TomlError.prototype.toString = function () {
    return "TOML error (line " + this.line + "): " + this.message;
};

function parse(text) {
    var src = String(text === undefined || text === null ? "" : text);
    if (src.charCodeAt(0) === 0xFEFF)
        src = src.slice(1);
    var pos = 0;
    var line = 1;
    var root = {};
    var current = root;
    // Tables that were explicitly defined with [header] (to detect duplicates loosely)
    var arrayTables = [];

    function fail(msg) {
        throw new TomlError(msg, line);
    }
    function peek(offset) {
        return src.charAt(pos + (offset || 0));
    }
    function startsWith(s) {
        return src.substr(pos, s.length) === s;
    }
    function advance(n) {
        for (var i = 0; i < (n || 1); i++) {
            if (src.charAt(pos) === "\n")
                line++;
            pos++;
        }
    }
    function skipWs() {
        while (pos < src.length) {
            var c = src.charAt(pos);
            if (c === " " || c === "\t")
                pos++;
            else
                break;
        }
    }
    function skipComment() {
        if (peek() === "#") {
            while (pos < src.length && src.charAt(pos) !== "\n")
                pos++;
        }
    }
    function skipWsCommentsNewlines() {
        while (pos < src.length) {
            var c = src.charAt(pos);
            if (c === " " || c === "\t" || c === "\r") {
                pos++;
            } else if (c === "\n") {
                advance();
            } else if (c === "#") {
                skipComment();
            } else {
                break;
            }
        }
    }
    function expectLineEnd() {
        skipWs();
        skipComment();
        if (peek() === "\r")
            pos++;
        if (pos < src.length && peek() !== "\n")
            fail("Expected end of line, found '" + peek() + "'");
    }

    function isBareKeyChar(c) {
        return /[A-Za-z0-9_\-]/.test(c);
    }

    function parseEscape() {
        // assumes current char is after backslash
        var c = peek();
        advance();
        switch (c) {
        case "b": return "\b";
        case "t": return "\t";
        case "n": return "\n";
        case "f": return "\f";
        case "r": return "\r";
        case "e": return "\u001b";
        case "\"": return "\"";
        case "\\": return "\\";
        case "u":
        case "U": {
            var len = c === "u" ? 4 : 8;
            var hex = src.substr(pos, len);
            if (!/^[0-9A-Fa-f]+$/.test(hex) || hex.length !== len)
                fail("Invalid unicode escape");
            advance(len);
            var cp = parseInt(hex, 16);
            return String.fromCodePoint ? String.fromCodePoint(cp) : String.fromCharCode(cp);
        }
        default:
            fail("Invalid escape sequence \\" + c);
        }
        return "";
    }

    function parseBasicString() {
        // at opening quote
        advance();
        var out = "";
        while (true) {
            if (pos >= src.length)
                fail("Unterminated string");
            var c = peek();
            if (c === "\"") {
                advance();
                return out;
            }
            if (c === "\n")
                fail("Newline in basic string");
            if (c === "\\") {
                advance();
                out += parseEscape();
                continue;
            }
            out += c;
            advance();
        }
    }

    function parseMultilineBasicString() {
        advance(3);
        if (peek() === "\r" && peek(1) === "\n")
            advance(2);
        else if (peek() === "\n")
            advance();
        var out = "";
        while (true) {
            if (pos >= src.length)
                fail("Unterminated multi-line string");
            if (startsWith("\"\"\"")) {
                // Allow up to two extra quotes at the end
                var extra = 0;
                while (src.charAt(pos + 3 + extra) === "\"" && extra < 2)
                    extra++;
                out += src.substr(pos, extra);
                advance(3 + extra);
                return out;
            }
            var c = peek();
            if (c === "\\") {
                // line-ending backslash
                var j = pos + 1;
                while (src.charAt(j) === " " || src.charAt(j) === "\t" || src.charAt(j) === "\r")
                    j++;
                if (src.charAt(j) === "\n") {
                    advance(j - pos);
                    while (pos < src.length && /[\s]/.test(peek()))
                        advance();
                    continue;
                }
                advance();
                out += parseEscape();
                continue;
            }
            out += c;
            advance();
        }
    }

    function parseLiteralString() {
        advance();
        var start = pos;
        while (pos < src.length && peek() !== "'") {
            if (peek() === "\n")
                fail("Newline in literal string");
            pos++;
        }
        if (pos >= src.length)
            fail("Unterminated literal string");
        var s = src.substring(start, pos);
        advance();
        return s;
    }

    function parseMultilineLiteralString() {
        advance(3);
        if (peek() === "\r" && peek(1) === "\n")
            advance(2);
        else if (peek() === "\n")
            advance();
        var start = pos;
        while (pos < src.length && !startsWith("'''"))
            advance();
        if (pos >= src.length)
            fail("Unterminated multi-line literal string");
        var extra = 0;
        while (src.charAt(pos + 3 + extra) === "'" && extra < 2)
            extra++;
        var s = src.substring(start, pos + extra);
        advance(3 + extra);
        return s;
    }

    function parseKeySegment() {
        skipWs();
        var c = peek();
        if (c === "\"")
            return parseBasicString();
        if (c === "'")
            return parseLiteralString();
        var start = pos;
        while (pos < src.length && isBareKeyChar(peek()))
            pos++;
        if (start === pos)
            fail("Expected key, found '" + c + "'");
        return src.substring(start, pos);
    }

    function parseKey() {
        var parts = [parseKeySegment()];
        skipWs();
        while (peek() === ".") {
            pos++;
            parts.push(parseKeySegment());
            skipWs();
        }
        return parts;
    }

    function parseNumberOrDate() {
        var start = pos;
        while (pos < src.length && /[0-9A-Za-z_+\-.:]/.test(peek()))
            pos++;
        // Allow a single space in datetimes "1979-05-27 07:32:00"
        var raw = src.substring(start, pos);
        if (/^\d{4}-\d{2}-\d{2}$/.test(raw) && peek() === " " && /\d/.test(peek(1))) {
            pos++;
            while (pos < src.length && /[0-9:.+\-Z]/.test(peek()))
                pos++;
            raw = src.substring(start, pos);
        }
        if (raw === "inf" || raw === "+inf")
            return Infinity;
        if (raw === "-inf")
            return -Infinity;
        if (raw === "nan" || raw === "+nan" || raw === "-nan")
            return NaN;
        if (/^\d{4}-\d{2}-\d{2}/.test(raw) || /^\d{2}:\d{2}/.test(raw))
            return raw; // date/time kept as string
        var clean = raw.replace(/_/g, "");
        if (/^[+\-]?0x[0-9A-Fa-f]+$/.test(clean))
            return parseInt(clean, 16);
        if (/^[+\-]?0o[0-7]+$/.test(clean))
            return parseInt(clean.replace("0o", ""), 8);
        if (/^[+\-]?0b[01]+$/.test(clean))
            return parseInt(clean.replace("0b", ""), 2);
        if (/^[+\-]?\d+$/.test(clean))
            return parseInt(clean, 10);
        if (/^[+\-]?(\d+)(\.\d+)?([eE][+\-]?\d+)?$/.test(clean))
            return parseFloat(clean);
        fail("Invalid value '" + raw + "'");
        return null;
    }

    function parseArray() {
        advance(); // [
        var arr = [];
        while (true) {
            skipWsCommentsNewlines();
            if (peek() === "]") {
                advance();
                return arr;
            }
            arr.push(parseValue());
            skipWsCommentsNewlines();
            if (peek() === ",") {
                advance();
                continue;
            }
            skipWsCommentsNewlines();
            if (peek() === "]") {
                advance();
                return arr;
            }
            fail("Expected ',' or ']' in array");
        }
    }

    function parseInlineTable() {
        advance(); // {
        var tbl = {};
        skipWs();
        if (peek() === "}") {
            advance();
            return tbl;
        }
        while (true) {
            skipWsCommentsNewlines();
            if (peek() === "}") {
                advance();
                return tbl;
            }
            var key = parseKey();
            skipWs();
            if (peek() !== "=")
                fail("Expected '=' in inline table");
            advance();
            skipWs();
            var val = parseValue();
            assignDotted(tbl, key, val);
            skipWsCommentsNewlines();
            if (peek() === ",") {
                advance();
                continue;
            }
            if (peek() === "}") {
                advance();
                return tbl;
            }
            fail("Expected ',' or '}' in inline table");
        }
    }

    function parseValue() {
        skipWs();
        var c = peek();
        if (startsWith("\"\"\""))
            return parseMultilineBasicString();
        if (c === "\"")
            return parseBasicString();
        if (startsWith("'''"))
            return parseMultilineLiteralString();
        if (c === "'")
            return parseLiteralString();
        if (startsWith("true") && !isBareKeyChar(peek(4))) {
            pos += 4;
            return true;
        }
        if (startsWith("false") && !isBareKeyChar(peek(5))) {
            pos += 5;
            return false;
        }
        if (c === "[")
            return parseArray();
        if (c === "{")
            return parseInlineTable();
        return parseNumberOrDate();
    }

    function isPlainObject(v) {
        return v !== null && typeof v === "object" && !Array.isArray(v);
    }

    function assignDotted(target, keyParts, value) {
        var obj = target;
        for (var i = 0; i < keyParts.length - 1; i++) {
            var k = keyParts[i];
            if (obj[k] === undefined)
                obj[k] = {};
            else if (Array.isArray(obj[k]) && obj[k].length > 0 && isPlainObject(obj[k][obj[k].length - 1]))
                obj[k] = obj[k];
            else if (!isPlainObject(obj[k]))
                fail("Key '" + keyParts.join(".") + "' conflicts with an existing value");
            obj = Array.isArray(obj[k]) ? obj[k][obj[k].length - 1] : obj[k];
        }
        var last = keyParts[keyParts.length - 1];
        obj[last] = value;
    }

    function resolveTable(keyParts, isArray) {
        var obj = root;
        for (var i = 0; i < keyParts.length; i++) {
            var k = keyParts[i];
            var isLast = i === keyParts.length - 1;
            if (isLast && isArray) {
                if (obj[k] === undefined)
                    obj[k] = [];
                if (!Array.isArray(obj[k]))
                    fail("Key '" + keyParts.join(".") + "' is not an array of tables");
                var t = {};
                obj[k].push(t);
                return t;
            }
            if (obj[k] === undefined)
                obj[k] = {};
            if (Array.isArray(obj[k])) {
                if (obj[k].length === 0)
                    obj[k].push({});
                obj = obj[k][obj[k].length - 1];
            } else if (isPlainObject(obj[k])) {
                obj = obj[k];
            } else {
                fail("Key '" + keyParts.join(".") + "' is not a table");
            }
        }
        return obj;
    }

    while (pos < src.length) {
        skipWsCommentsNewlines();
        if (pos >= src.length)
            break;
        var c = peek();
        if (c === "[") {
            var isArr = startsWith("[[");
            advance(isArr ? 2 : 1);
            var key = parseKey();
            skipWs();
            if (isArr) {
                if (!startsWith("]]"))
                    fail("Expected ']]'");
                advance(2);
            } else {
                if (peek() !== "]")
                    fail("Expected ']'");
                advance();
            }
            current = resolveTable(key, isArr);
            expectLineEnd();
            continue;
        }
        var k = parseKey();
        skipWs();
        if (peek() !== "=")
            fail("Expected '=' after key '" + k.join(".") + "'");
        advance();
        skipWs();
        var v = parseValue();
        assignDotted(current, k, v);
        expectLineEnd();
    }
    return root;
}

// Serialize a flat-ish JS object back to TOML (used for writing small state/override files).
function stringify(obj) {
    var lines = [];
    function fmtKey(k) {
        return /^[A-Za-z0-9_\-]+$/.test(k) ? k : JSON.stringify(k);
    }
    function fmtValue(v) {
        if (typeof v === "string")
            return JSON.stringify(v);
        if (typeof v === "boolean" || typeof v === "number")
            return String(v);
        if (Array.isArray(v))
            return "[" + v.map(fmtValue).join(", ") + "]";
        if (v && typeof v === "object") {
            var parts = [];
            for (var k in v)
                parts.push(fmtKey(k) + " = " + fmtValue(v[k]));
            return "{ " + parts.join(", ") + " }";
        }
        return "\"\"";
    }
    function walk(o, path) {
        var tables = [];
        var simple = [];
        for (var k in o) {
            var v = o[k];
            if (v && typeof v === "object" && !Array.isArray(v))
                tables.push(k);
            else
                simple.push(k);
        }
        if (path.length > 0 && (simple.length > 0 || tables.length === 0))
            lines.push("[" + path.map(fmtKey).join(".") + "]");
        for (var i = 0; i < simple.length; i++)
            lines.push(fmtKey(simple[i]) + " = " + fmtValue(o[simple[i]]));
        if (simple.length > 0)
            lines.push("");
        for (var j = 0; j < tables.length; j++)
            walk(o[tables[j]], path.concat([tables[j]]));
    }
    walk(obj, []);
    return lines.join("\n") + "\n";
}
