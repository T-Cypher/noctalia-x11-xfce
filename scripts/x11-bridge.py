#!/usr/bin/env python3
"""noctalia-x11 bridge - X11/EWMH backend for the Quickshell config.

Replaces the Wayland-only pieces of noctalia (ext-workspace, foreign toplevels, compositor
keyboard layout IPC, ext-idle-notify) on X11 window managers such as xfwm4.

Pure Python 3 + ctypes against libX11 (and optionally libXss); no third-party modules.

Protocol
  stdout: one JSON object per line
     {"type":"state", desktops, current, active, windows, showingDesktop}
     {"type":"keyboard", layouts, names, group, caps, num, scroll}
     {"type":"idle", "seconds": N}
     {"type":"pointer", "x": X, "y": Y}
     {"type":"compositor", "active": bool}
     {"type":"ready"} / {"type":"error", "message": "..."}
  stdin: one command per line
     desktop N | desktop-rel +1|-1 | activate WID | close WID | minimize WID | toggle WID
     maximize WID | fullscreen WID | move WID N | focus-title TITLE | show-desktop [0|1]
     layout-next | layout-prev | layout-set N | idle on|off | pointer | refresh | quit
"""

import ctypes
import ctypes.util
import json
import os
import select
import sys
import time

# --------------------------------------------------------------------------- libX11 setup

_x11_path = ctypes.util.find_library("X11") or "libX11.so.6"
try:
    X = ctypes.cdll.LoadLibrary(_x11_path)
except OSError as exc:  # pragma: no cover
    sys.stdout.write(json.dumps({"type": "error", "message": "cannot load libX11: %s" % exc}) + "\n")
    sys.stdout.flush()
    sys.exit(1)

c_int, c_uint, c_long, c_ulong = ctypes.c_int, ctypes.c_uint, ctypes.c_long, ctypes.c_ulong
c_void_p, c_char_p, c_short, c_ushort, c_ubyte = ctypes.c_void_p, ctypes.c_char_p, ctypes.c_short, ctypes.c_ushort, ctypes.c_ubyte
byref, POINTER = ctypes.byref, ctypes.POINTER


class XAnyEvent(ctypes.Structure):
    _fields_ = [("type", c_int), ("serial", c_ulong), ("send_event", c_int), ("display", c_void_p), ("window", c_ulong)]


class XPropertyEvent(ctypes.Structure):
    _fields_ = [("type", c_int), ("serial", c_ulong), ("send_event", c_int), ("display", c_void_p),
                ("window", c_ulong), ("atom", c_ulong), ("time", c_ulong), ("state", c_int)]


class XConfigureEvent(ctypes.Structure):
    _fields_ = [("type", c_int), ("serial", c_ulong), ("send_event", c_int), ("display", c_void_p),
                ("event", c_ulong), ("window", c_ulong), ("x", c_int), ("y", c_int), ("width", c_int),
                ("height", c_int), ("border_width", c_int), ("above", c_ulong), ("override_redirect", c_int)]


class XDestroyWindowEvent(ctypes.Structure):
    _fields_ = [("type", c_int), ("serial", c_ulong), ("send_event", c_int), ("display", c_void_p),
                ("event", c_ulong), ("window", c_ulong)]


class ClientMessageData(ctypes.Union):
    _fields_ = [("b", ctypes.c_char * 20), ("s", c_short * 10), ("l", c_long * 5)]


class XClientMessageEvent(ctypes.Structure):
    _fields_ = [("type", c_int), ("serial", c_ulong), ("send_event", c_int), ("display", c_void_p),
                ("window", c_ulong), ("message_type", c_ulong), ("format", c_int), ("data", ClientMessageData)]


class XEvent(ctypes.Union):
    _fields_ = [("type", c_int), ("xany", XAnyEvent), ("xproperty", XPropertyEvent),
                ("xconfigure", XConfigureEvent), ("xdestroywindow", XDestroyWindowEvent),
                ("xclient", XClientMessageEvent), ("pad", c_long * 24)]


