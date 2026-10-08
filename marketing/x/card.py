#!/usr/bin/env python3
"""X に貼る画像（カード）を描く

広報担当AI の下書きに付ける画像。AI の画像生成は使わず、アプリと同じスクワットマンの絵
（ios/Design/reel_squad.swift）と、文字だけで描く。決まり事は docs/devops/x-operator#images。

    python3 marketing/x/card.py <カードの JSON> <書き出す PNG>

カードの JSON：
    {
      "headline": "30回。",                         大きな見出し。1行
      "lines": ["…", "…"],                          本文。1要素が1段落で、幅で折り返す
      "note": "健康な成人男性15人／Nagasaki ら 2021",   左下の小さな文字。研究なら対象と出典
      "pose": "squat"                               右のスクワットマン。squat、lie、none
    }
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SQUAD = ROOT / "ios" / "Design" / "reel_squad.swift"
# X のタイムラインで切り取られずに出る 16:9
W, H = 1200, 675
SIDE = 300
PAD = 64
PAPER = "#FBF6EE"
INK = "#1C1916"
MUTE = "#6E655C"
DOPA = "#E5337A"
BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
MID = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"


def main() -> None:
    card = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    out = Path(sys.argv[2])
    pose = card.get("pose", "squat")
    text_w = W - PAD * 2 - (SIDE if pose != "none" else 0)
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        command = ["magick", "-size", f"{W}x{H}", f"xc:{PAPER}",
                   "-fill", DOPA, "-draw", f"rectangle 0,0 14,{H}"]
        if pose != "none":
            # 1回の動きを36枚で描き、真ん中の1枚を使う。寝ている姿は1枚だけ
            subprocess.run(["swift", str(SQUAD), str(work / "squad"), str(SIDE), str(H), pose, "36"],
                           check=True, capture_output=True)
            frame = work / "squad" / ("000.png" if pose == "lie" else "018.png")
            command += [str(frame), "-geometry", f"+{W - SIDE}+0", "-composite"]
        # 見出し、本文、注記を、それぞれ幅で折り返した画像にしてから重ねる
        y = PAD
        blocks = [(card["headline"], BOLD, 120, INK, 24)]
        blocks += [(line, MID, 40, INK, 18) for line in card.get("lines", [])]
        for i, (text, font, size, color, gap) in enumerate(blocks):
            path = work / f"block{i}.png"
            subprocess.run(["magick", "-background", "none", "-fill", color, "-font", font,
                            "-pointsize", str(size), "-size", f"{text_w}x", f"caption:{text}", str(path)], check=True)
            height = int(subprocess.run(["magick", "identify", "-format", "%h", str(path)],
                                        check=True, capture_output=True, text=True).stdout)
            command += [str(path), "-geometry", f"+{PAD}+{y}", "-composite"]
            y += height + gap
        if card.get("note"):
            note = work / "note.png"
            subprocess.run(["magick", "-background", "none", "-fill", MUTE, "-font", MID, "-pointsize", "26",
                            "-size", f"{text_w}x", f"caption:{card['note']}", str(note)], check=True)
            height = int(subprocess.run(["magick", "identify", "-format", "%h", str(note)],
                                        check=True, capture_output=True, text=True).stdout)
            if y > H - PAD - height:
                sys.exit(f"error: 文字が多すぎて注記と重なる（本文の下端 {y}px）。本文を短くする")
            command += [str(note), "-geometry", f"+{PAD}+{H - PAD - height}", "-composite"]
        out.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(command + [str(out)], check=True)
    print(f"できた: {out}")


if __name__ == "__main__":
    main()
