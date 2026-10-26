"""Render the small Binder mark as installable PNG icons using only Python's stdlib."""

import struct
import sys
import zlib
from pathlib import Path


def rounded_rect(x, y, left, top, right, bottom, radius):
    cx = min(max(x, left + radius), right - radius)
    cy = min(max(y, top + radius), bottom - radius)
    return (x - cx) ** 2 + (y - cy) ** 2 <= radius**2


def segment(x, y, x1, y1, x2, y2, radius):
    dx, dy = x2 - x1, y2 - y1
    length = dx * dx + dy * dy
    position = max(0, min(1, ((x - x1) * dx + (y - y1) * dy) / length)) if length else 0
    return (x - (x1 + position * dx)) ** 2 + (y - (y1 + position * dy)) ** 2 <= radius**2


def polygon_contains(x, y, points):
    inside = False
    previous = points[-1]
    for current in points:
        x1, y1 = previous
        x2, y2 = current
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            inside = not inside
        previous = current
    return inside


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def render(size):
    scale = 2
    side = size * scale
    background = (44, 111, 104, 255)
    white = (255, 255, 255, 250)
    pale = (215, 233, 230, 255)
    coral = (242, 123, 104, 255)
    hi = bytearray(background * (side * side))

    binder = (125 * scale, 105 * scale, 363 * scale, 407 * scale, 38 * scale)
    for y in range(binder[1], binder[3]):
        for x in range(binder[0], binder[2]):
            if rounded_rect(x + .5, y + .5, *binder):
                offset = (y * side + x) * 4
                hi[offset:offset + 4] = bytes(white)

    spine_x = 180 * scale
    for y in range(122 * scale, 390 * scale):
        for x in range(170 * scale, 191 * scale):
            if segment(x + .5, y + .5, spine_x, 122 * scale, spine_x, 390 * scale, 10 * scale):
                offset = (y * side + x) * 4
                hi[offset:offset + 4] = bytes(background)

    for cy in (190, 258, 326):
        for y in range((cy - 10) * scale, (cy + 10) * scale):
            for x in range(170 * scale, 191 * scale):
                if (x - spine_x) ** 2 + (y - cy * scale) ** 2 <= (10 * scale) ** 2:
                    offset = (y * side + x) * 4
                    hi[offset:offset + 4] = bytes(white)

    for y in range(side):
        for x in range(224 * scale, 316 * scale):
            if any(segment(x, y, 224 * scale, line_y * scale, 315 * scale, line_y * scale, 9 * scale) for line_y in (195, 246)):
                offset = (y * side + x) * 4
                hi[offset:offset + 4] = bytes(pale)
        if y in range(288 * scale, 307 * scale):
            for x in range(224 * scale, 291 * scale):
                if segment(x, y, 224 * scale, 297 * scale, 290 * scale, 297 * scale, 9 * scale):
                    offset = (y * side + x) * 4
                    hi[offset:offset + 4] = bytes(pale)

    roof = [(273, 355), (297, 327), (321, 355), (351, 318), (351, 375), (273, 375)]
    roof = [(x * scale, y * scale) for x, y in roof]
    for y in range(318 * scale, 376 * scale):
        for x in range(273 * scale, 352 * scale):
            if polygon_contains(x + .5, y + .5, roof):
                offset = (y * side + x) * 4
                hi[offset:offset + 4] = bytes(coral)

    pixels = bytearray(size * size * 4)
    for y in range(size):
        for x in range(size):
            samples = [hi[((y * 2 + sy) * side + x * 2 + sx) * 4:((y * 2 + sy) * side + x * 2 + sx) * 4 + 4]
                       for sy in range(2) for sx in range(2)]
            offset = (y * size + x) * 4
            pixels[offset:offset + 4] = bytes(sum(sample[channel] for sample in samples) // 4 for channel in range(4))

    rows = b"".join(b"\0" + pixels[y * size * 4:(y + 1) * size * 4] for y in range(size))
    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", header) + png_chunk(b"IDAT", zlib.compress(rows, 9)) + png_chunk(b"IEND", b"")


output = Path(__file__).parent
for icon_size in (192, 512):
    (output / f"binder-{icon_size}.png").write_bytes(render(icon_size))
