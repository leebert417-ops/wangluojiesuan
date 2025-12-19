from __future__ import annotations

"""
SVG -> PNG 转换脚本（命令行）。

用法：
  python svg_to_png.py input.svg
  python svg_to_png.py input.svg output.png
  python svg_to_png.py input.svg --width 512
  python svg_to_png.py input.svg --height 512
  python svg_to_png.py input.svg --dpi 300

可用后端（按优先级自动选择）：
  1) Inkscape（推荐）：确保 `inkscape` 在 PATH 中
  2) ImageMagick：确保 `magick` 在 PATH 中
  3) librsvg：确保 `rsvg-convert` 在 PATH 中
  4) CairoSVG：`pip install cairosvg`（Windows 可能还需要 Cairo 运行时）

说明：
  - 若检测到多个后端，按上面顺序使用第一个。
  - ImageMagick 可通过 `--background none|white|...` 指定背景色。
"""

import argparse
import shutil
import subprocess
from pathlib import Path


def _which(cmd: str) -> str | None:
    return shutil.which(cmd)


def _run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def convert_svg_to_png(
    svg_path: Path,
    png_path: Path,
    *,
    width: int | None = None,
    height: int | None = None,
    dpi: int | None = None,
    background: str = "none",
) -> None:
    svg_path = svg_path.resolve()
    png_path = png_path.resolve()

    if not svg_path.is_file():
        raise FileNotFoundError(f"SVG not found: {svg_path}")

    png_path.parent.mkdir(parents=True, exist_ok=True)

    inkscape = _which("inkscape")
    if inkscape:
        cmd = [
            inkscape,
            str(svg_path),
            "--export-type=png",
            f"--export-filename={png_path}",
        ]
        if dpi is not None:
            cmd.append(f"--export-dpi={dpi}")
        if width is not None:
            cmd.append(f"--export-width={width}")
        if height is not None:
            cmd.append(f"--export-height={height}")
        _run(cmd)
        return

    magick = _which("magick")
    if magick:
        cmd = [magick, "-background", background]
        if dpi is not None:
            cmd += ["-density", str(dpi)]
        cmd.append(str(svg_path))
        if width is not None or height is not None:
            if width is None:
                size = f"x{height}"
            elif height is None:
                size = f"{width}x"
            else:
                size = f"{width}x{height}"
            cmd += ["-resize", size]
        cmd.append(str(png_path))
        _run(cmd)
        return

    rsvg = _which("rsvg-convert")
    if rsvg:
        cmd = [rsvg, "-o", str(png_path)]
        if width is not None:
            cmd += ["-w", str(width)]
        if height is not None:
            cmd += ["-h", str(height)]
        cmd.append(str(svg_path))
        _run(cmd)
        return

    try:
        import cairosvg  # type: ignore

        kwargs: dict[str, object] = {
            "url": str(svg_path),
            "write_to": str(png_path),
        }
        if width is not None:
            kwargs["output_width"] = int(width)
        if height is not None:
            kwargs["output_height"] = int(height)
        if dpi is not None:
            kwargs["dpi"] = int(dpi)
        cairosvg.svg2png(**kwargs)
        return
    except Exception:
        pass

    raise RuntimeError(
        "No SVG->PNG backend found. Install one of:\n"
        "- Inkscape (recommended): ensure `inkscape` is on PATH\n"
        "- ImageMagick: ensure `magick` is on PATH\n"
        "- librsvg: ensure `rsvg-convert` is on PATH\n"
        "- CairoSVG: `pip install cairosvg` (may need Cairo runtime on Windows)\n"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Convert SVG to PNG.")
    parser.add_argument("svg", type=Path, help="Input .svg path")
    parser.add_argument(
        "png",
        type=Path,
        nargs="?",
        help="Output .png path (default: same name next to input)",
    )
    parser.add_argument("--width", type=int, default=None, help="Output width (px)")
    parser.add_argument("--height", type=int, default=None, help="Output height (px)")
    parser.add_argument("--dpi", type=int, default=None, help="Rasterization DPI")
    parser.add_argument(
        "--background",
        default="none",
        help="Background for ImageMagick backend (e.g. 'none' or 'white')",
    )
    args = parser.parse_args(argv)

    svg_path: Path = args.svg
    png_path: Path = args.png if args.png else svg_path.with_suffix(".png")

    convert_svg_to_png(
        svg_path,
        png_path,
        width=args.width,
        height=args.height,
        dpi=args.dpi,
        background=str(args.background),
    )
    print(png_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