class XkbStateRec(ctypes.Structure):
    _fields_ = [("group", c_ubyte), ("locked_group", c_ubyte), ("base_group", c_ushort),
                ("latched_group", c_ushort), ("mods", c_ubyte), ("base_mods", c_ubyte),
                ("latched_mods", c_ubyte), ("locked_mods", c_ubyte), ("compat_state", c_ubyte),
                ("grab_mods", c_ubyte), ("compat_grab_mods", c_ubyte), ("lookup_mods", c_ubyte),
                ("compat_lookup_mods", c_ubyte), ("ptr_buttons", c_ushort)]


class XScreenSaverInfo(ctypes.Structure):
    _fields_ = [("window", c_ulong), ("state", c_int), ("kind", c_int), ("til_or_since", c_ulong),
                ("idle", c_ulong), ("eventMask", c_ulong)]


def _sig(fn, restype, *argtypes):
    f = getattr(X, fn)
    f.restype = restype
    f.argtypes = list(argtypes)
    return f


XOpenDisplay = _sig("XOpenDisplay", c_void_p, c_char_p)
XDefaultRootWindow = _sig("XDefaultRootWindow", c_ulong, c_void_p)
XDefaultScreen = _sig("XDefaultScreen", c_int, c_void_p)
XInternAtom = _sig("XInternAtom", c_ulong, c_void_p, c_char_p, c_int)
XGetAtomName = _sig("XGetAtomName", c_void_p, c_void_p, c_ulong)
XSelectInput = _sig("XSelectInput", c_int, c_void_p, c_ulong, c_long)
XGetWindowProperty = _sig("XGetWindowProperty", c_int, c_void_p, c_ulong, c_ulong, c_long, c_long, c_int,
                          c_ulong, POINTER(c_ulong), POINTER(c_int), POINTER(c_ulong), POINTER(c_ulong),
                          POINTER(c_void_p))
XFree = _sig("XFree", c_int, c_void_p)
XPending = _sig("XPending", c_int, c_void_p)
XNextEvent = _sig("XNextEvent", c_int, c_void_p, POINTER(XEvent))
XConnectionNumber = _sig("XConnectionNumber", c_int, c_void_p)
XSendEvent = _sig("XSendEvent", c_int, c_void_p, c_ulong, c_int, c_long, POINTER(XEvent))
XFlush = _sig("XFlush", c_int, c_void_p)
XSync = _sig("XSync", c_int, c_void_p, c_int)
XGetGeometry = _sig("XGetGeometry", c_int, c_void_p, c_ulong, POINTER(c_ulong), POINTER(c_int), POINTER(c_int),
                    POINTER(c_uint), POINTER(c_uint), POINTER(c_uint), POINTER(c_uint))
XTranslateCoordinates = _sig("XTranslateCoordinates", c_int, c_void_p, c_ulong, c_ulong, c_int, c_int,
                             POINTER(c_int), POINTER(c_int), POINTER(c_ulong))
XQueryTree = _sig("XQueryTree", c_int, c_void_p, c_ulong, POINTER(c_ulong), POINTER(c_ulong),
                  POINTER(c_void_p), POINTER(c_uint))
XQueryPointer = _sig("XQueryPointer", c_int, c_void_p, c_ulong, POINTER(c_ulong), POINTER(c_ulong),
                     POINTER(c_int), POINTER(c_int), POINTER(c_int), POINTER(c_int), POINTER(c_uint))
XIconifyWindow = _sig("XIconifyWindow", c_int, c_void_p, c_ulong, c_int)
XGetSelectionOwner = _sig("XGetSelectionOwner", c_ulong, c_void_p, c_ulong)
XkbQueryExtension = _sig("XkbQueryExtension", c_int, c_void_p, POINTER(c_int), POINTER(c_int), POINTER(c_int),
                         POINTER(c_int), POINTER(c_int))
XkbSelectEventDetails = _sig("XkbSelectEventDetails", c_int, c_void_p, c_uint, c_uint, c_ulong, c_ulong)
XkbGetState = _sig("XkbGetState", c_int, c_void_p, c_uint, POINTER(XkbStateRec))
XkbLockGroup = _sig("XkbLockGroup", c_int, c_void_p, c_uint, c_uint)
XkbGetNamedIndicator = _sig("XkbGetNamedIndicator", c_int, c_void_p, c_ulong, POINTER(c_int), POINTER(c_int),
                            c_void_p, POINTER(c_int))

