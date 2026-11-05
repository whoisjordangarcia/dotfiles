#!/usr/bin/env python3
import argparse
import base64
import collections
import fcntl
import glob
import json
import os
import re
import select
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time
import tty
import urllib.parse

STATE_DIR = os.path.expanduser("~/.local/state/show-html")
CHROMES = (
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
)
FALLBACK_CELL = (16, 34)
# A pane this wide in CSS pixels gets a page's desktop layout rather than its narrow one.
MIN_CSS_WIDTH = 1080
SIZE_SETTLE = 0.25
DEFAULT_SIZE_WAIT = 1
SIZE_DEADLINE = 3
ESC_TIMEOUT = 0.05
PLACE_TIMEOUT = 1
SETTLE = 0.12
BURST_GAP = 0.1
WHEEL_MOTION = 0.25
# Rex takes about 60 ms to draw a 3.9 MP frame and 20 ms to draw 1 MP, so frames during motion
# are cut to this budget (45 fps against 15 on a 100x78 pane); the sharp frame follows at rest.
MOTION_PIXELS = 1_000_000
RESIZE_DEBOUNCE = 0.03
DOUBLE_CLICK = 0.4
WHEEL_CSS_PX = 40
WRITE_CHUNK = 1 << 16
LAUNCH_TIMEOUT = 30

TOKEN = re.compile(rb"\x1b_G[^\x1b]*\x1b\\|\x1b\[<\d+;\d+;\d+[Mm]|\x1b\[[0-9;:?]*[A-Za-z~]|\x1bO[A-Za-z]")
UNFINISHED = re.compile(rb"\x1b(?:_[^\x1b]*\x1b?|\[[0-9;:<?]*|O)?")

# (key, code, windows virtual key, text, macOS editing command). Without the command a macOS
# Chrome leaves caret keys and page keys to an NSResponder chain headless does not have.
KEYS = {
    "A": ("ArrowUp", "ArrowUp", 38, None, "moveUp"),
    "B": ("ArrowDown", "ArrowDown", 40, None, "moveDown"),
    "C": ("ArrowRight", "ArrowRight", 39, None, "moveRight"),
    "D": ("ArrowLeft", "ArrowLeft", 37, None, "moveLeft"),
    "H": ("Home", "Home", 36, None, "scrollToBeginningOfDocument"),
    "F": ("End", "End", 35, None, "scrollToEndOfDocument"),
    "1~": ("Home", "Home", 36, None, "scrollToBeginningOfDocument"),
    "7~": ("Home", "Home", 36, None, "scrollToBeginningOfDocument"),
    "4~": ("End", "End", 35, None, "scrollToEndOfDocument"),
    "8~": ("End", "End", 35, None, "scrollToEndOfDocument"),
    "5~": ("PageUp", "PageUp", 33, None, "scrollPageUp"),
    "6~": ("PageDown", "PageDown", 34, None, "scrollPageDown"),
    "3~": ("Delete", "Delete", 46, None, "deleteForward"),
    "\r": ("Enter", "Enter", 13, "\r", None),
    "\t": ("Tab", "Tab", 9, None, None),
    "\x7f": ("Backspace", "Backspace", 8, None, "deleteBackward"),
    "\x1b": ("Escape", "Escape", 27, None, None),
}
SHIFT, ALT, CTRL = 8, 1, 2

TEXT_FOCUS = """(() => {
  let e = document.activeElement;
  while (e && e.shadowRoot && e.shadowRoot.activeElement) e = e.shadowRoot.activeElement;
  if (!e) return false;
  if (e.isContentEditable || e.tagName === 'TEXTAREA') return true;
  return e.tagName === 'INPUT' &&
    !['button','checkbox','color','file','image','radio','range','reset','submit'].includes(e.type);
})()"""


class Cdp:
    """One DevTools connection over Chrome's --remote-debugging-pipe, framed by NUL bytes."""

    def __init__(self, read_fd, write_fd, on_event):
        self.read_fd, self.write_fd = read_fd, write_fd
        self.on_event = on_event
        self.buffer = bytearray()
        self.next_id = 0
        self.callbacks = {}

    def send(self, method, params=None, session=None, reply=None):
        self.next_id += 1
        message = {"id": self.next_id, "method": method, "params": params or {}}
        if session:
            message["sessionId"] = session
        if reply:
            self.callbacks[self.next_id] = reply
        payload = json.dumps(message).encode() + b"\0"
        while payload:
            payload = payload[os.write(self.write_fd, payload) :]
        return self.next_id

    def pump(self):
        data = os.read(self.read_fd, 1 << 20)
        if not data:
            raise EOFError("Chrome closed the DevTools pipe")
        start = len(self.buffer)
        self.buffer += data
        begin = 0
        while (end := self.buffer.find(0, max(begin, start))) >= 0:
            message = json.loads(bytes(self.buffer[begin:end]))
            begin = end + 1
            if "id" in message:
                callback = self.callbacks.pop(message["id"], None)
                if callback:
                    callback(message)
            else:
                self.on_event(message)
        del self.buffer[:begin]

    def call(self, method, params=None, session=None, timeout=20):
        """Block until Chrome replies, still dispatching events. Raises TimeoutError or RuntimeError."""
        box = []
        self.send(method, params, session, box.append)
        deadline = time.monotonic() + timeout
        while not box:
            left = deadline - time.monotonic()
            if left <= 0:
                raise TimeoutError(f"no reply from Chrome to {method}")
            if select.select([self.read_fd], [], [], left)[0]:
                self.pump()
        if "error" in box[0]:
            raise RuntimeError(f"{method}: {box[0]['error']}")
        return box[0]["result"]


