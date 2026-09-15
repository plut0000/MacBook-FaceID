#!/usr/bin/env python3
"""Raster assets for the GitHub Pages site (favicon, apple-touch, og-image).

Mark: a tiny MacBook lid with a hardware notch and a green status light.
Intentionally not Apple Face ID brackets and not a gradient face.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
IMG = DOCS / "assets" / "img"
FONT_DIR = Path("/usr/share/fonts/truetype/macos")

INK = (28, 28, 30, 255)
SCREEN = (10, 10, 12, 255)
BEZEL = (58, 58, 60, 255)
GREEN = (48, 209, 88, 255)
WHITE = (245, 245, 247, 255)
MUTED = (161, 161, 166, 255)
OG_BG = (14, 14, 16, 255)
OG_CARD = (24, 24, 26, 255)


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    path = FONT_DIR / name
    if not path.exists():
        return ImageFont.load_default()
    return ImageFont.truetype(str(path), size=size)


def rounded_rect(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    radius: float,
    fill,
    outline=None,
    width: int = 1,
) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_mark(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = size * 0.06
    rounded_rect(d, (pad, pad, size - pad, size - pad), size * 0.22, INK)

    # Lid / display
    dx0, dy0 = size * 0.20, size * 0.26
    dx1, dy1 = size * 0.80, size * 0.70
    rounded_rect(d, (dx0, dy0, dx1, dy1), size * 0.06, SCREEN, outline=BEZEL, width=max(1, size // 48))

    # Hardware notch (camera housing), not Face ID brackets
    nw, nh = size * 0.22, size * 0.07
    nx0 = size / 2 - nw / 2
    rounded_rect(d, (nx0, dy0, nx0 + nw, dy0 + nh), nh / 2, INK)

    # Status light — watching / ready
    r = max(1.5, size * 0.055)
    cx, cy = size / 2, (dy0 + dy1) / 2 + size * 0.04
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GREEN)

    # Chin / hinge hint
    hx0, hx1 = size * 0.34, size * 0.66
    hy = size * 0.78
    rounded_rect(d, (hx0, hy, hx1, hy + size * 0.035), size * 0.02, BEZEL)
    return img


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG", optimize=True)


def draw_macbook(draw: ImageDraw.ImageDraw, origin: tuple[int, int], scale: float) -> None:
    x, y = origin
    w, h = int(420 * scale), int(268 * scale)
    # Shadow
    shadow = (x + 8, y + 14, x + w + 8, y + h + 18)
    draw.rounded_rectangle(shadow, radius=int(28 * scale), fill=(0, 0, 0, 70))
    # Bezel
    draw.rounded_rectangle((x, y, x + w, y + h), radius=int(26 * scale), fill=(44, 44, 46, 255))
    # Screen
    inset = int(10 * scale)
    draw.rounded_rectangle(
        (x + inset, y + inset, x + w - inset, y + h - inset - int(8 * scale)),
        radius=int(18 * scale),
        fill=(8, 8, 10, 255),
    )
    # Notch
    nw, nh = int(78 * scale), int(18 * scale)
    nx = x + w / 2 - nw / 2
    ny = y + inset
    draw.rounded_rectangle((nx, ny, nx + nw, ny + nh), radius=nh / 2, fill=(44, 44, 46, 255))
    # Expanded island
    iw, ih = int(210 * scale), int(92 * scale)
    ix = x + w / 2 - iw / 2
    iy = y + int(36 * scale)
    draw.rounded_rectangle((ix, iy, ix + iw, iy + ih), radius=int(22 * scale), fill=OG_CARD)
    # Scan ring (circle — not Face ID corner brackets)
    cx, cy = x + w / 2, iy + ih / 2
    r = int(22 * scale)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=GREEN, width=max(2, int(3 * scale)))
    r2 = int(14 * scale)
    draw.ellipse((cx - r2, cy - r2, cx + r2, cy + r2), outline=(48, 209, 88, 140), width=max(1, int(2 * scale)))
    # Check
    p1 = (cx - int(8 * scale), cy + int(1 * scale))
    p2 = (cx - int(2 * scale), cy + int(8 * scale))
    p3 = (cx + int(10 * scale), cy - int(8 * scale))
    draw.line([p1, p2, p3], fill=GREEN, width=max(2, int(3 * scale)))


def draw_og() -> Image.Image:
    w, h = 1200, 630
    img = Image.new("RGBA", (w, h), OG_BG)
    d = ImageDraw.Draw(img)

    # Soft top wash
    wash = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wash)
    wd.ellipse((-200, -260, 760, 420), fill=(48, 209, 88, 28))
    wd.ellipse((720, 80, 1400, 820), fill=(80, 80, 90, 40))
    img = Image.alpha_composite(img, wash.filter(ImageFilter.GaussianBlur(90)))
    d = ImageDraw.Draw(img)

    title = font("Inter-Bold.ttf", 64)
    sub = font("Inter-SemiBold.ttf", 32)
    body = font("Inter-Regular.ttf", 22)
    label = font("Inter-Medium.ttf", 16)

    d.text((88, 92), "OPEN SOURCE  ·  macOS 14+", font=label, fill=GREEN)
    d.text((88, 148), "MacBook FaceID", font=title, fill=WHITE)
    d.text((88, 232), "Face Unlock for Mac.", font=sub, fill=WHITE)
    d.text(
        (88, 292),
        "A notch-native scan that types the password\nyou saved. Not TrueDepth. Not Secure Enclave.",
        font=body,
        fill=MUTED,
        spacing=8,
    )
    d.text((88, 520), "plut0000.github.io/MacBook-FaceID", font=label, fill=MUTED)

    draw_macbook(d, (690, 168), 1.05)
    return img.convert("RGB")


def write_ico(path: Path, sizes: list[int]) -> None:
    source = draw_mark(256)
    source.save(path, format="ICO", sizes=[(s, s) for s in sizes])


def main() -> None:
    IMG.mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(parents=True, exist_ok=True)

    for s, name in ((16, "favicon-16.png"), (32, "favicon-32.png"), (48, "favicon-48.png")):
        save_png(draw_mark(s * 4).resize((s, s), Image.Resampling.LANCZOS), IMG / name)

    save_png(draw_mark(180 * 2).resize((180, 180), Image.Resampling.LANCZOS), DOCS / "apple-touch-icon.png")
    save_png(draw_mark(180 * 2).resize((180, 180), Image.Resampling.LANCZOS), IMG / "apple-touch-icon.png")
    save_png(draw_mark(512), IMG / "icon-512.png")

    write_ico(DOCS / "favicon.ico", [16, 32, 48])
    save_png(draw_og(), IMG / "og-image.png")

    print(f"Wrote site images under {DOCS}")


if __name__ == "__main__":
    main()