XErrorHandler = ctypes.CFUNCTYPE(c_int, c_void_p, c_void_p)
XSetErrorHandler = _sig("XSetErrorHandler", c_void_p, XErrorHandler)

# Optional XScreenSaver extension for idle time
XSS = None
try:
    _xss_path = ctypes.util.find_library("Xss") or "libXss.so.1"
    XSS = ctypes.cdll.LoadLibrary(_xss_path)
    XSS.XScreenSaverQueryExtension.restype = c_int
    XSS.XScreenSaverQueryExtension.argtypes = [c_void_p, POINTER(c_int), POINTER(c_int)]
    XSS.XScreenSaverQueryInfo.restype = c_int
    XSS.XScreenSaverQueryInfo.argtypes = [c_void_p, c_ulong, POINTER(XScreenSaverInfo)]
except OSError:
    XSS = None

# Constants
PropertyNotify, ConfigureNotify, DestroyNotify, ClientMessage = 28, 22, 17, 33
PropertyChangeMask = 1 << 22
StructureNotifyMask = 1 << 17
SubstructureNotifyMask = 1 << 19
SubstructureRedirectMask = 1 << 20
AnyPropertyType = 0
XA_ATOM, XA_CARDINAL, XA_STRING, XA_WINDOW, XA_WM_HINTS, XA_WM_NAME, XA_WM_CLASS = 4, 6, 31, 33, 35, 39, 67
XkbUseCoreKbd = 0x0100
XkbStateNotify, XkbIndicatorStateNotify = 2, 4
XkbGroupStateMask = 1 << 4
UrgencyHint = 1 << 8
SOURCE_PAGER = 2


def _ignore_errors(_display, _event):
    return 0


_error_handler = XErrorHandler(_ignore_errors)  # keep a reference alive


def emit(obj):
    data = (json.dumps(obj, ensure_ascii=True, separators=(",", ":")) + "\n").encode("ascii")
    try:
        os.write(1, data)
    except BrokenPipeError:
        sys.exit(0)


# --------------------------------------------------------------------------- the bridge