def is_url(target):
    return re.match(r"https?://", target) is not None


def display_name(target):
    if is_url(target):
        parts = urllib.parse.urlsplit(target)
        return parts.netloc + parts.path
    return os.path.basename(target)


def find_chrome():
    playwright = glob.glob(
        os.path.expanduser("~/Library/Caches/ms-playwright/chromium-*/chrome-mac*/*.app/Contents/MacOS/*")
    )
    for path in (*CHROMES, *sorted(playwright, reverse=True)):
        if os.access(path, os.X_OK):
            return path
    raise RuntimeError("no Chrome, Brave or Chromium found in /Applications or the Playwright cache")


def read_winsize(fd):
    return struct.unpack("4H", fcntl.ioctl(fd, termios.TIOCGWINSZ, b"\0" * 8))


def wait_for_real_size(fd):
    """Return the pane's winsize once it has pixels and has stopped changing, or the last one read."""
    deadline = time.monotonic() + SIZE_DEADLINE
    last, since = None, time.monotonic()
    while time.monotonic() < deadline:
        size = read_winsize(fd)
        now = time.monotonic()
        if size != last:
            last, since = size, now
        # 24x80 is what a new pane reads until its client attaches, and the scale is fixed from this size.
        elif size[2] and size[3] and now - since >= (DEFAULT_SIZE_WAIT if size[:2] == (24, 80) else SIZE_SETTLE):
            break
        time.sleep(0.02)
    return last


def cell_size(winsize):
    rows, cols, width_px, height_px = winsize
    if width_px and height_px and rows and cols:
        return width_px // cols, height_px // rows
    return FALLBACK_CELL


def choose_scale(device_width):
    """Device pixels per CSS pixel: the image stays 1:1 at any value, so only text size is at stake.

    Fit MIN_CSS_WIDTH CSS pixels when the pane allows it at 1.25x or more, else fall back to 1.25x,
    so a half-screen pane gets the page's wide layout with text about the terminal's own size.
    """
    return min(2.0, max(1.25, device_width / MIN_CSS_WIDTH))


