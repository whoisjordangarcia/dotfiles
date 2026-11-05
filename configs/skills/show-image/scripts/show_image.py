#!/usr/bin/env python3
import base64
import collections
import concurrent.futures
import fcntl
import math
import os
import re
import select
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time
import tty

STATE_DIR = os.path.expanduser("~/.local/state/show-image")
FALLBACK_CELL = (10, 20)
# A tall image fills the pane's width even past 1:1, up to this; anything else stops at 1:1.
MAX_FILL_UPSCALE = 4
# Rex answers EINVAL to a PNG with either side above this.
MAX_DIMENSION = 10000
# Rex holds 128 MiB of decoded images per pane (4 bytes a pixel, even for RGB). Past that it answers
# ENOMEM to one too big, and otherwise evicts the oldest, even one on screen, while still replying OK.
STORE_LIMIT = 120 * 1024 * 1024
BYTES_PER_PIXEL = 4
# Tiles that fit in the store at once. More means less decoding in one go: Rex draws nothing while it
# decodes a PNG.
TILES_HELD = 6
# Height over width from which an image counts as a tall capture: its margins are trimmed, and if it has
# to shrink, it shrinks to hold this much of itself in the store.
TALL_RATIO = 3
# Share of the page's rows below which a block past a blank gutter counts as a sidebar.
SIDEBAR_ROWS = 0.1
# Blank columns narrower than this are spacing inside a block, not a gutter.
GUTTER_MIN = 16
REPLY_TIMEOUT = 5
LAUNCH_TIMEOUT = 20
ESC_TIMEOUT = 0.05
WHEEL_ROWS = 3
LINE_SHARE = 1 / 3
PAGE_SHARE = 0.9
FRAME = 0.015
# Settles a page jump in about 250 ms.
EASE_TAU = 0.03
# Beyond this many views a jump would have to upload every tile it passes, so it cuts instead.
EASE_MAX_VIEWS = 2
UPLOAD_BATCH = 8
OK = "OK"

Layout = collections.namedtuple("Layout", "scrolls col row cols rows crop_h max_top pixel")
Tile = collections.namedtuple("Tile", "top height")
Placement = collections.namedtuple("Placement", "tile row rows y height")

TOKEN = re.compile(
    rb"\x1b_G[^\x1b]*\x1b\\|\x1b\[<\d+;\d+;\d+[Mm]|\x1b\[[0-9;:?]*[A-Za-z~]|\x1bO[A-Za-z]"
)
UNFINISHED = re.compile(rb"\x1b(?:_[^\x1b]*\x1b?|\[[0-9;:<?]*|O)?")

LINE_UP = (b"k", b"\x1b[A", b"\x1bOA")
LINE_DOWN = (b"j", b"\x1b[B", b"\x1bOB")
PAGE_UP = (b"b", b"\x1b[5~")
PAGE_DOWN = (b" ", b"\x1b[6~")
TOP = (b"g", b"\x1b[H", b"\x1b[1~", b"\x1bOH")
BOTTOM = (b"G", b"\x1b[F", b"\x1b[4~", b"\x1bOF")
QUIT = (b"q", b"\x1b", b"\x03")


