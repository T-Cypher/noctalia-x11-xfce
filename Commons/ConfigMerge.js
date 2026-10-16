// noctalia v5.3.0 config-stack semantics (src/config/config_merge.cpp, file_utils.h), as pure
// functions so they can be unit-tested outside QML. Config.qml performs the actual I/O.
//
//   * every *.toml directly inside the config directory is a root file, merged in bytewise
//     sorted order;
//   * [include] files = [...] pulls in files or directories (non-recursive *.toml, sorted);
//     ~, $VAR and ${VAR} are expanded and relative paths resolve against the including file;
//     a file's includes merge first and the file's own body overlays them (host wins);
//   * each file loads at most once (cycles / duplicates are skipped with a warning);
//   * [include] autoload = false in a root file restricts loading to the opting roots;
//   * the first parse error or missing include is reported (Config keeps the previous config).
.pragma library
.import "Defaults.js" as Defaults

function isPlainObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// $NAME / ${NAME} expansion; unset variables expand to "" (FileUtils::expandEnvVars).
function expandEnvVars(s, env) {
    var out = "";
    var i = 0;
    while (i < s.length) {
        var c = s.charAt(i);
        if (c !== "$") {
            out += c;
            i++;
            continue;
        }
        if (s.charAt(i + 1) === "{") {
            var close = s.indexOf("}", i + 2);
            if (close >= 0) {
                out += env(s.substring(i + 2, close)) || "";
                i = close + 1;
                continue;
            }
            out += "$";
            i++;
            continue;
        }
        var m = /^[A-Za-z_][A-Za-z0-9_]*/.exec(s.substring(i + 1));
        if (m) {
            out += env(m[0]) || "";
            i += 1 + m[0].length;
            continue;
        }
        out += "$";
        i++;
    }
    return out;
}

function normalizePath(p) {
    var abs = p.charAt(0) === "/";
    var parts = p.split("/");
    var out = [];
    for (var i = 0; i < parts.length; i++) {
        var seg = parts[i];
        if (seg === "" || seg === ".")
            continue;
        if (seg === "..") {
            if (out.length > 0 && out[out.length - 1] !== "..")
                out.pop();
            else if (!abs)
                out.push("..");
            continue;
        }
        out.push(seg);
    }
    return (abs ? "/" : "") + out.join("/");
}

function dirname(p) {
    var i = p.lastIndexOf("/");
    if (i < 0)
        return ".";
    return i === 0 ? "/" : p.substring(0, i);
}

// FileUtils::resolvePath: expand ~, make relative paths absolute against baseDir, normalize.
function resolvePath(p, baseDir, home) {
    var s = String(p);
    if (s === "~")
        s = home;
    else if (s.indexOf("~/") === 0)
        s = home + s.substring(1);
    if (s.charAt(0) !== "/")
        s = (baseDir || ".") + "/" + s;
    return normalizePath(s);
}

function bytewise(a, b) {
    return a < b ? -1 : (a > b ? 1 : 0);
}