class Viewer:
    def __init__(self, target, debug_dir, dump_frames, status_file, focus_on_quit):
        self.name = display_name(target)
        self.url = target if is_url(target) else "file://" + urllib.parse.quote(target)
        self.origin = urllib.parse.urlsplit(self.url).netloc
        self.focus_on_quit = focus_on_quit
        self.quit_by_user = False
        self.debug_dir = debug_dir
        self.dump_frames = dump_frames
        self.status_file = status_file
        self.log_file = open(os.path.join(debug_dir, "log.txt"), "a", buffering=1) if debug_dir else None
        self.fd = sys.stdin.fileno()
        self.out = collections.deque()
        self.out_offset = 0
        self.chrome = None
        self.profile = None
        self.cdp = None
        self.session = None
        self.target_id = None

        self.winsize = None
        self.scale = 1.0
        self.grid = (1, 1, 1, 1)
        self.expected = None
        self.resize_at = None
        self.footer_dirty = True
        self.footer_at = 0
        self.notice = ""

        self.latest = None
        self.image_id = 0
        self.shown_id = 0
        self.placing = None
        self.placing_since = 0
        self.written_at = 0
        self.frame_number = 0
        self.dropped = 0
        self.last_ms = None
        self.place_times = collections.deque(maxlen=120)
        self.announced = False

        self.last_cast = None
        self.cast_seq = 0
        self.last_cast_at = 0
        self.needs_settle = False
        self.settling = False
        self.moving = False
        self.blocked = False
        self.on_error_page = False
        self.loaded = False
        self.wheel_at = 0

        self.pending = b""
        self.wheel = [0.0, 0.0, None, 0]
        self.wheel_busy = False
        self.move = None
        self.move_busy = False
        self.buttons = 0
        self.click = (0, None, 0)

    def log(self, text):
        if self.log_file:
            self.log_file.write(f"{time.time():.3f} {text}\n")

    def report(self, status):
        if self.status_file and not self.announced:
            self.announced = True
            with open(self.status_file, "w") as target:
                target.write(status)

    # Terminal output. stdout is non-blocking and fed from the select loop, so a slow terminal
    # delays pictures but never input.
    def write(self, data):
        self.out.append(data if isinstance(data, bytes) else data.encode())

    def flush_some(self):
        while self.out:
            view = memoryview(self.out[0])[self.out_offset :]
            try:
                self.out_offset += os.write(1, view[:WRITE_CHUNK])
            except BlockingIOError:
                return
            if self.out_offset >= len(self.out[0]):
                self.out.popleft()
                self.out_offset = 0
            else:
                return

    def apply_winsize(self, winsize):
        self.winsize = winsize
        rows, cols, _, _ = winsize
        cell_w, cell_h = cell_size(winsize)
        self.grid = (cols, max(rows - 1, 1), cell_w, cell_h)
        self.footer_dirty = True

    def send_metrics(self):
        cols, rows, cell_w, cell_h = self.grid
        width = max(round(cols * cell_w / self.scale), 1)
        height = max(round(rows * cell_h / self.scale), 1)
        self.expected = (round(width * self.scale), round(height * self.scale))
        self.log(f"metrics css={width}x{height} scale={self.scale:.4f} device={self.expected} grid={self.grid}")
        self.cdp.send(
            "Emulation.setDeviceMetricsOverride",
            {"width": width, "height": height, "deviceScaleFactor": self.scale, "mobile": False},
            self.session,
        )
        self.needs_settle = True
        self.last_cast_at = time.monotonic()
        if self.loaded:
            self.start_screencast()

    def start_chrome(self):
        self.profile = tempfile.mkdtemp(prefix=f"chrome-profile-{os.getpid()}-", dir=STATE_DIR)
        chrome_in, ours_out = os.pipe()
        ours_in, chrome_out = os.pipe()
        self.chrome = subprocess.Popen(
            [
                "/bin/sh", "-c", f'exec "$0" "$@" 3<&{chrome_in} 4>&{chrome_out}',
                find_chrome(),
                "--headless=new",
                f"--user-data-dir={self.profile}",
                "--remote-debugging-pipe",
                # Screencast frames only reach device resolution with the real scale; the emulated
                # one alone gives CSS-pixel frames. It cannot change after launch.
                f"--force-device-scale-factor={self.scale}",
                "--force-color-profile=srgb",
                "--disable-smooth-scrolling",
                "--no-first-run",
                "--no-default-browser-check",
                "--disable-extensions",
                "--disable-sync",
                "--disable-background-networking",
                "--disable-component-update",
                "about:blank",
            ],
            pass_fds=(chrome_in, chrome_out),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        os.close(chrome_in)
        os.close(chrome_out)
        self.cdp = Cdp(ours_in, ours_out, self.on_event)

    def stop_chrome(self):
        if self.chrome:
            if self.chrome.poll() is None:
                self.chrome.terminate()
                try:
                    self.chrome.wait(3)
                except subprocess.TimeoutExpired:
                    self.chrome.kill()
                    self.chrome.wait()
            # Helpers outlive the browser for a moment and can recreate files in the profile.
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                found = subprocess.run(["pgrep", "-f", self.profile], capture_output=True, text=True).stdout.split()
                if not found:
                    break
                time.sleep(0.05)
            else:
                for pid in found:
                    try:
                        os.kill(int(pid), signal.SIGKILL)
                    except OSError:
                        pass
        if self.profile:
            shutil.rmtree(self.profile, ignore_errors=True)

    def attach(self):
        cdp = self.cdp
        cdp.call("Target.setDiscoverTargets", {"discover": True})
        target = next(t for t in cdp.call("Target.getTargets")["targetInfos"] if t["type"] == "page")
        self.target_id = target["targetId"]
        self.session = cdp.call("Target.attachToTarget", {"targetId": self.target_id, "flatten": True})["sessionId"]
        cdp.call("Browser.setDownloadBehavior", {"behavior": "deny"})
        cdp.call("Page.enable", session=self.session)
        # Only Document requests: the file's own subresources and the viewer's own navigation stay free.
        cdp.call("Fetch.enable", {"patterns": [{"resourceType": "Document"}]}, self.session)
        cdp.call("Emulation.setFocusEmulationEnabled", {"enabled": True}, self.session)
        # Classic scrollbars would take layout width that a Mac browser's overlay ones do not.
        cdp.call("Emulation.setScrollbarsHidden", {"hidden": True}, self.session)
        # A smooth-scrolled jump or a reveal animation would cost a full picture for every step.
        cdp.call(
            "Emulation.setEmulatedMedia",
            {"features": [{"name": "prefers-reduced-motion", "value": "reduce"}]},
            self.session,
        )
        self.send_metrics()
        failure = cdp.call("Page.navigate", {"url": self.url}, self.session).get("errorText")
        if failure:
            raise RuntimeError(f"could not load {self.url}: {failure}")

    def start_screencast(self):
        width, height = self.expected
        shrink = min(1.0, (MOTION_PIXELS / (width * height)) ** 0.5)
        # Chrome keeps the old limits if a running screencast is started again.
        self.cdp.send("Page.stopScreencast", session=self.session)
        self.cdp.send(
            "Page.startScreencast",
            {"format": "png", "maxWidth": round(width * shrink), "maxHeight": round(height * shrink)},
            self.session,
        )

    def on_event(self, message):
        method = message["method"]
        params = message["params"]
        if method == "Page.screencastFrame":
            self.on_cast(params)
        elif method == "Page.loadEventFired":
            # Not before this: the navigation swaps renderers, and the call fails during the swap.
            self.loaded = True
            self.start_screencast()
            self.leave_error_page_if_blocked()
        elif method == "Page.frameNavigated":
            self.on_frame_navigated(params["frame"])
        elif method == "Fetch.requestPaused":
            self.on_document_request(params)
        elif method == "Target.targetCreated":
            info = params["targetInfo"]
            if info["type"] == "page" and info["targetId"] != self.target_id and self.target_id:
                self.cdp.send("Target.closeTarget", {"targetId": info["targetId"]})
                self.say("blocked a new tab")
        elif method == "Page.javascriptDialogOpening":
            # Unanswered, a dialog freezes the renderer and every later input call with it.
            self.cdp.send("Page.handleJavaScriptDialog", {"accept": False}, self.session)
            self.say(f"dismissed {params['type']}")
        elif method == "Target.targetCrashed":
            self.say("page crashed")

    def on_document_request(self, params):
        url = params["request"]["url"].split("#", 1)[0]
        same_file = url == self.url.split("#", 1)[0]
        same_site = is_url(self.url) and is_url(url) and urllib.parse.urlsplit(url).netloc == self.origin
        if same_file or same_site or url == "about:blank":
            self.cdp.send("Fetch.continueRequest", {"requestId": params["requestId"]}, self.session)
        else:
            # Aborted leaves the current page up, except on an http link, handled in on_frame_navigated.
            self.blocked = True
            self.cdp.send("Fetch.failRequest", {"requestId": params["requestId"], "errorReason": "Aborted"}, self.session)
            self.say(f"blocked {url}")

    def on_frame_navigated(self, frame):
        self.on_error_page = "parentId" not in frame and frame["url"].startswith("chrome-error:")

    def leave_error_page_if_blocked(self):
        # Chrome tries an http link as https first, and an aborted attempt lands on its error page.
        # Going back any earlier than the error page's load event gets cancelled by it.
        if not (self.blocked and self.on_error_page):
            return
        self.blocked = False

        def back(message):
            history = message.get("result")
            if history and history["currentIndex"] > 0:
                entry = history["entries"][history["currentIndex"] - 1]
                self.cdp.send("Page.navigateToHistoryEntry", {"entryId": entry["id"]}, self.session)

        self.cdp.send("Page.getNavigationHistory", session=self.session, reply=back)

    def say(self, notice):
        self.notice = notice
        self.footer_dirty = True
        self.log(f"notice {notice}")

    def on_cast(self, params):
        # Acked at once: a late ack makes Chrome skip frames with no catch-up, so the last one
        # of a burst could be lost.
        self.cdp.send("Page.screencastFrameAck", {"sessionId": params["sessionId"]}, self.session)
        data = params["data"]
        # Taking a screenshot makes Chrome repeat identical frames, which must not count as a change.
        if data == self.last_cast:
            return
        self.last_cast = data
        self.cast_seq += 1
        now = time.monotonic()
        previous = self.last_cast_at
        self.last_cast_at = now
        self.needs_settle = True
        self.moving = now - self.wheel_at < WHEEL_MOTION or now - previous < BURST_GAP
        if self.moving:
            self.offer(data, time.time() - params["metadata"]["timestamp"], now, "cast")

    def wants_sharp_frame(self, now):
        if not self.needs_settle or self.settling:
            return False
        return not self.moving or now - self.last_cast_at > SETTLE

    def request_sharp_frame(self):
        self.needs_settle = False
        self.settling = True
        seq = self.cast_seq
        started = time.monotonic()

        def reply(message):
            self.settling = False
            if "result" not in message:
                return
            # While moving, a newer motion frame is already out and this picture is behind it.
            if seq == self.cast_seq or not self.moving:
                self.moving = False
                self.offer(message["result"]["data"], time.monotonic() - started, time.monotonic(), "shot")

        self.cdp.send("Page.captureScreenshot", {"format": "png", "optimizeForSpeed": True}, self.session, reply)

    def offer(self, data, source_age, received, kind):
        if self.latest:
            self.dropped += 1
        self.latest = (data, source_age, received, kind)

    def next_picture(self):
        if not self.latest or self.placing:
            return
        data, source_age, received, kind = self.latest
        self.latest = None
        png = base64.b64decode(data[:64])
        width, height = struct.unpack(">II", png[16:24])
        # Motion frames are smaller than the grid, but a stale size from before a resize has the wrong shape.
        if self.expected and abs(width * self.expected[1] - height * self.expected[0]) > 0.01 * width * self.expected[1]:
            self.log(f"dropped {kind} {width}x{height}, want {self.expected}")
            return

        self.image_id += 1
        image_id = self.image_id
        self.frame_number += 1
        if self.dump_frames:
            with open(os.path.join(self.debug_dir, f"frame-{self.frame_number:05}.png"), "wb") as target:
                target.write(base64.b64decode(data))
        encoded = data.encode()
        chunks = []
        for start in range(0, len(encoded), 4096):
            more = int(start + 4096 < len(encoded))
            control = f"a=t,f=100,i={image_id},m={more}" if start == 0 else f"m={more}"
            chunks.append(b"\x1b_G%s;%s\x1b\\" % (control.encode(), encoded[start : start + 4096]))
        self.write(b"".join(chunks))

        cols, rows, cell_w, cell_h = self.grid
        crop_w, crop_h = min(width, cols * cell_w), min(height, rows * cell_h)
        swap = (
            "\x1b[?2026h\x1b[H"
            f"\x1b_Ga=p,i={image_id},p=1,x=0,y=0,w={crop_w},h={crop_h},c={cols},r={rows},C=1\x1b\\"
        )
        # Place first, then delete: the other order flashes the background.
        if self.shown_id:
            swap += f"\x1b_Ga=d,d=I,i={self.shown_id},q=2\x1b\\"
        swap += "\x1b[?2026l"
        self.write(swap)
        self.shown_id = image_id
        self.placing = (image_id, source_age, received, kind, len(encoded) * 3 // 4, width, height, self.frame_number)
        self.placing_since = time.monotonic()
        self.written_at = 0

    def on_kitty_reply(self, token):
        body = token[3:-2].decode(errors="replace")
        control, _, status = body.partition(";")
        self.log(f"reply {control} {status}")
        if status != "OK":
            self.say(f"terminal: {status}")
            self.report(status)
            self.placing = None
        elif "p=" in control and self.placing:
            self.finish_placing()

    def finish_placing(self):
        image_id, source_age, received, kind, size, width, height, number = self.placing
        self.placing = None
        now = time.monotonic()
        self.last_ms = (source_age + now - received) * 1000
        self.place_times.append(now)
        self.footer_dirty = True
        self.log(
            f"frame {number} {kind} {width}x{height} {size // 1024}KB chrome={source_age * 1000:.0f}ms"
            f" sent+placed={(now - received) * 1000:.0f}ms written={((self.written_at or now) - self.placing_since) * 1000:.0f}ms"
            f" total={self.last_ms:.0f}ms dropped={self.dropped}"
        )
        self.report("OK")

    def fps(self):
        now = time.monotonic()
        recent = [t for t in self.place_times if now - t <= 1]
        return len(recent)

    def draw_footer(self):
        now = time.monotonic()
        if not self.footer_dirty and not (self.place_times and now - self.place_times[-1] < 1.2 and now - self.footer_at > 0.25):
            return
        if now - self.footer_at < 0.1 and self.placing:
            return
        self.footer_dirty = False
        self.footer_at = now
        rows, cols, _, _ = self.winsize
        speed = f"{self.fps()} fps  {self.last_ms:.0f} ms" if self.last_ms is not None else "loading"
        details = f"{speed}  q quit"
        if self.notice:
            details = f"{self.notice}  {details}"
        width = max(cols - 1, 1)
        room = width - len(details) - 2
        text = (f"{self.name[:room]}  {details}" if room > 0 else details)[:width]
        self.write(f"\x1b[{max(rows, 1)};1H\x1b[2K\x1b[2m{text}\x1b[0m")

    def css_point(self, col, row):
        cols, rows, cell_w, cell_h = self.grid
        col, row = min(max(col, 1), cols), min(max(row, 1), rows)
        return (col - 0.5) * cell_w / self.scale, (row - 0.5) * cell_h / self.scale

    def flush_wheel(self):
        delta_x, delta_y, point, modifiers = self.wheel
        if self.wheel_busy or (not delta_x and not delta_y):
            return
        self.wheel[0] = self.wheel[1] = 0.0
        self.wheel_busy = True

        def done(_):
            self.wheel_busy = False
            self.flush_wheel()

        self.mouse("mouseWheel", point, "none", modifiers, reply=done, deltaX=delta_x, deltaY=delta_y)

    def flush_move(self):
        if self.move_busy or not self.move:
            return
        point, modifiers = self.move
        self.move = None
        self.move_busy = True

        def done(_):
            self.move_busy = False
            self.flush_move()

        button = "left" if self.buttons & 1 else "middle" if self.buttons & 4 else "right" if self.buttons & 2 else "none"
        self.mouse("mouseMoved", point, button, modifiers, reply=done)

    def mouse(self, kind, point, button, modifiers, reply=None, **extra):
        params = {
            "type": kind,
            "x": point[0],
            "y": point[1],
            "button": button,
            "buttons": self.buttons,
            "modifiers": modifiers,
            **extra,
        }
        self.cdp.send("Input.dispatchMouseEvent", params, self.session, reply)

    def on_mouse(self, token):
        code, col, row = (int(n) for n in token[3:-1].split(b";"))
        press = token.endswith(b"M")
        modifiers = (SHIFT if code & 4 else 0) | (ALT if code & 8 else 0) | (CTRL if code & 16 else 0)
        point = self.css_point(col, row)
        if code & 64:
            if press:
                direction = code & 3
                self.wheel[0] += {2: -WHEEL_CSS_PX, 3: WHEEL_CSS_PX}.get(direction, 0)
                self.wheel[1] += {0: -WHEEL_CSS_PX, 1: WHEEL_CSS_PX}.get(direction, 0)
                self.wheel[2], self.wheel[3] = point, modifiers
                self.wheel_at = time.monotonic()
                self.flush_wheel()
            return
        if code & 32:
            self.move = (point, modifiers)
            self.flush_move()
            return
        if row > self.grid[1]:
            return
        # A click must land after any wheel or motion that came before it.
        if self.wheel[0] or self.wheel[1]:
            self.wheel_busy = False
            self.flush_wheel()
        if self.move:
            self.move_busy = False
            self.flush_move()
        number = code & 3
        name, bit = {0: ("left", 1), 1: ("middle", 4), 2: ("right", 2)}.get(number, ("left", 1))
        if press:
            now = time.monotonic()
            count, cell, at = self.click
            count = count + 1 if cell == (col, row) and now - at < DOUBLE_CLICK else 1
            self.click = (count, (col, row), now)
            self.buttons |= bit
            self.mouse("mousePressed", point, name, modifiers, clickCount=count)
        else:
            self.buttons &= ~bit
            self.mouse("mouseReleased", point, name, modifiers, clickCount=self.click[0] or 1)

    def key(self, key, code, vk, text, command, modifiers=0):
        params = {"key": key, "code": code, "windowsVirtualKeyCode": vk, "nativeVirtualKeyCode": vk, "modifiers": modifiers}
        down = {**params, "type": "keyDown" if text else "rawKeyDown"}
        if text:
            down["text"] = text
            down["unmodifiedText"] = text
        if command:
            down["commands"] = [command]
        self.cdp.send("Input.dispatchKeyEvent", down, self.session)
        self.cdp.send("Input.dispatchKeyEvent", {**params, "type": "keyUp"}, self.session)

    def char_key(self, char):
        modifiers = 0
        if char.isascii() and char.isalpha():
            code, vk = f"Key{char.upper()}", ord(char.upper())
            modifiers = SHIFT if char.isupper() else 0
        elif char.isdigit() and char.isascii():
            code, vk = f"Digit{char}", ord(char)
        elif char == " ":
            code, vk = "Space", 32
        else:
            code, vk = "", 0
        self.key(char, code, vk, char, None, modifiers)

    def text_has_focus(self):
        try:
            result = self.cdp.call(
                "Runtime.evaluate", {"expression": TEXT_FOCUS, "returnByValue": True}, self.session, timeout=1
            )
            return result["result"].get("value") is True
        except (TimeoutError, RuntimeError):
            return False

    def on_csi(self, token):
        ss3 = token.startswith(b"\x1bO")
        body = token[2:].decode(errors="replace")
        final = body[-1]
        params = body[:-1].split(";") if not ss3 else [""]
        modifiers = 0
        if len(params) > 1 and params[1].isdigit():
            bits = int(params[1]) - 1
            modifiers = (SHIFT if bits & 1 else 0) | (ALT if bits & 2 else 0) | (CTRL if bits & 4 else 0)
        if final == "Z":
            self.key(*KEYS["\t"], SHIFT)
            return
        name = final if final != "~" else f"{params[0]}~"
        if name in KEYS:
            self.key(*KEYS[name], modifiers)

    def on_tokens(self, data):
        if self.log_file and not data.startswith(b"\x1b_G"):
            self.log(f"input {data[:80]!r}")
        data = self.pending + data
        self.pending = b""
        i = 0
        while i < len(data):
            byte = data[i]
            if byte == 0x1b:
                match = TOKEN.match(data, i)
                if match:
                    token = match.group(0)
                    i = match.end()
                    if token.startswith(b"\x1b_G"):
                        self.on_kitty_reply(token)
                    elif token.startswith(b"\x1b[<"):
                        self.on_mouse(token)
                    else:
                        self.on_csi(token)
                elif UNFINISHED.fullmatch(data, i):
                    self.pending = data[i:]
                    return
                else:
                    i += 2
                continue
            if byte >= 0x80:
                length = 2 if byte < 0xe0 else 3 if byte < 0xf0 else 4
                if i + length > len(data):
                    self.pending = data[i:]
                    return
                self.char_key(data[i : i + length].decode(errors="replace"))
                i += length
                continue
            i += 1
            char = chr(byte)
            if byte == 3:
                self.quit_by_user = True
                raise SystemExit(0)
            if byte == 0x0d or byte == 0x0a:
                self.key(*KEYS["\r"])
            elif byte == 0x09:
                self.key(*KEYS["\t"])
            elif byte in (0x7f, 0x08):
                self.key(*KEYS["\x7f"])
            elif byte < 0x20:
                letter = chr(byte + 0x60)
                self.key(letter, f"Key{letter.upper()}", byte + 0x40, None, None, CTRL)
            elif char == "q" and not self.text_has_focus():
                self.quit_by_user = True
                raise SystemExit(0)
            else:
                self.char_key(char)

    def on_debug_eval(self):
        for line in os.read(self.eval_fd, 65536).decode().splitlines():
            if line.strip():
                self.run_debug_eval(line)

    def run_debug_eval(self, expression):
        def reply(message):
            result = message.get("result", {})
            value = result.get("result", {}).get("value", result.get("exceptionDetails", message.get("error")))
            with open(os.path.join(self.debug_dir, "eval.out"), "a") as target:
                target.write(json.dumps(value) + "\n")

        self.cdp.send(
            "Runtime.evaluate", {"expression": expression, "returnByValue": True, "awaitPromise": True}, self.session, reply
        )

    def loop(self):
        wake_read, wake_write = os.pipe()
        os.set_blocking(wake_write, False)
        # select() retries after a signal (PEP 475), so SIGWINCH has to wake it through this pipe.
        signal.set_wakeup_fd(wake_write)
        signal.signal(signal.SIGWINCH, lambda *_: None)
        sources = [self.fd, self.cdp.read_fd, wake_read]
        self.eval_fd = None
        if self.debug_dir:
            fifo = os.path.join(self.debug_dir, "eval")
            if not os.path.exists(fifo):
                os.mkfifo(fifo)
            # Read-write so the loop never sees EOF between test commands.
            self.eval_fd = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
            sources.append(self.eval_fd)

        while True:
            now = time.monotonic()
            if self.placing and now - self.placing_since > PLACE_TIMEOUT:
                self.log("no placement reply")
                self.placing = None
            if self.wants_sharp_frame(now):
                self.request_sharp_frame()
            if self.resize_at and now >= self.resize_at:
                self.resize_at = None
                self.send_metrics()
            self.next_picture()
            self.draw_footer()
            self.flush_some()
            if self.placing and not self.out and not self.written_at:
                self.written_at = time.monotonic()

            wait = 1.0
            if self.pending:
                wait = ESC_TIMEOUT
            elif self.resize_at:
                wait = max(self.resize_at - now, 0)
            elif self.needs_settle or self.placing or self.place_times and now - self.place_times[-1] < 1.3:
                wait = 0.05
            ready, writable, _ = select.select(sources, [1] if self.out else [], [], wait)

            if wake_read in ready:
                os.read(wake_read, 4096)
                size = read_winsize(self.fd)
                if size != self.winsize:
                    self.apply_winsize(size)
                    self.write("\x1b[H\x1b[J")
                    self.resize_at = time.monotonic() + RESIZE_DEBOUNCE
            if self.cdp.read_fd in ready:
                self.cdp.pump()
            if self.fd in ready:
                data = os.read(self.fd, 65536)
                if not data:
                    return
                self.on_tokens(data)
            elif self.pending == b"\x1b" and not ready:
                self.pending = b""
                self.key(*KEYS["\x1b"])
            if self.eval_fd is not None and self.eval_fd in ready:
                self.on_debug_eval()
            if writable:
                self.flush_some()

    def run(self):
        for hangup in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
            signal.signal(hangup, lambda *_: sys.exit(0))
        saved = termios.tcgetattr(self.fd)
        tty.setraw(self.fd)
        try:
            # Autowrap off so the footer cannot scroll the screen. 1003 reports motion with no button,
            # 1006 is SGR form.
            os.write(1, b"\x1b[?1049h\x1b[?25l\x1b[?7l\x1b[?1003h\x1b[?1006h\x1b[H\x1b[J")
            winsize = wait_for_real_size(self.fd)
            self.log(f"winsize {winsize}")
            self.apply_winsize(winsize)
            cols, _, cell_w, _ = self.grid
            self.scale = choose_scale(cols * cell_w)
            self.start_chrome()
            self.attach()
            os.set_blocking(1, False)
            self.loop()
        except EOFError as error:
            self.report(str(error))
        except (TimeoutError, RuntimeError, OSError) as error:
            self.log(f"error {error}")
            self.report(str(error))
        finally:
            try:
                signal.signal(signal.SIGHUP, signal.SIG_IGN)
                signal.signal(signal.SIGTERM, signal.SIG_IGN)
                self.stop_chrome()
            finally:
                try:
                    os.set_blocking(1, True)
                    os.write(
                        1,
                        b"\x1b_Ga=d,d=A,q=2\x1b\\\x1b[?1006l\x1b[?1003l\x1b[?7h\x1b[?25h\x1b[?1049l",
                    )
                    termios.tcsetattr(self.fd, termios.TCSADRAIN, saved)
                except OSError:
                    pass
                if self.quit_by_user and self.focus_on_quit:
                    subprocess.run(["rex", "block", "focus", self.focus_on_quit], capture_output=True)


def close_previous_viewer(state_file):
    try:
        with open(state_file) as saved:
            previous = saved.read().strip()
    except FileNotFoundError:
        return
    if previous and subprocess.run(["rex", "block", "inspect", previous], capture_output=True).returncode == 0:
        subprocess.run(["rex", "block", "close", previous], capture_output=True)
    os.remove(state_file)


def remove_orphaned_profiles():
    """Chrome exits with the viewer's pipe, but a viewer killed outright leaves its profile behind."""
    for profile in glob.glob(os.path.join(STATE_DIR, "chrome-profile-*")):
        pid = int(os.path.basename(profile).split("-")[2])
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            shutil.rmtree(profile, ignore_errors=True)
        except PermissionError:
            pass


def launch(args):
    target = args.target if is_url(args.target) else os.path.abspath(args.target)
    if not is_url(target) and not os.path.isfile(target):
        sys.exit(f"No such file: {target}")
    anchor = os.environ.get("REX_BLOCK")
    if not anchor or not os.environ.get("REX_SESSION"):
        sys.exit("REX_BLOCK and REX_SESSION are not set: this only works inside a Rex terminal")
    try:
        find_chrome()
    except RuntimeError as error:
        sys.exit(f"Cannot show {target}: {error}")

    os.makedirs(STATE_DIR, exist_ok=True)
    remove_orphaned_profiles()
    state_file = os.path.join(STATE_DIR, f"{anchor}.viewer")
    close_previous_viewer(state_file)

    status_file = os.path.join(STATE_DIR, f"{anchor}.status")
    if os.path.exists(status_file):
        os.remove(status_file)
    command = [sys.executable, os.path.abspath(__file__), "--view", "--status", status_file]
    if not args.no_focus:
        command += ["--focus-on-quit", anchor]
    if args.debug:
        os.makedirs(args.debug, exist_ok=True)
        command += ["--debug", os.path.abspath(args.debug)]
    if args.dump_frames:
        command.append("--dump-frames")
    created = subprocess.run(
        ["rex", "split", f"--focus={'false' if args.no_focus else 'true'}", "--split", "right", "--shell=none",
         "--label", display_name(target)[:128], "-b", anchor, "--", *command, target],
        check=True, capture_output=True, text=True,
    )
    block = created.stdout.split()[-1]
    with open(state_file, "w") as saved:
        saved.write(block)
    # rex split ignores --ratio; a move applies it.
    subprocess.run(["rex", "block", "move", block, "right", anchor, "--ratio", "50"], capture_output=True)

    deadline = time.monotonic() + LAUNCH_TIMEOUT
    status = None
    while time.monotonic() < deadline and not status:
        if os.path.exists(status_file):
            with open(status_file) as source:
                status = source.read()
        if not status and subprocess.run(["rex", "block", "inspect", block], capture_output=True).returncode != 0:
            status = status or "the viewer exited before drawing"
        time.sleep(0.05)
    if os.path.exists(status_file):
        os.remove(status_file)
    if status == "OK":
        print(f"Shown in a pane: {target}")
        return
    subprocess.run(["rex", "block", "close", block], capture_output=True)
    os.remove(state_file)
    sys.exit(f"Could not show {target}: {status or 'timed out waiting for the viewer'}")


def main():
    parser = argparse.ArgumentParser(description="Show a local HTML file live in a Rex pane.")
    parser.add_argument("target", help="local HTML file or http(s) URL")
    parser.add_argument("--debug", metavar="DIR", help="log kitty replies and frames to DIR, and take page JS on DIR/eval")
    parser.add_argument("--dump-frames", action="store_true", help="with --debug, write each frame's exact PNG to DIR")
    parser.add_argument("--view", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--status", help=argparse.SUPPRESS)
    parser.add_argument("--focus-on-quit", help=argparse.SUPPRESS)
    parser.add_argument("--no-focus", action="store_true", help="open without taking focus, for tests")
    args = parser.parse_args()
    if args.view:
        Viewer(args.target, args.debug, args.dump_frames, args.status, args.focus_on_quit).run()
    else:
        launch(args)


if __name__ == "__main__":
    main()
