"""
生成通风网络“无文字”图标（SVG），可选转 PNG。

输出内容：
  - 节点：小圆点（入风节点为绿色样式、回风节点为红色样式）
  - 巷道：加粗线段（普通巷道为灰色；入风/回风巷道为绿/红）
  - 不包含任何文字（无节点ID/巷道ID/标题/图例）

用法：
  仅生成 SVG：
    python Icon_Drawing.py
    python Icon_Drawing.py --svg-out NetworkSolverApp_network_notext.svg

  生成 SVG 并转 PNG（需要安装任意一个后端，见 svg_to_png.py 说明）：
    python Icon_Drawing.py --png
    python Icon_Drawing.py --png --png-dpi 300
    python Icon_Drawing.py --svg-out out.svg --png --png-out out.png --png-width 512
"""

from math import cos, sin, pi
from pathlib import Path
import argparse

def svg_header(w, h):
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <defs>
    <style><![CDATA[
      .edge {{ stroke: #374151; stroke-width: 30; stroke-linecap: round; }}
      .edge-in {{ stroke: #16a34a; stroke-width: 36; stroke-linecap: round; }}
      .edge-out {{ stroke: #dc2626; stroke-width: 36; stroke-linecap: round; }}
      .node {{ fill: #e0f2fe; stroke: #1d4ed8; stroke-width: 2; }}
      .node-in {{ fill: #dcfce7; stroke: #16a34a; stroke-width: 2; }}
      .node-out {{ fill: #fee2e2; stroke: #dc2626; stroke-width: 2; }}
    ]]></style>
  </defs>
'''
def svg_footer():
    return "</svg>\n"

def line(x1, y1, x2, y2, klass):
    return f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" class="{klass}"/>\n'

def circle(cx, cy, r, klass):
    return f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" class="{klass}"/>\n'

def main(out_path="NetworkSolverApp_network_notext.svg"):
    W, H = 520, 520
    cx, cy = 260, 260
    R = 170
    node_r = 24
    boundary_len = 60  # 入/回风巷道长度（更短可调小）

    nodes = {}
    for i in range(1, 7):
        ang = (i - 1) * (2 * pi / 6) - pi / 2
        nodes[i] = (cx + R * cos(ang), cy + R * sin(ang))

    branches = [
        (1, 2),
        (2, 3),
        (3, 4),
        (4, 5),
        (5, 6),
        (6, 1),
        (2, 5),
    ]

    inlet_nodes = [1]
    outlet_nodes = [4]

    svg = [svg_header(W, H)]

    for u, v in branches:
        x1, y1 = nodes[u]
        x2, y2 = nodes[v]
        svg.append(line(x1, y1, x2, y2, "edge"))

    # 入风巷道：在入风节点上方画一段竖直短线
    for n in inlet_nodes:
        x, y = nodes[n]
        svg.append(line(x, y - node_r - boundary_len, x, y - node_r, "edge-in"))

    # 回风巷道：在回风节点下方画一段竖直短线
    for n in outlet_nodes:
        x, y = nodes[n]
        svg.append(line(x, y + node_r, x, y + node_r + boundary_len, "edge-out"))

    for i, (x, y) in nodes.items():
        klass = "node"
        if i in inlet_nodes:
            klass = "node-in"
        if i in outlet_nodes:
            klass = "node-out"
        svg.append(circle(x, y, node_r, klass))

    svg.append(svg_footer())

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("".join(svg))

    print(f"Wrote: {out_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate a ventilation-network SVG icon (no text).")
    parser.add_argument("--svg-out", default="NetworkSolverApp_network_notext.svg", help="Output SVG path")
    parser.add_argument("--png", action="store_true", help="Also convert SVG to PNG (requires a backend)")
    parser.add_argument("--png-out", default="", help="Output PNG path (default: same name as SVG)")
    parser.add_argument("--png-width", type=int, default=None, help="PNG width (px)")
    parser.add_argument("--png-height", type=int, default=None, help="PNG height (px)")
    parser.add_argument("--png-dpi", type=int, default=None, help="Rasterization DPI")
    args = parser.parse_args()

    svg_out = Path(args.svg_out)
    main(str(svg_out))

    if args.png:
        from svg_to_png import convert_svg_to_png

        png_out = Path(args.png_out) if args.png_out else svg_out.with_suffix(".png")
        convert_svg_to_png(
            svg_out,
            png_out,
            width=args.png_width,
            height=args.png_height,
            dpi=args.png_dpi,
        )
        print(f"Wrote: {png_out}")