def tile_shape(width, height):
    """Return (tile height, step between tile tops), or None if the image fits in one tile."""
    if height <= MAX_DIMENSION and width * height * BYTES_PER_PIXEL <= STORE_LIMIT:
        return None
    tile = min(MAX_DIMENSION, STORE_LIMIT // (width * BYTES_PER_PIXEL * TILES_HELD))
    # Neighbours overlap by more than a cell's worth of image in all but very narrow panes, so a join
    # can fall on a row boundary and neither placement is stretched to meet it.
    return tile, tile - max(width // 16, 128)


def tile_plan(width, height):
    shape = tile_shape(width, height)
    if not shape:
        return [Tile(0, height)]
    tile, step = shape
    tiles = []
    top = 0
    while True:
        tiles.append(Tile(top, min(tile, height - top)))
        if top + tile >= height:
            return tiles
        top += step


def view_limit(width, height):
    """Return the most image rows that can be guaranteed on screen, wherever the view falls."""
    shape = tile_shape(width, height)
    if not shape:
        return height
    tile, step = shape
    return (STORE_LIMIT // (width * BYTES_PER_PIXEL * tile) - 1) * step


def layout(image_size, winsize):
    """Return where to draw an image in a pane, in cells; winsize is TIOCGWINSZ order.

    The last pane row is left for the footer. col and row are 0-based. crop_h and max_top are in
    image pixels, and max_top is 0 unless the image scrolls. pixel is image pixels per device pixel.
    """
    image_w, image_h = image_size
    rows, columns, width_px, height_px = winsize
    columns = max(columns, 1)
    usable_rows = max(rows - 1, 1)
    cell_w = width_px / columns if width_px else FALLBACK_CELL[0]
    cell_h = height_px / rows if height_px and rows else FALLBACK_CELL[1]
    pane_h = usable_rows * cell_h

    fill_scale = min(columns * cell_w / image_w, MAX_FILL_UPSCALE)
    limit = view_limit(image_w, image_h)
    scrolls = image_h * fill_scale > 2 * pane_h or image_h > limit
    scale = fill_scale if scrolls else min(fill_scale, 1, pane_h / image_h)
    shown_cols = min(max(round(image_w * scale / cell_w), 1), columns)
    if scrolls:
        # Derived from the rounded cell count, so the terminal's stretch to the cell grid cancels out.
        crop_h = min(round(image_w * pane_h / (shown_cols * cell_w)), image_h)
        shown_rows = usable_rows if crop_h <= limit else max(round(usable_rows * limit / crop_h), 1)
        crop_h = min(crop_h, limit)
    else:
        shown_rows = min(max(round(image_h * scale / cell_h), 1), usable_rows)
        crop_h = image_h
    return Layout(
        scrolls,
        (columns - shown_cols) // 2,
        (usable_rows - shown_rows) // 2,
        shown_cols,
        shown_rows,
        crop_h,
        image_h - crop_h,
        image_w / (shown_cols * cell_w),
    )


def placements(tiles, top, crop_h, rows):
    """Cut the image rows top..top+crop_h, drawn across rows cells, into one placement per tile."""
    per_row = crop_h / rows
    pieces = []
    row = 0
    while row < rows:
        y = top + round(row * per_row)
        index = max(i for i, tile in enumerate(tiles) if tile.top <= y)
        tile = tiles[index]
        tile_end = tile.top + tile.height
        end = row + 1
        while end < rows and top + round((end + 1) * per_row) <= tile_end:
            end += 1
        bottom = min(top + round(end * per_row), tile_end)
        pieces.append(Placement(index, row, end - row, y - tile.top, max(bottom - y, 1)))
        row = end
    return pieces


def tiles_to_hold(tiles, urgent, direction, width, uploading):
    """Return tile indexes to hold, most urgent first, within the store limit."""
    first, last = min(urgent), max(urgent)
    ahead = [last + 1, last + 2] if direction > 0 else [first - 1, first - 2]
    behind = [first - 1, first - 2] if direction > 0 else [last + 1, last + 2]
    wanted = [*([] if uploading is None else [uploading]), *urgent, *ahead, *behind]
    hold = []
    room = STORE_LIMIT
    for index in wanted:
        if index in hold or not 0 <= index < len(tiles):
            continue
        cost = width * tiles[index].height * BYTES_PER_PIXEL
        if cost > room:
            break
        room -= cost
        hold.append(index)
    return hold


def needed_tiles(start, end, jump, direction):
    """Order what a move needs: the view it starts from and, unless it cuts, each tile on the way."""
    if jump:
        return [*end, *start]
    low, high = min(start + end), max(start + end)
    between = range(low, high + 1) if direction > 0 else range(high, low - 1, -1)
    return [*start, *between]


def ease_toward(shown, target, dt, span):
    """Close a share of the distance to target for a frame of dt seconds; span is the range in device px."""
    shown += (target - shown) * (1 - math.exp(-dt / EASE_TAU))
    return target if abs(target - shown) * span < 0.5 else shown


def view_top(position, geometry):
    if position >= 1:
        return geometry.max_top
    return min(round(round(position * geometry.max_top / geometry.pixel) * geometry.pixel), geometry.max_top)


def parse_input(data):
    """Split raw input into tokens, returning them and any trailing unfinished escape sequence.

    A lone Esc comes back as unfinished: only the caller's timeout can tell it from a sequence's start.
    """
    tokens = []
    i = 0
    while i < len(data):
        if data[i] != 0x1b:
            tokens.append(data[i : i + 1])
            i += 1
            continue
        match = TOKEN.match(data, i)
        if match:
            token = match.group(0)
            if token.startswith(b"\x1b[<"):
                wheel = {b"64": b"WHEEL_UP", b"65": b"WHEEL_DOWN"}.get(token[3:].split(b";")[0])
                if wheel and token.endswith(b"M"):
                    tokens.append(wheel)
            else:
                tokens.append(token)
            i = match.end()
        elif UNFINISHED.fullmatch(data, i):
            return tokens, data[i:]
        else:
            i += 2
    return tokens, b""


def scrolled(position, token, geometry):
    if not geometry.max_top:
        return position
    page = geometry.crop_h * PAGE_SHARE
    line = geometry.crop_h * LINE_SHARE
    wheel = geometry.crop_h / geometry.rows * WHEEL_ROWS
    if token in LINE_UP:
        position -= line / geometry.max_top
    elif token in LINE_DOWN:
        position += line / geometry.max_top
    elif token == b"WHEEL_UP":
        position -= wheel / geometry.max_top
    elif token == b"WHEEL_DOWN":
        position += wheel / geometry.max_top
    elif token in PAGE_UP:
        position -= page / geometry.max_top
    elif token in PAGE_DOWN:
        position += page / geometry.max_top
    elif token in TOP:
        position = 0
    elif token in BOTTOM:
        position = 1
    return min(max(position, 0), 1)


def footer_text(name, real_size, geometry, position, status, columns):
    width = max(columns - 1, 1)
    if status is not None and status != OK:
        return f"Terminal did not draw: {status}. q to close"[:width]
    size = f"{real_size[0]}x{real_size[1]}"
    if status is None:
        details = f"{size}  uploading"
    elif geometry.scrolls:
        details = f"{size}  {round(position * 100)}%  j/k space g/G q"
    else:
        details = f"{size}  q to close"
    room = width - len(details) - 2
    return (f"{name[:room]}  {details}" if room > 0 else details)[:width]


def sips(source, target, *arguments):
    subprocess.run(["sips", *arguments, source, "--out", target], check=True, capture_output=True)


def png_size(png):
    return struct.unpack(">II", png[16:24])


def shrink_factor(width, height):
    """Return the scale that fits the image in a tile's width and a pane's worth of it in the store."""
    shown_area = width * min(height, TALL_RATIO * width)
    return min(1, MAX_DIMENSION / width, math.sqrt(STORE_LIMIT / (BYTES_PER_PIXEL * shown_area)))


def margins(bitmap, width, height):
    """Return (x, width) of the page content in a padded BMP, or None if it has no margins or content.

    Uniform columns go, and so does a block in less than SIDEBAR_ROWS of the page's rows with a uniform
    gutter between it and the rest. A full-page capture draws a fixed sidebar in its first screen only,
    and anything that crosses the gutter keeps the block.
    """
    with open(bitmap, "rb") as source:
        header = source.read(54)
        data_at = struct.unpack("<I", header[10:14])[0]
        pixel = struct.unpack("<H", header[28:30])[0] // 8
        stride = ((width + 2) * pixel + 3) & ~3

        def rows():
            source.seek(data_at + stride)
            for _ in range(height):
                yield source.read(stride)[pixel : (width + 1) * pixel]

        edges = collections.Counter(row[:pixel] for row in rows())
        background = edges.most_common(1)[0][0] * width
        plain = int.from_bytes(background, "big")
        occupied = 0
        for row in rows():
            if row != background:
                occupied |= int.from_bytes(row, "big") ^ plain
        if not occupied:
            return None
        mask = occupied.to_bytes(width * pixel, "big")

        columns = [x for x in range(width) if any(mask[x * pixel : (x + 1) * pixel])]
        blocks = [[columns[0], columns[0] + 1]]
        for x in columns[1:]:
            if x - blocks[-1][1] < GUTTER_MIN:
                blocks[-1][1] = x + 1
            else:
                blocks.append([x, x + 1])
        if len(blocks) > 1:
            counts = [0] * len(blocks)
            for row in rows():
                if row != background:
                    for i, (start, end) in enumerate(blocks):
                        if row[start * pixel : end * pixel] != background[start * pixel : end * pixel]:
                            counts[i] += 1
            blocks = [b for b, n in zip(blocks, counts) if n >= SIDEBAR_ROWS * height] or blocks
    x, end = blocks[0][0], blocks[-1][1]
    return None if end - x == width else (x, end - x)


def prepare(path, scratch):
    """Return the true size, the drawn size, the tiles, and each tile's PNG path."""
    with open(path, "rb") as source:
        header = source.read(24)
    png = path
    if not header.startswith(b"\x89PNG\r\n\x1a\n"):
        png = os.path.join(scratch, "image.png")
        sips(path, png, "-s", "format", "png")
        with open(png, "rb") as source:
            header = source.read(24)
    real_size = png_size(header)
    width, height = real_size

    factor = shrink_factor(width, height)
    if factor < 1:
        width = int(width * factor)
        shrunk = os.path.join(scratch, "shrunk.png")
        sips(png, shrunk, "-s", "format", "png", "--resampleWidth", str(width))
        png = shrunk
        with open(png, "rb") as source:
            width, height = png_size(source.read(24))

    tall = height >= TALL_RATIO * width
    if not tall and not tile_shape(width, height):
        return real_size, (width, height), [Tile(0, height)], [png]

    # A sips crop that starts at 0,0 comes out centred, and one that ends at the bottom edge comes out as
    # the whole image, both silently. A one-pixel border keeps every crop off the edges. BMP because it
    # crops faster than PNG and margins() can read it raw; it drops alpha, so transparency turns black.
    bitmap = os.path.join(scratch, "image.bmp")
    sips(png, bitmap, "-s", "format", "bmp", "-p", str(height + 2), str(width + 2))
    left = 0
    full_width = width
    if tall:
        left, width = margins(bitmap, width, height) or (0, width)
    tiles = tile_plan(width, height)
    if len(tiles) == 1 and width == full_width:
        return real_size, (width, height), tiles, [png]

    paths = [os.path.join(scratch, f"tile{i}.png") for i in range(len(tiles))]

    def cut(job):
        tile, target = job
        sips(
            bitmap, target, "-s", "format", "png", "-c", str(tile.height), str(width),
            "--cropOffset", str(tile.top + 1), str(left + 1),
        )

    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        list(pool.map(cut, zip(tiles, paths)))
    os.remove(bitmap)
    return real_size, (width, height), tiles, paths


def upload(png, image):
    """Yield the escape sequences that upload a file as one image."""
    with open(png, "rb") as source:
        encoded = base64.b64encode(source.read())
    # The protocol caps each escape sequence at 4096 base64 bytes; m=1 means more follow.
    for start in range(0, len(encoded), 4096):
        more = int(start + 4096 < len(encoded))
        control = f"a=t,f=100,i={image + 1},m={more}" if start == 0 else f"m={more}"
        yield b"\x1b_G" + control.encode() + b";" + encoded[start : start + 4096] + b"\x1b\\"


def read_winsize(fd):
    return struct.unpack("4H", fcntl.ioctl(fd, termios.TIOCGWINSZ, b"\0" * 8))


def status_path(block):
    return os.path.join(STATE_DIR, f"{block}.status")


def report(status):
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(status_path(os.environ["REX_BLOCK"]), "w") as target:
        target.write(status)


def draw(pieces, geometry, width, winsize, stale, footer, clear):
    # Not ED 2: besides the screen, it deletes the uploaded image, and Rex then has nothing to place.
    frame = "\x1b[H\x1b[J" if clear else ""
    for image in stale:
        # Not a delete: any a=d during a chunked upload makes Rex drop that upload without a reply. A
        # pixel behind the view's top-left corner is out of sight until the image itself goes.
        frame += f"\x1b[{geometry.row + 1};{geometry.col + 1}H\x1b_Ga=p,i={image + 1},p=1,x=0,y=0,w=1,h=1,c=1,r=1,z=-1,C=1,q=2\x1b\\"
    for piece in pieces:
        # c and r pin the placement to the grid, so a client whose cells differ in pixels from the
        # reported size scales it rather than overflowing. C=1 stops a full-height placement moving
        # the cursor and scrolling the screen.
        frame += (
            f"\x1b[{geometry.row + piece.row + 1};{geometry.col + 1}H"
            f"\x1b_Ga=p,i={piece.tile + 1},p=1,x=0,y={piece.y},w={width},h={piece.height},"
            f"c={geometry.cols},r={piece.rows},C=1,q=2\x1b\\"
        )
    frame += f"\x1b[{max(winsize[0], 1)};1H\x1b[2K{footer}"
    sys.stdout.write(frame)
    sys.stdout.flush()


def show(fd, name, real_size, image_size, tiles, paths):
    """Run the viewer until it ends; return whether a key ended it."""
    for hangup in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(hangup, lambda *_: sys.exit(0))
    # select() retries after a signal (PEP 475), so SIGWINCH has to wake it through this pipe.
    wake_read, wake_write = os.pipe()
    os.set_blocking(wake_write, False)
    signal.set_wakeup_fd(wake_write)
    signal.signal(signal.SIGWINCH, lambda *_: None)

    def pieces_at(position, geometry):
        return placements(tiles, view_top(position, geometry), geometry.crop_h, geometry.rows)

    saved = termios.tcgetattr(fd)
    tty.setraw(fd)
    try:
        # Autowrap off so the footer cannot scroll the screen, whatever the width of its characters.
        sys.stdout.write("\x1b[?1049h\x1b[?25l\x1b[?7l\x1b[?1000h\x1b[?1006h\x1b[H\x1b[2J")
        sys.stdout.flush()

        status = None
        deadline = None
        shown = target = 0
        direction = 1
        loaded = set()
        placed = set()
        uploading = None
        chunks = None
        pending = b""
        pending_since = 0
        last_winsize = None
        last_frame = None
        last_tick = time.monotonic()
        while True:
            winsize = read_winsize(fd)
            geometry = layout(image_size, winsize)
            now = time.monotonic()

            current = sorted({piece.tile for piece in pieces_at(shown, geometry)})
            destination = sorted({piece.tile for piece in pieces_at(target, geometry)})
            jump = abs(target - shown) * geometry.max_top > EASE_MAX_VIEWS * geometry.crop_h
            hold = tiles_to_hold(
                tiles, needed_tiles(current, destination, jump, direction), direction, image_size[0], uploading
            )

            blocked = False
            if shown != target and status == OK and now - last_tick >= FRAME:
                span = geometry.max_top / geometry.pixel
                step = target if jump else ease_toward(shown, target, min(now - last_tick, 2 * FRAME), span)
                last_tick = now
                # Waiting for a tile beats drawing the pane with a hole in it.
                if {piece.tile for piece in pieces_at(step, geometry)} <= loaded:
                    shown = step
                else:
                    blocked = True

            pieces = [piece for piece in pieces_at(shown, geometry) if piece.tile in loaded]
            if status != OK:
                pieces = []
            footer = footer_text(name, real_size, geometry, shown, status, winsize[1])
            frame = (winsize, pieces, status, footer)
            if frame != last_frame:
                on_screen = {piece.tile for piece in pieces}
                draw(pieces, geometry, image_size[0], winsize, placed - on_screen, footer, winsize != last_winsize)
                placed = on_screen
                last_winsize, last_frame = winsize, frame

            if uploading is None:
                for image in loaded - set(hold):
                    sys.stdout.write(f"\x1b_Ga=d,d=I,i={image + 1},q=2\x1b\\")
                    sys.stdout.flush()
                    loaded.discard(image)
                    placed.discard(image)
                missing = [image for image in hold if image not in loaded]
                if missing:
                    uploading = missing[0]
                    chunks = upload(paths[uploading], uploading)
            if uploading is not None:
                out = sys.stdout.buffer
                for _ in range(UPLOAD_BATCH):
                    chunk = next(chunks, None)
                    if chunk is None:
                        loaded.add(uploading)
                        uploading = None
                        last_frame = None
                        if deadline is None:
                            deadline = time.monotonic() + REPLY_TIMEOUT
                        break
                    out.write(chunk)
                out.flush()

            waits = []
            if pending:
                waits.append(ESC_TIMEOUT)
            if status is None and deadline is not None:
                waits.append(max(deadline - time.monotonic(), 0))
            if shown != target and status == OK:
                waits.append(0 if blocked and uploading is not None else max(last_tick + FRAME - time.monotonic(), 0))
            elif uploading is not None:
                waits.append(0)
            wait = min(waits) if waits else None
            ready = select.select([fd, wake_read], [], [], wait)[0]

            if wake_read in ready:
                os.read(wake_read, 4096)
            if status is None and deadline is not None and time.monotonic() >= deadline:
                status = "no reply from terminal"
                report(status)
            if fd in ready:
                data = os.read(fd, 4096)
                if not data:
                    return False
                tokens, pending = parse_input(pending + data)
                pending_since = time.monotonic()
            elif pending and time.monotonic() - pending_since >= ESC_TIMEOUT:
                tokens, pending = ([pending] if pending == b"\x1b" else []), b""
            else:
                tokens = []

            for token in tokens:
                if token.startswith(b"\x1b_G"):
                    reply = token[3:-2].split(b";", 1)[-1].decode(errors="replace")
                    if status is None:
                        report(reply)
                    if status is None or reply != OK:
                        status = reply
                elif token in QUIT:
                    return True
                else:
                    moved = scrolled(target, token, geometry)
                    if moved != target:
                        direction = 1 if moved > target else -1
                        if shown == target:
                            last_tick = time.monotonic() - FRAME
                        target = moved
    finally:
        try:
            sys.stdout.write("\x1b_Ga=d,d=A,q=2\x1b\\\x1b[?1006l\x1b[?1000l\x1b[?7h\x1b[?25h\x1b[?1049l")
            sys.stdout.flush()
            termios.tcsetattr(fd, termios.TCSADRAIN, saved)
        except OSError:
            pass


def view(path, agent_block):
    name = os.path.basename(path)
    with tempfile.TemporaryDirectory(prefix="show-image-") as scratch:
        try:
            real_size, image_size, tiles, paths = prepare(path, scratch)
        except (OSError, subprocess.CalledProcessError) as error:
            report(f"could not read {name}: {error}")
            return
        by_key = show(sys.stdin.fileno(), name, real_size, image_size, tiles, paths)
    if by_key and block_exists(agent_block):
        focus_block(agent_block)


def block_exists(block):
    return subprocess.run(["rex", "block", "inspect", block], capture_output=True).returncode == 0


def focus_block(block):
    subprocess.run(["rex", "focus", block], capture_output=True)


def close_block(block):
    subprocess.run(["rex", "block", "close", block], capture_output=True)


def close_previous_viewer(state_file):
    try:
        with open(state_file) as saved:
            previous = saved.read().strip()
    except FileNotFoundError:
        return
    if previous and block_exists(previous):
        close_block(previous)
    os.remove(state_file)


def wait_for_status(block):
    deadline = time.monotonic() + LAUNCH_TIMEOUT
    path = status_path(block)
    while time.monotonic() < deadline:
        try:
            with open(path) as source:
                status = source.read()
        except FileNotFoundError:
            status = ""
        if status:
            os.remove(path)
            return status
        if not block_exists(block):
            return "the viewer exited before the terminal replied"
        time.sleep(0.1)
    return "timed out waiting for the viewer"


def launch(path):
    path = os.path.abspath(path)
    if not os.path.isfile(path):
        sys.exit(f"No such file: {path}")
    agent_block = os.environ.get("REX_BLOCK")
    if not agent_block or not os.environ.get("REX_SESSION"):
        sys.exit("REX_BLOCK and REX_SESSION are not set: this only works inside a Rex terminal")

    os.makedirs(STATE_DIR, exist_ok=True)
    state_file = os.path.join(STATE_DIR, f"{agent_block}.viewer")
    close_previous_viewer(state_file)

    created = subprocess.run(
        [
            "rex", "split", "--split", "right", "--ratio", "50", "--shell=none",
            "--label", os.path.basename(path)[:128], "-b", agent_block,
            "--", sys.executable, os.path.abspath(__file__), "--view", path, agent_block,
        ],
        check=True, capture_output=True, text=True,
    )
    block = created.stdout.split()[-1]
    with open(state_file, "w") as saved:
        saved.write(block)
    # rex split ignores --ratio; a move applies it.
    subprocess.run(
        ["rex", "block", "move", block, "right", agent_block, "--ratio", "50"], capture_output=True
    )

    status = wait_for_status(block)
    if status == OK:
        print(f"Shown in a pane: {path}")
        return
    close_block(block)
    focus_block(agent_block)
    os.remove(state_file)
    sys.exit(f"Terminal did not draw {path}: {status}")


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--view":
        view(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 2:
        launch(sys.argv[1])
    else:
        sys.exit("Usage: show_image.py IMAGE_PATH")