class Bridge:
    def __init__(self):
        self.dpy = XOpenDisplay(None)
        if not self.dpy:
            emit({"type": "error", "message": "cannot open display %r" % os.environ.get("DISPLAY")})
            sys.exit(1)
        XSetErrorHandler(_error_handler)
        self.root = XDefaultRootWindow(self.dpy)
        self.screen = XDefaultScreen(self.dpy)
        self.parent_pid = os.getppid()
        self._atoms = {}
        self.clients = {}          # wid -> info dict
        self.client_order = []     # mapping order from _NET_CLIENT_LIST
        self.geometry_dirty = set()
        self.desktops = 1
        self.current = 0
        self.names = []
        self.active = 0
        self.showing_desktop = False
        self.dirty = True
        self.last_state = None
        self.last_emit = 0.0
        self.keyboard = None
        self.layout_names_cache = None
        self.idle_enabled = False
        self.last_idle = -1
        self.next_idle_poll = 0.0
        self.xss_ok = False
        self.composited = None
        self.next_cm_check = 0.0

        self.a = self.atom
        XSelectInput(self.dpy, self.root, PropertyChangeMask | SubstructureNotifyMask)

        # XKB
        self.xkb_event_base = None
        opcode, ev, err, major, minor = c_int(), c_int(), c_int(), c_int(1), c_int(0)
        if XkbQueryExtension(self.dpy, byref(opcode), byref(ev), byref(err), byref(major), byref(minor)):
            self.xkb_event_base = ev.value
            XkbSelectEventDetails(self.dpy, XkbUseCoreKbd, XkbStateNotify, XkbGroupStateMask, XkbGroupStateMask)
            XkbSelectEventDetails(self.dpy, XkbUseCoreKbd, XkbIndicatorStateNotify, 0xFFFFFFFF, 0xFFFFFFFF)

        if XSS is not None:
            e, r = c_int(), c_int()
            try:
                self.xss_ok = bool(XSS.XScreenSaverQueryExtension(self.dpy, byref(e), byref(r)))
            except Exception:
                self.xss_ok = False

        self.refresh_root()
        self.refresh_keyboard(force=True)

    # ---------------------------------------------------------------- atoms & properties
    def atom(self, name):
        a = self._atoms.get(name)
        if a is None:
            a = XInternAtom(self.dpy, name.encode(), 0)
            self._atoms[name] = a
        return a

    def atom_name(self, atom):
        if not atom:
            return ""
        p = XGetAtomName(self.dpy, atom)
        if not p:
            return ""
        try:
            return ctypes.string_at(p).decode("utf-8", "replace")
        finally:
            XFree(p)

    def get_prop(self, win, prop, req_type=AnyPropertyType, max_len=65536):
        actual_type, actual_format = c_ulong(), c_int()
        nitems, bytes_after, data = c_ulong(), c_ulong(), c_void_p()
        status = XGetWindowProperty(self.dpy, win, prop, 0, max_len, 0, req_type, byref(actual_type),
                                    byref(actual_format), byref(nitems), byref(bytes_after), byref(data))
        if status != 0 or not data.value:
            return None
        try:
            fmt, n = actual_format.value, nitems.value
            if fmt == 8:
                return ctypes.string_at(data.value, n)
            if fmt == 16:
                return list((c_short * n).from_address(data.value))
            if fmt == 32:
                return list((c_ulong * n).from_address(data.value))
            return None
        finally:
            XFree(data)

    def get_card(self, win, name, default=None):
        v = self.get_prop(win, self.a(name))
        if isinstance(v, list) and v:
            return v[0]
        return default

    def get_text(self, win, name, fallback=None):
        v = self.get_prop(win, self.a(name))
        if isinstance(v, (bytes, bytearray)) and v:
            return v.decode("utf-8", "replace").rstrip("\x00")
        if fallback is not None:
            v = self.get_prop(win, fallback)
            if isinstance(v, (bytes, bytearray)) and v:
                try:
                    return v.decode("utf-8").rstrip("\x00")
                except UnicodeDecodeError:
                    return v.decode("latin-1", "replace").rstrip("\x00")
        return ""

    def get_atoms(self, win, name):
        v = self.get_prop(win, self.a(name))
        if not isinstance(v, list):
            return []
        return [self.atom_name(x) for x in v]

    # ---------------------------------------------------------------- root state
    def refresh_root(self):
        self.desktops = int(self.get_card(self.root, "_NET_NUMBER_OF_DESKTOPS", 1) or 1)
        self.current = int(self.get_card(self.root, "_NET_CURRENT_DESKTOP", 0) or 0)
        raw = self.get_prop(self.root, self.a("_NET_DESKTOP_NAMES"))
        if isinstance(raw, (bytes, bytearray)):
            self.names = raw.decode("utf-8", "replace").split("\x00")
        else:
            self.names = []
        self.active = int(self.get_card(self.root, "_NET_ACTIVE_WINDOW", 0) or 0)
        self.showing_desktop = bool(self.get_card(self.root, "_NET_SHOWING_DESKTOP", 0))
        self.refresh_client_list()
        self.dirty = True

    def refresh_client_list(self):
        lst = self.get_prop(self.root, self.a("_NET_CLIENT_LIST"))
        wids = [int(w) for w in lst] if isinstance(lst, list) else []
        seen = set(wids)
        for wid in list(self.clients.keys()):
            if wid not in seen:
                del self.clients[wid]
        for wid in wids:
            if wid not in self.clients:
                XSelectInput(self.dpy, wid, PropertyChangeMask | StructureNotifyMask)
                info = {"id": wid}
                self.clients[wid] = info
                self.refresh_client(wid, full=True)
        self.client_order = wids
        self.dirty = True

    SKIP_TYPES = {"_NET_WM_WINDOW_TYPE_DOCK", "_NET_WM_WINDOW_TYPE_DESKTOP", "_NET_WM_WINDOW_TYPE_SPLASH",
                  "_NET_WM_WINDOW_TYPE_MENU", "_NET_WM_WINDOW_TYPE_DROPDOWN_MENU", "_NET_WM_WINDOW_TYPE_POPUP_MENU",
                  "_NET_WM_WINDOW_TYPE_TOOLTIP", "_NET_WM_WINDOW_TYPE_NOTIFICATION", "_NET_WM_WINDOW_TYPE_COMBO",
                  "_NET_WM_WINDOW_TYPE_DND"}

    def refresh_client(self, wid, full=False, atom=None):
        info = self.clients.get(wid)
        if info is None:
            return
        name = self.atom_name(atom) if atom else None
        if full or name in ("_NET_WM_NAME", "WM_NAME"):
            info["title"] = self.get_text(wid, "_NET_WM_NAME", XA_WM_NAME)
        if full or name == "WM_CLASS":
            raw = self.get_prop(wid, XA_WM_CLASS)
            parts = raw.decode("utf-8", "replace").split("\x00") if isinstance(raw, (bytes, bytearray)) else []
            info["instance"] = parts[0] if len(parts) > 0 else ""
            info["class"] = parts[1] if len(parts) > 1 else info["instance"]
        if full or name == "_NET_WM_DESKTOP":
            d = self.get_card(wid, "_NET_WM_DESKTOP", 0)
            info["desktop"] = -1 if d is None or d >= 0xFFFFFFFF else int(d)
        if full or name == "_NET_WM_STATE":
            states = set(self.get_atoms(wid, "_NET_WM_STATE"))
            info["minimized"] = "_NET_WM_STATE_HIDDEN" in states
            info["fullscreen"] = "_NET_WM_STATE_FULLSCREEN" in states
            info["maximized"] = "_NET_WM_STATE_MAXIMIZED_VERT" in states and "_NET_WM_STATE_MAXIMIZED_HORZ" in states
            info["skipTaskbar"] = "_NET_WM_STATE_SKIP_TASKBAR" in states
            info["demandsAttention"] = "_NET_WM_STATE_DEMANDS_ATTENTION" in states
            info["above"] = "_NET_WM_STATE_ABOVE" in states
        if full or name == "WM_HINTS":
            hints = self.get_prop(wid, XA_WM_HINTS)
            info["urgentHint"] = bool(isinstance(hints, list) and hints and (hints[0] & UrgencyHint))
        if full or name == "_NET_WM_WINDOW_TYPE":
            types = self.get_atoms(wid, "_NET_WM_WINDOW_TYPE")
            info["type"] = types[0].replace("_NET_WM_WINDOW_TYPE_", "").lower() if types else "normal"
            info["skip"] = any(t in self.SKIP_TYPES for t in types)
        if full:
            info["pid"] = int(self.get_card(wid, "_NET_WM_PID", 0) or 0)
            self.geometry_dirty.add(wid)
        self.dirty = True

    def refresh_geometry(self, wid):
        info = self.clients.get(wid)
        if info is None:
            return
        root, x, y = c_ulong(), c_int(), c_int()
        w, h, bw, depth = c_uint(), c_uint(), c_uint(), c_uint()
        if not XGetGeometry(self.dpy, wid, byref(root), byref(x), byref(y), byref(w), byref(h), byref(bw), byref(depth)):
            return
        rx, ry, child = c_int(), c_int(), c_ulong()
        if XTranslateCoordinates(self.dpy, wid, self.root, 0, 0, byref(rx), byref(ry), byref(child)):
            info["x"], info["y"] = rx.value, ry.value
        info["w"], info["h"] = w.value, h.value
        self.dirty = True

    def state(self):
        windows = []
        for wid in self.client_order:
            info = self.clients.get(wid)
            if not info or info.get("skip"):
                continue
            if info.get("pid") == self.parent_pid and info.get("type") == "dock":
                continue
            windows.append({
                "id": "0x%x" % wid,
                "title": info.get("title", ""),
                "appId": info.get("class", ""),
                "instance": info.get("instance", ""),
                "desktop": info.get("desktop", 0),
                "pid": info.get("pid", 0),
                "x": info.get("x", 0), "y": info.get("y", 0), "w": info.get("w", 0), "h": info.get("h", 0),
                "minimized": info.get("minimized", False),
                "fullscreen": info.get("fullscreen", False),
                "maximized": info.get("maximized", False),
                "skipTaskbar": info.get("skipTaskbar", False),
                "urgent": bool(info.get("urgentHint") or info.get("demandsAttention")),
                "type": info.get("type", "normal"),
            })
        names = []
        for i in range(self.desktops):
            n = self.names[i] if i < len(self.names) and self.names[i] else ""
            names.append(n)
        return {
            "type": "state",
            "desktops": self.desktops,
            "names": names,
            "current": self.current,
            "active": "0x%x" % self.active if self.active else "",
            "showingDesktop": self.showing_desktop,
            "windows": windows,
        }

    # ---------------------------------------------------------------- keyboard
    def layout_descriptions(self):
        if self.layout_names_cache is not None:
            return self.layout_names_cache
        layouts, variants = {}, {}
        for path in ("/usr/share/X11/xkb/rules/evdev.lst", "/usr/share/X11/xkb/rules/base.lst"):
            try:
                with open(path, encoding="utf-8", errors="replace") as fh:
                    section = None
                    for line in fh:
                        line = line.rstrip("\n")
                        if line.startswith("!"):
                            section = line[1:].strip()
                            continue
                        if not line.strip():
                            continue
                        parts = line.strip().split(None, 1)
                        if len(parts) < 2:
                            continue
                        if section == "layout":
                            layouts.setdefault(parts[0], parts[1].strip())
                        elif section == "variant":
                            desc = parts[1].strip()
                            if ":" in desc:
                                lay, d = desc.split(":", 1)
                                variants.setdefault((lay.strip(), parts[0]), d.strip())
                break
            except OSError:
                continue
        self.layout_names_cache = (layouts, variants)
        return self.layout_names_cache

    def refresh_keyboard(self, force=False):
        raw = self.get_prop(self.root, self.a("_XKB_RULES_NAMES"))
        layouts, variants = [], []
        if isinstance(raw, (bytes, bytearray)):
            fields = raw.decode("utf-8", "replace").split("\x00")
            if len(fields) >= 3:
                layouts = [l.strip() for l in fields[2].split(",")] if fields[2] else []
            if len(fields) >= 4:
                variants = [v.strip() for v in fields[3].split(",")]
        if not layouts:
            layouts = ["us"]
        st = XkbStateRec()
        group = 0
        if self.xkb_event_base is not None and XkbGetState(self.dpy, XkbUseCoreKbd, byref(st)) == 0:
            group = int(st.group)
        descs, vdescs = self.layout_descriptions()
        names = []
        for i, lay in enumerate(layouts):
            var = variants[i] if i < len(variants) else ""
            if var and (lay, var) in vdescs:
                names.append(vdescs[(lay, var)])
            else:
                names.append(descs.get(lay, lay.upper()))
        locks = {}
        for key, ind in (("caps", "Caps Lock"), ("num", "Num Lock"), ("scroll", "Scroll Lock")):
            ndx, state, real = c_int(), c_int(), c_int()
            ok = self.xkb_event_base is not None and XkbGetNamedIndicator(
                self.dpy, self.a(ind), byref(ndx), byref(state), None, byref(real))
            locks[key] = bool(state.value) if ok else False
        kb = {"type": "keyboard", "layouts": layouts, "variants": variants, "names": names,
              "group": group, "caps": locks["caps"], "num": locks["num"], "scroll": locks["scroll"]}
        if force or kb != self.keyboard:
            self.keyboard = kb
            emit(kb)

    # ---------------------------------------------------------------- commands
    def send_client_message(self, win, msg_type, data, target=None):
        ev = XEvent()
        ev.xclient.type = ClientMessage
        ev.xclient.serial = 0
        ev.xclient.send_event = 1
        ev.xclient.display = self.dpy
        ev.xclient.window = win
        ev.xclient.message_type = self.a(msg_type)
        ev.xclient.format = 32
        for i in range(5):
            ev.xclient.data.l[i] = data[i] if i < len(data) else 0
        XSendEvent(self.dpy, target or self.root, 0, SubstructureRedirectMask | SubstructureNotifyMask, byref(ev))
        XFlush(self.dpy)

    def find_by_title(self, title, win=None, depth=0):
        win = win or self.root
        if depth > 3:
            return 0
        root_ret, parent_ret, children, n = c_ulong(), c_ulong(), c_void_p(), c_uint()
        if not XQueryTree(self.dpy, win, byref(root_ret), byref(parent_ret), byref(children), byref(n)):
            return 0
        found = 0
        try:
            if children.value and n.value:
                arr = (c_ulong * n.value).from_address(children.value)
                # topmost first
                for child in reversed(list(arr)):
                    if self.get_text(child, "_NET_WM_NAME", XA_WM_NAME) == title:
                        found = child
                        break
                if not found:
                    for child in reversed(list(arr)):
                        found = self.find_by_title(title, child, depth + 1)
                        if found:
                            break
        finally:
            if children.value:
                XFree(children)
        return found

    def handle_command(self, line):
        parts = line.strip().split(" ", 1)
        if not parts or not parts[0]:
            return
        cmd = parts[0]
        arg = parts[1].strip() if len(parts) > 1 else ""

        def wid():
            try:
                return int(arg.split()[0], 0)
            except (ValueError, IndexError):
                return 0

        if cmd == "desktop":
            try:
                n = max(0, min(self.desktops - 1, int(arg)))
            except ValueError:
                return
            self.send_client_message(self.root, "_NET_CURRENT_DESKTOP", [n, 0])
        elif cmd == "desktop-rel":
            try:
                delta = int(arg or "1")
            except ValueError:
                delta = 1
            n = (self.current + delta) % max(1, self.desktops)
            self.send_client_message(self.root, "_NET_CURRENT_DESKTOP", [n, 0])
        elif cmd == "activate":
            w = wid()
            if w:
                self.send_client_message(w, "_NET_ACTIVE_WINDOW", [SOURCE_PAGER, 0, 0])
        elif cmd == "close":
            w = wid()
            if w:
                self.send_client_message(w, "_NET_CLOSE_WINDOW", [0, SOURCE_PAGER])
        elif cmd == "minimize":
            w = wid()
            if w:
                XIconifyWindow(self.dpy, w, self.screen)
                XFlush(self.dpy)
        elif cmd == "toggle":
            w = wid()
            info = self.clients.get(w)
            if w and info is not None and w == self.active and not info.get("minimized"):
                XIconifyWindow(self.dpy, w, self.screen)
                XFlush(self.dpy)
            elif w:
                self.send_client_message(w, "_NET_ACTIVE_WINDOW", [SOURCE_PAGER, 0, 0])
        elif cmd in ("maximize", "fullscreen"):
            w = wid()
            if w:
                if cmd == "maximize":
                    a1, a2 = self.a("_NET_WM_STATE_MAXIMIZED_VERT"), self.a("_NET_WM_STATE_MAXIMIZED_HORZ")
                else:
                    a1, a2 = self.a("_NET_WM_STATE_FULLSCREEN"), 0
                self.send_client_message(w, "_NET_WM_STATE", [2, a1, a2, SOURCE_PAGER])
        elif cmd == "move":
            bits = arg.split()
            if len(bits) == 2:
                try:
                    self.send_client_message(int(bits[0], 0), "_NET_WM_DESKTOP", [int(bits[1]), SOURCE_PAGER])
                except ValueError:
                    pass
        elif cmd == "focus-title":
            w = self.find_by_title(arg)
            if w:
                self.send_client_message(w, "_NET_ACTIVE_WINDOW", [SOURCE_PAGER, 0, 0])
        elif cmd == "show-desktop":
            want = (not self.showing_desktop) if arg == "" else arg in ("1", "true", "on")
            self.send_client_message(self.root, "_NET_SHOWING_DESKTOP", [1 if want else 0])
        elif cmd in ("layout-next", "layout-prev", "layout-set"):
            if self.xkb_event_base is None or not self.keyboard:
                return
            count = max(1, len(self.keyboard["layouts"]))
            g = self.keyboard["group"]
            if cmd == "layout-next":
                g = (g + 1) % count
            elif cmd == "layout-prev":
                g = (g - 1) % count
            else:
                try:
                    g = max(0, min(count - 1, int(arg)))
                except ValueError:
                    return
            XkbLockGroup(self.dpy, XkbUseCoreKbd, g)
            XFlush(self.dpy)
        elif cmd == "idle":
            self.idle_enabled = arg in ("on", "1", "true")
            self.last_idle = -1
        elif cmd == "pointer":
            r, c = c_ulong(), c_ulong()
            rx, ry, wx, wy, mask = c_int(), c_int(), c_int(), c_int(), c_uint()
            if XQueryPointer(self.dpy, self.root, byref(r), byref(c), byref(rx), byref(ry), byref(wx), byref(wy), byref(mask)):
                emit({"type": "pointer", "x": rx.value, "y": ry.value, "tag": arg})
            else:
                emit({"type": "pointer", "x": -1, "y": -1, "tag": arg})
        elif cmd == "refresh":
            self.refresh_root()
            self.refresh_keyboard(force=True)
            self.last_state = None
        elif cmd == "quit":
            sys.exit(0)

    # ---------------------------------------------------------------- event loop
    def handle_event(self, ev):
        t = ev.type
        if t == PropertyNotify:
            pe = ev.xproperty
            if pe.window == self.root:
                name = self.atom_name(pe.atom)
                if name == "_NET_CLIENT_LIST":
                    self.refresh_client_list()
                elif name in ("_NET_CURRENT_DESKTOP", "_NET_NUMBER_OF_DESKTOPS", "_NET_DESKTOP_NAMES",
                              "_NET_ACTIVE_WINDOW", "_NET_SHOWING_DESKTOP"):
                    self.refresh_root()
                elif name == "_XKB_RULES_NAMES":
                    self.refresh_keyboard()
            elif pe.window in self.clients:
                self.refresh_client(pe.window, atom=pe.atom)
        elif t == ConfigureNotify:
            w = ev.xconfigure.window
            if w in self.clients:
                self.geometry_dirty.add(w)
        elif t == DestroyNotify:
            w = ev.xdestroywindow.window
            if w in self.clients:
                del self.clients[w]
                self.dirty = True
        elif self.xkb_event_base is not None and t == self.xkb_event_base:
            self.refresh_keyboard()

    def flush_state(self, now):
        if self.geometry_dirty:
            for w in list(self.geometry_dirty):
                self.refresh_geometry(w)
            self.geometry_dirty.clear()
        if not self.dirty:
            return
        if now - self.last_emit < 0.04:
            return
        st = self.state()
        if st != self.last_state:
            emit(st)
            self.last_state = st
        self.last_emit = now
        self.dirty = False

    def check_compositor(self, now):
        if now < self.next_cm_check:
            return
        self.next_cm_check = now + 3.0
        owner = XGetSelectionOwner(self.dpy, self.a("_NET_WM_CM_S%d" % self.screen))
        active = bool(owner)
        if active != self.composited:
            self.composited = active
            emit({"type": "compositor", "active": active})

    def poll_idle(self, now):
        if not (self.idle_enabled and self.xss_ok) or now < self.next_idle_poll:
            return
        self.next_idle_poll = now + 1.0
        info = XScreenSaverInfo()
        if XSS.XScreenSaverQueryInfo(self.dpy, self.root, byref(info)):
            secs = int(info.idle // 1000)
            if secs != self.last_idle:
                if secs > 0 or self.last_idle > 0 or self.last_idle < 0:
                    emit({"type": "idle", "seconds": secs})
                self.last_idle = secs

    def run(self):
        xfd = XConnectionNumber(self.dpy)
        buf = b""
        emit({"type": "ready", "idleSupported": self.xss_ok, "xkb": self.xkb_event_base is not None})
        ev = XEvent()
        while True:
            while XPending(self.dpy):
                XNextEvent(self.dpy, byref(ev))
                self.handle_event(ev)
            now = time.monotonic()
            self.flush_state(now)
            self.poll_idle(now)
            self.check_compositor(now)
            timeout = 0.05 if (self.dirty or self.geometry_dirty) else (0.5 if self.idle_enabled else 3.0)
            try:
                readable, _, _ = select.select([xfd, 0], [], [], timeout)
            except InterruptedError:
                continue
            if 0 in readable:
                chunk = os.read(0, 4096)
                if not chunk:
                    return  # parent went away
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    try:
                        self.handle_command(line.decode("utf-8", "replace"))
                    except SystemExit:
                        raise
                    except Exception as exc:  # never die on a bad command
                        emit({"type": "error", "message": "command failed: %s" % exc})


def main():
    bridge = Bridge()
    try:
        bridge.run()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
