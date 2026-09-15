#!/usr/bin/env python3
"""Generate a sharp original macOS icon: graphite tile, notch pill, hairline scan.

Not a face, not Apple Face ID brackets, not a smile.
"""

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
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))  # type: ignore[return-value]


def rounded_rect_sdf(px: float, py: float, cx: float, cy: float, hw: float, hh: float, r: float) -> float:
    dx = abs(px - cx) - (hw - r)
    dy = abs(py - cy) - (hh - r)
    outside = math.hypot(max(dx, 0.0), max(dy, 0.0))
    inside = min(max(dx, dy), 0.0)
    return outside + inside - r


def capsule_sdf(px: float, py: float, x0: float, x1: float, y: float, radius: float) -> float:
    dx = x1 - x0
    t = 0.0 if dx == 0 else max(0.0, min(1.0, (px - x0) / dx))
    return math.hypot(px - (x0 + t * dx), py - y) - radius


def coverage(sdf: float, aa: float = 0.85) -> float:
    return max(0.0, min(1.0, 0.5 - sdf / aa))


def stroke_coverage(sdf: float, half: float, aa: float = 0.85) -> float:
    return coverage(abs(sdf) - half, aa)


def blend(dst: list[int], src: tuple[int, int, int], a: float) -> None:
    if a <= 0:
        return
    a = max(0.0, min(1.0, a))
    ia = 1.0 - a
    dst[0] = int(dst[0] * ia + src[0] * a)
    dst[1] = int(dst[1] * ia + src[1] * a)
    dst[2] = int(dst[2] * ia + src[2] * a)
    dst[3] = int(min(255, dst[3] + (255 - dst[3]) * a))


def draw_icon(size: int) -> bytes:
    px = bytearray(size * size * 4)
    samples = 3 if size >= 128 else (2 if size >= 32 else 1)
    aa = max(0.55, size * 0.0028)

    tile_inset = size * 0.08
    tile_r = size * 0.205
    tile_cx = tile_cy = (size - 1) / 2
    tile_hw = tile_hh = (size - 1) / 2 - tile_inset

    # Notch pill sits in the upper third — the MacBook camera housing, not a face.
    pill_y = size * 0.40
    pill_hw = size * (0.20 if size >= 32 else 0.22)
    pill_hh = size * (0.055 if size >= 32 else 0.07)
    pill_r = pill_hh
    scan_y = size * 0.58
    scan_half = size * 0.13
    scan_w = max(0.55, size * 0.0075)

    graphite = (22, 22, 24)
    graphite_hi = (38, 38, 42)
    mark = (228, 228, 232)
    mark_dim = (168, 168, 174)

    for y in range(size):
        for x in range(size):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(samples):
                for sx in range(samples):
                    pxf = x + (sx + 0.5) / samples
                    pyf = y + (sy + 0.5) / samples
                    pixel = [0, 0, 0, 0]

                    tile = rounded_rect_sdf(pxf, pyf, tile_cx, tile_cy, tile_hw, tile_hh, tile_r)
                    tcover = coverage(tile, aa)
                    if tcover > 0:
                        shade = mix(graphite_hi, graphite, pyf / max(size, 1))
                        blend(pixel, shade, tcover)
                        # hairline rim, not a glow
                        rim = stroke_coverage(tile, 0.0, aa) * 0.22
                        blend(pixel, (255, 255, 255), rim * tcover)

                    if pixel[3] > 4:
                        pill = rounded_rect_sdf(pxf, pyf, tile_cx, pill_y, pill_hw, pill_hh, pill_r)
                        pill_line = stroke_coverage(pill, max(0.6, size * 0.008), aa)
                        blend(pixel, mark, pill_line)

                        scan = capsule_sdf(pxf, pyf, tile_cx - scan_half, tile_cx + scan_half, scan_y, scan_w)
                        blend(pixel, mark_dim, coverage(scan, aa) * 0.95)

                    acc[0] += pixel[0]
                    acc[1] += pixel[1]
                    acc[2] += pixel[2]
                    acc[3] += pixel[3]

            n = float(samples * samples)
            i = (y * size + x) * 4
            px[i : i + 4] = bytes(
                (
                    int(acc[0] / n),
                    int(acc[1] / n),
                    int(acc[2] / n),
                    int(acc[3] / n),
                )
            )

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