// io = {
//   read(path)  -> file text, or null when unreadable,
//   info(path)  -> undefined (not probed yet) | {type: "f"|"d"|"m", canon, children: [{path, canon}]},
//   env(name)   -> environment value or "",
//   home        -> $HOME
// }
// parse(text) -> object (throws on syntax errors)
// roots = [{path, canon}] root files (already sorted)
function mergeAll(roots, io, parse) {
    var out = {
        merged: {},
        loaded: [],        // canonical paths actually merged
        includeDirs: [],   // canonical include directories (watched for new files)
        need: [],          // include targets that still have to be probed
        error: "",         // first parse error / missing include
        errorFile: "",
        errorLine: 0,
        warnings: []
    };
    var parsedCache = {};

    function noteError(file, e) {
        if (out.error !== "")
            return;
        out.error = e && e.message !== undefined ? String(e.message) : String(e);
        out.errorFile = file;
        out.errorLine = e && e.line !== undefined ? Number(e.line) : 0;
    }

    function load(path) {
        if (parsedCache[path] !== undefined)
            return parsedCache[path];
        var text = io.read(path);
        var result = null;
        if (text === null || text === undefined) {
            noteError(path, "cannot read file");
        } else {
            try {
                result = parse(text);
            } catch (e) {
                noteError(path, e);
                result = null;
            }
        }
        parsedCache[path] = result;
        return result;
    }

    function includeDirective(parsed) {
        var inc = parsed && isPlainObject(parsed.include) ? parsed.include : null;
        return {
            files: inc && Array.isArray(inc.files) ? inc.files : [],
            hasAutoload: inc !== null && typeof inc.autoload === "boolean",
            autoload: inc !== null && inc.autoload === false ? false : true
        };
    }

    var visited = {};

    function expandFile(path, canon, parsed) {
        if (visited[canon]) {
            out.warnings.push("config include cycle or duplicate skipped: " + canon);
            return {};
        }
        visited[canon] = true;
        out.loaded.push(canon);
        var directive = includeDirective(parsed);
        var base = {};
        var dir = dirname(path);
        for (var i = 0; i < directive.files.length; i++) {
            var entry = directive.files[i];
            if (typeof entry !== "string")
                continue;
            var target = resolvePath(expandEnvVars(entry, io.env), dir, io.home);
            var inf = io.info(target);
            if (inf === undefined) {
                if (out.need.indexOf(target) < 0)
                    out.need.push(target);
                continue;
            }
            if (inf.type === "d") {
                if (out.includeDirs.indexOf(inf.canon) < 0)
                    out.includeDirs.push(inf.canon);
                var children = inf.children.slice().sort(function (a, b) {
                    return bytewise(a.path, b.path);
                });
                for (var c = 0; c < children.length; c++)
                    Defaults.deepMergeUser(base, loadAndExpand(children[c].path, children[c].canon));
            } else if (inf.type === "f") {
                Defaults.deepMergeUser(base, loadAndExpand(target, inf.canon));
            } else {
                noteError(path, "include not found: " + entry);
                out.warnings.push("config include not found: " + target + " (from " + path + ")");
            }
        }
        var body = {};
        for (var k in parsed)
            if (k !== "include")
                body[k] = parsed[k];
        Defaults.deepMergeUser(base, body);
        return base;
    }

    function loadAndExpand(path, canon) {
        var parsed = load(path);
        if (parsed === null)
            return {};
        return expandFile(path, canon || path, parsed);
    }

    // Phase A: parse every root, noting [include] autoload = false.
    var parsedRoots = [];
    var anyOptOut = false;
    for (var r = 0; r < roots.length; r++) {
        var parsed = load(roots[r].path);
        if (parsed === null)
            continue;
        var d = includeDirective(parsed);
        var optOut = d.hasAutoload && !d.autoload;
        anyOptOut = anyOptOut || optOut;
        parsedRoots.push({
            path: roots[r].path,
            canon: roots[r].canon || roots[r].path,
            parsed: parsed,
            optOut: optOut
        });
    }
    // Phase B: merge the load set.
    for (var p = 0; p < parsedRoots.length; p++) {
        var root = parsedRoots[p];
        if (anyOptOut && !root.optOut)
            continue;
        Defaults.deepMergeUser(out.merged, expandFile(root.path, root.canon, root.parsed));
    }
    return out;
}

// StringUtils::containsWholeToken (whitespace-delimited, case-sensitive).
function containsWholeToken(haystack, needle) {
    var h = String(haystack || ""), n = String(needle || "");
    if (h.length === 0 || n.length === 0)
        return false;
    for (var pos = h.indexOf(n); pos >= 0; pos = h.indexOf(n, pos + 1)) {
        var startOk = pos === 0 || /\s/.test(h.charAt(pos - 1));
        var end = pos + n.length;
        var endOk = end === h.length || /\s/.test(h.charAt(end));
        if (startOk && endOk)
            return true;
    }
    return false;
}

// outputMatchesSelector: exact connector name, or a whole token of the output identity fields.
function outputMatchesSelector(selector, name, manufacturer, model, serial) {
    var s = String(selector || "");
    if (s.length === 0)
        return false;
    if (name && s === name)
        return true;
    var description = [manufacturer || "", model || "", serial || ""].join(" ").replace(/\s+/g, " ").trim();
    var fields = [description, manufacturer || "", model || "", serial || ""];
    for (var i = 0; i < fields.length; i++)
        if (containsWholeToken(fields[i], s))
            return true;
    return false;
}
