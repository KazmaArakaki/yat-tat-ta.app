#!/usr/bin/env python3
"""X のアプリ専用アカウントのアイコンとヘッダーを書き出す

    python3 Design/x_profile.py

できあがりは Design/Reels/x-profile/（Git には入れない）。
アイコンはアプリアイコンと同じ絵（X が丸く切り抜く）。ヘッダーは、しゃがんだスクワットマンの隊列。
プロフィールの文は docs/devops/sns-marketing#account。
"""
import subprocess
import tempfile
from pathlib import Path

from compose_reel import FPS, PAPER, make_icon

HERE = Path(__file__).resolve().parent
OUT = HERE / "Reels" / "x-profile"
# X のヘッダーの大きさ。下の左にアイコンが重なる
HEADER = (1500, 500)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        icon = make_icon(work)
        subprocess.run(["magick", str(work / "icon-flat.png"), "-resize", "400x400", str(OUT / "icon.png")], check=True)
        # 1回の動きを36枚で描き、しゃがみきったところ（真ん中の1枚）を使う
        squad = work / "squad"
        subprocess.run(["swift", str(HERE / "reel_squad.swift"), str(squad), str(HEADER[0]), str(HEADER[1]),
                        "squat", str(round(1.2 * FPS))], check=True)
        subprocess.run(["magick", "-size", f"{HEADER[0]}x{HEADER[1]}", f"xc:#{PAPER[2:]}",
                        str(squad / "018.png"), "-composite", str(OUT / "header.png")], check=True)
    print(f"できた: {OUT}/icon.png, header.png")


if __name__ == "__main__":
    main()
