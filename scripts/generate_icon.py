#!/usr/bin/env python3
"""Generate a simple macOS app icon: dark tile, scan brackets, face hint."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path


def write_png(path: Path, size: int, rgba: bytes) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = b""
    stride = size * 4
    for y in range(size):
        raw += b"\x00" + rgba[y * stride : (y + 1) * stride]
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))  # type: ignore[return-value]


def draw_icon(size: int) -> bytes:
    px = bytearray(size * size * 4)
    mid = (size - 1) / 2
    radius = size * 0.22
    inner = size * 0.18

    def set_px(x: int, y: int, r: int, g: int, b: int, a: int = 255) -> None:
        if 0 <= x < size and 0 <= y < size:
            i = (y * size + x) * 4
            px[i : i + 4] = bytes((r, g, b, a))

    def rounded_mask(x: int, y: int) -> float:
        # Superellipse-ish rounded rect in 0..1 coverage
        nx = (x + 0.5) / size
        ny = (y + 0.5) / size
        pad = 0.08
        rx, ry = nx * 2 - 1, ny * 2 - 1
        # Map to rounded square
        corner = 0.62
        ax, ay = abs(rx), abs(ry)
        if ax > 1 or ay > 1:
            return 0
        # Distance outside rounded rect
        cx = max(ax - (1 - corner), 0)
        cy = max(ay - (1 - corner), 0)
        d = math.hypot(cx, cy) / corner if corner else 0
        edge = 1 - d
        # Soft outer padding
        if nx < pad or ny < pad or nx > 1 - pad or ny > 1 - pad:
            border = min(nx, ny, 1 - nx, 1 - ny) / pad
            return max(0.0, min(edge, border))
        return max(0.0, min(1.0, edge * 6))

    bg = (18, 18, 22)
    accent = (230, 230, 235)
    green = (52, 199, 89)

    for y in range(size):
        for x in range(size):
            cover = rounded_mask(x, y)
            if cover <= 0:
                set_px(x, y, 0, 0, 0, 0)
                continue
            # Subtle vertical gradient
            t = (y / size) * 0.25
            r, g, b = mix(bg, (36, 36, 42), t)
            set_px(x, y, r, g, b, int(255 * min(1, cover)))

    def ring(cx: float, cy: float, rad: float, width: float, color: tuple[int, int, int], arc: bool = False) -> None:
        for y in range(size):
            for x in range(size):
                dx = x + 0.5 - cx
                dy = y + 0.5 - cy
                dist = math.hypot(dx, dy)
                if abs(dist - rad) <= width:
                    if arc:
                        ang = math.atan2(dy, dx)
                        # four gaps like classic Face ID brackets
                        sector = abs((ang + math.pi) % (math.pi / 2) - math.pi / 4)
                        if sector < 0.28:
                            continue
                    i = (y * size + x) * 4
                    if px[i + 3] < 8:
                        continue
                    px[i] = color[0]
                    px[i + 1] = color[1]
                    px[i + 2] = color[2]

    cx = cy = mid
    ring(cx, cy, size * 0.28, max(1.2, size * 0.018), accent, arc=True)
    ring(cx, cy, size * 0.20, max(1.0, size * 0.014), mix(accent, green, 0.35), arc=True)

    # Eyes + smile
    eye_y = cy - size * 0.04
    for ex in (cx - size * 0.07, cx + size * 0.07):
        for y in range(size):
            for x in range(size):
                if math.hypot(x + 0.5 - ex, y + 0.5 - eye_y) <= size * 0.018:
                    i = (y * size + x) * 4
                    if px[i + 3] > 8:
                        px[i : i + 3] = bytes(accent)

    for y in range(size):
        for x in range(size):
            dx = (x + 0.5 - cx) / (size * 0.09)
            dy = (y + 0.5 - (cy + size * 0.06)) / (size * 0.05)
            if 0.7 <= dx * dx + dy * dy <= 1.05 and dy > 0:
                i = (y * size + x) * 4
                if px[i + 3] > 8:
                    px[i : i + 3] = bytes(accent)

    return bytes(px)


def main() -> None:
    out = Path(__file__).resolve().parents[1] / "MacBookFaceID/MacBookFaceID/Resources/Assets.xcassets/AppIcon.appiconset"
    out.mkdir(parents=True, exist_ok=True)
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in sizes:
        write_png(out / f"icon_{s}.png", s, draw_icon(s))
    (out / "Contents.json").write_text(
        """{
  "images" : [
    { "idiom" : "mac", "size" : "16x16", "scale" : "1x", "filename" : "icon_16.png" },
    { "idiom" : "mac", "size" : "16x16", "scale" : "2x", "filename" : "icon_32.png" },
    { "idiom" : "mac", "size" : "32x32", "scale" : "1x", "filename" : "icon_32.png" },
    { "idiom" : "mac", "size" : "32x32", "scale" : "2x", "filename" : "icon_64.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "1x", "filename" : "icon_128.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "2x", "filename" : "icon_256.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "1x", "filename" : "icon_256.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "2x", "filename" : "icon_512.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "1x", "filename" : "icon_512.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "2x", "filename" : "icon_1024.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""",
        encoding="utf-8",
    )
    print(f"Wrote icons to {out}")


if __name__ == "__main__":
    main()
