#!/usr/bin/env python3
"""Generate the original Voxel Boroughs raster branding assets.

SPDX-License-Identifier: MIT
Generated artwork: CC BY 4.0, n30nex and Voxel Boroughs contributors.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "games" / "voxel_boroughs"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else
             "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def cube(draw: ImageDraw.ImageDraw, center: tuple[int, int], size: int, height: int,
         top: str, left: str, right: str) -> None:
    x, y = center
    half = size // 2
    draw.polygon([(x, y - half), (x + size, y), (x, y + half), (x - size, y)], fill=top)
    draw.polygon([(x - size, y), (x, y + half), (x, y + half + height),
                  (x - size, y + height)], fill=left)
    draw.polygon([(x + size, y), (x, y + half), (x, y + half + height),
                  (x + size, y + height)], fill=right)


def make_icon(size: int = 1024) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((32, 32, size - 32, size - 32), radius=180, fill="#14272F")
    cube(draw, (size // 2, 360), 330, 245, "#82BD73", "#4F8054", "#365F48")
    cube(draw, (430, 300), 118, 235, "#E8D9AA", "#B78F68", "#8D6A56")
    cube(draw, (645, 440), 82, 145, "#85BCE0", "#5E8DB1", "#416F91")
    draw.line((238, 490, 762, 490), fill="#F1DF8E", width=20)
    return image


def make_background() -> Image.Image:
    width, height = 1920, 1080
    image = Image.new("RGB", (width, height), "#102027")
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / (height - 1)
        color = tuple(int(a + (b - a) * t) for a, b in zip((31, 53, 63), (10, 23, 29)))
        draw.line((0, y, width, y), fill=color)
    horizon = 650
    for step in range(-16, 17):
        draw.line((960, horizon, 960 + step * 145, height), fill="#31515B", width=2)
    for row in range(9):
        y = horizon + row * row * 6
        draw.line((0, y, width, y), fill="#31515B", width=2)
    cube(draw, (500, 545), 135, 230, "#D7A786", "#A77B62", "#825D4C")
    cube(draw, (760, 500), 175, 340, "#72A9CC", "#507F9B", "#365F77")
    cube(draw, (1150, 555), 150, 250, "#B89A66", "#8B754E", "#66563D")
    cube(draw, (1425, 610), 105, 145, "#85BCE0", "#5E8DB1", "#416F91")
    return image


def main() -> None:
    icon = make_icon()
    icon.resize((128, 128), Image.Resampling.LANCZOS).save(ROOT / "misc" / "voxel-boroughs.png")
    icon.resize((256, 256), Image.Resampling.LANCZOS).save(
        ROOT / "misc" / "voxel-boroughs-icon.ico",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    icon.resize((192, 192), Image.Resampling.LANCZOS).save(GAME / "menuicon.png")

    background = make_background()
    background.save(GAME / "background.png", optimize=True)

    header = Image.new("RGBA", (1024, 256), "#14272F")
    header.alpha_composite(icon.resize((220, 220), Image.Resampling.LANCZOS), (18, 18))
    header_draw = ImageDraw.Draw(header)
    header_draw.text((245, 57), "VOXEL BOROUGHS", fill="#F4F1E8", font=font(70, True))
    header_draw.text((250, 147), "BUILD A LIVING CITY, ONE DISTRICT AT A TIME",
                     fill="#82BD73", font=font(24, True))
    header.save(GAME / "header.png", optimize=True)


if __name__ == "__main__":
    main()

