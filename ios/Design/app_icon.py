#!/usr/bin/env python3
"""アプリアイコン（ロゴのマーク）の層を SVG で書き出す

人形の点は ios/YatTatTa/Home/SquatStageView.swift の SquatterLayer.squat と同じ。
人形を直したら、このファイルの SQUAT も直して実行し直す。

    python3 ios/Design/app_icon.py

書き出す先は ios/YatTatTa/AppIcon.icon/Assets/。地の色と、暗い配色での色の差し替えは
AppIcon.icon/icon.json に書く（Icon Composer で開いて直してもよい）。
"""
from pathlib import Path

# しゃがんだ姿。つま先、足首、膝、腰、肩 / 肩、肘、手 / 頭
SQUAT_LEGS = [(12, 0), (0, 0), (15, -15), (-7, -25), (3, -55)]
SQUAT_ARM = [(3, -55), (17, -55), (31, -56)]
SQUAT_HEAD = (7, -69)

INK = "#1C1916"
DOPA = "#E5337A"

# 1024 四方の中の置き場所。点1つぶんの大きさ K、かかとの位置 (X, Y)
K = 7.6
X = 512 - 12 * K
Y = 770
# ずらした影。右下へ
SHADOW = (14, 22)

OUT = Path(__file__).resolve().parent.parent / "YatTatTa" / "AppIcon.icon" / "Assets"


def svg(body: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">{body}</svg>\n'


def doll(dx: float, dy: float, body: str, outline: str | None) -> str:
    pt = lambda p: f"{X + dx + p[0] * K:.1f},{Y + dy + p[1] * K:.1f}"
    d = "M" + "L".join(map(pt, SQUAT_LEGS)) + "M" + "L".join(map(pt, SQUAT_ARM))
    hx, hy = X + dx + SQUAT_HEAD[0] * K, Y + dy + SQUAT_HEAD[1] * K
    cap = 'fill="none" stroke-linecap="round" stroke-linejoin="round"'
    s = ""
    if outline:
        s += f'<path d="{d}" {cap} stroke="{outline}" stroke-width="{15 * K:.1f}"/>'
        s += f'<circle cx="{hx:.1f}" cy="{hy:.1f}" r="{12 * K:.1f}" fill="{outline}"/>'
    s += f'<path d="{d}" {cap} stroke="{body}" stroke-width="{9 * K:.1f}"/>'
    s += f'<circle cx="{hx:.1f}" cy="{hy:.1f}" r="{8.5 * K:.1f}" fill="{body}"/>'
    return s


def ring() -> str:
    # 塗りだけで描く（icon.json の fill で色を差し替えられるように、線ではなく穴あきの楕円）
    cx, cy, rx, ry, w = X + 8 * K, Y + 40, 300, 70, 13
    e = lambda a, b: f"M{cx - a:.1f},{cy:.1f}a{a},{b} 0 1,0 {2 * a},0a{a},{b} 0 1,0 {-2 * a},0Z"
    return f'<path fill-rule="evenodd" fill="{INK}" opacity=".9" d="{e(rx + w, ry + w)}{e(rx - w, ry - w)}"/>'


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    layers = {
        "ring.svg": ring(),
        "shadow.svg": doll(*SHADOW, INK, INK),
        "doll.svg": doll(0, 0, DOPA, INK),
    }
    for name, body in layers.items():
        (OUT / name).write_text(svg(body))
        print(OUT / name)


if __name__ == "__main__":
    main()
