#!/usr/bin/env python3
"""録った画面と音に、上の帯の文字と、終わりの画面を付けて、SNS の縦の動画にする

reel.sh から呼ぶ。直接は使わない。

    python3 Design/compose_reel.py <作業場所> <録画を始めた時刻> <書き出す先> [ja|en] [sns|lp]

作業場所には screen.mov（シミュレーターの録画）、reel.caf（アプリが書いた音）、
reel.json（音の始まりの時刻と、場面の時刻）を置いておく。
型は docs/sessions/20261007-1727-sns-marketing/x-video.html。
帯の文字は、発信の決まり事の1と2に従う（健康の効果とパチンコの語を書かない）。
"""
import json
import os
import subprocess
import sys
from pathlib import Path

W, H = 1080, 1920
# 上の帯の高さ。文字はこの中にだけ出し、アプリの画面にかぶせない
BAND = 300
FPS = 30
CARD_SECONDS = 2.5
PAPER = "0xFBF6EE"
INK = "0x1C1916"
MUTE = "0x6E655C"
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT_MID = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"

# 帯の文字。（文字, 出し始める場面, 消す場面）。場面の時刻はアプリが reel.json に書く
# LP の動画（lp）は、叩き切ったあとの共有の誘い（share）まで続く
CAPTIONS = {
    "ja": [
        ("スクワット、終わった？", "start", "tap"),
        ("1回＝1打", "tap", "chance"),
        ("叩くたびに、どんどん派手に", "chance", "fever"),
        ("FEVER！5秒間、叩き放題", "fever", "feverEnd"),
        ("最後の1打で、筋肉確定。", "feverEnd", "share"),
        ("記録は、カードで貼れる", "share", "end"),
    ],
    # 英語は1行が長くなるので、短く言い直し、文字も小さくする（CAPTION_SIZE）
    "en": [
        ("Squats done?", "start", "tap"),
        ("1 squat = 1 tap", "tap", "chance"),
        ("Each tap gets louder", "chance", "fever"),
        ("FEVER! 5 sec of tapping", "fever", "feverEnd"),
        ("Last tap: locked in!", "feverEnd", "share"),
        ("Share it as a card", "share", "end"),
    ],
}
CAPTION_SIZE = {"ja": 74, "en": 68}
# 左右の余白のスクワットマン。1回の動きの秒数。起きる前は寝ていて、フィーバーの間は速くなる
SQUAD_SECONDS = 1.2
SQUAD_FEVER_SECONDS = 0.4
CARD_TITLE = "Yat Tat Ta"
CARD_LINE = {"ja": "食べて、しゃがんで、連続タップ。", "en": "Eat, squat, tap."}

ICON_ASSETS = Path(__file__).resolve().parent.parent / "YatTatTa" / "AppIcon.icon" / "Assets"
ICON_FILL = "#E9A800"


def make_icon(work: Path) -> Path:
    """アプリアイコンの層を重ねて、角を丸めた PNG にする

    ImageMagick は SVG の線を描けないので、Quick Look で1枚ずつ PNG にしてから重ねる。
    重ねる順と地の色は AppIcon.icon/icon.json と同じ。
    """
    layers = []
    for name in ["ring", "shadow", "doll"]:
        subprocess.run(["qlmanage", "-t", "-s", "1024", "-o", str(work), str(ICON_ASSETS / f"{name}.svg")],
                       check=True, capture_output=True)
        layers.append(work / f"{name}.svg.png")
    flat = work / "icon-flat.png"
    command = ["magick", "-size", "1024x1024", f"xc:{ICON_FILL}"]
    for layer in layers:
        # Quick Look は白い地で描くので、白を抜いてから重ねる
        command += ["(", str(layer), "-fuzz", "6%", "-transparent", "white", ")", "-composite"]
    subprocess.run(command + [str(flat)], check=True)
    icon = work / "icon.png"
    subprocess.run(["magick", str(flat), "(", "-size", "1024x1024", "xc:none", "-fill", "white",
                    "-draw", "roundrectangle 0,0 1023,1023 230,230", ")",
                    "-compose", "DstIn", "-composite", str(icon)], check=True)
    return icon


def make_squad(work: Path, width: int, height: int) -> dict:
    """左右の余白に並べるスクワットマンの絵を、寝ている姿、ふだん、フィーバーの3通り書き出す"""
    script = Path(__file__).resolve().parent / "reel_squad.swift"
    dirs = {}
    for name, pose, seconds in [("lie", "lie", 0), ("calm", "squat", SQUAD_SECONDS), ("fever", "squat", SQUAD_FEVER_SECONDS)]:
        out = work / f"squad-{name}"
        subprocess.run(["swift", str(script), str(out), str(width), str(height), pose, str(round(seconds * FPS))],
                       check=True)
        dirs[name] = out
    return dirs


def text(work: Path, name: str, value: str) -> str:
    """drawtext の textfile に渡す。フィルターの中で文字を逃がさずに済む"""
    path = work / f"{name}.txt"
    path.write_text(value, encoding="utf-8")
    return str(path)


def main() -> None:
    work, record_start, out = Path(sys.argv[1]), float(sys.argv[2]), sys.argv[3]
    lang = sys.argv[4] if len(sys.argv) > 4 else "ja"
    kind = sys.argv[5] if len(sys.argv) > 5 else "sns"
    reel = json.loads((work / "reel.json").read_text())
    events = {"start": 0.0, **reel["events"]}
    # SNS の動画には共有の場面がない。最後の文字は終わりまで出す
    captions = [c for c in CAPTIONS[lang] if kind == "lp" or c[1] != "share"]
    if kind != "lp":
        captions = [(t, a, "end" if b == "share" else b) for t, a, b in captions]
    duration = events["end"]
    # 録画の頭から、アプリが音を書き始めたところまでを切る
    offset = max(0.0, reel["audioStart"] - record_start)

    # フィルターの中で日本語のパスを書かずに済むよう、書体を作業場所に置く
    for link, target in [("font.ttc", FONT), ("font-mid.ttc", FONT_MID)]:
        if not (work / link).exists():
            os.symlink(target, work / link)
    bold, mid = work / "font.ttc", work / "font-mid.ttc"
    icon = make_icon(work)

    screen_h = H - BAND
    screen_w = round(1206 * screen_h / 2622 / 2) * 2
    side = (W - screen_w) // 2
    squad = make_squad(work, side, screen_h)
    # 隊列を出す時間。起こすまでは寝ていて、フィーバーの間だけ速い
    wake, fever, fever_end = events.get("wake", 0.0), events.get("fever"), events.get("feverEnd")
    squad_windows = {"lie": [(0.0, wake)], "calm": [(wake, fever or duration)], "fever": []}
    if fever is not None and fever_end is not None:
        squad_windows["calm"].append((fever_end, duration))
        squad_windows["fever"].append((fever, fever_end))
    filters = [
        f"color=c={PAPER}:s={W}x{H}:d={duration}:r={FPS}[bg]",
        f"[0:v]fps={FPS},scale={screen_w}:{screen_h},setsar=1[screen]",
        f"[bg][screen]overlay=({W}-{screen_w})/2:{BAND}:shortest=1[base]",
    ]
    last = "base"
    # 右の隊列は左右を反転して、画面のほうを向かせる
    for i, name in enumerate(["lie", "calm", "fever"]):
        windows = squad_windows[name]
        if not windows:
            continue
        enable = "+".join(f"between(t,{a:.3f},{b:.3f})" for a, b in windows)
        filters.append(f"[{3 + i}:v]split=2[{name}_l][{name}_r0]")
        filters.append(f"[{name}_r0]hflip[{name}_r]")
        filters.append(f"[{last}][{name}_l]overlay=0:{BAND}:enable='{enable}'[{name}_a]")
        filters.append(f"[{name}_a][{name}_r]overlay={W - side}:{BAND}:enable='{enable}'[{name}_b]")
        last = f"{name}_b"
    for i, (caption, start, end) in enumerate(captions):
        begin, finish = events.get(start), events.get(end, duration)
        if begin is None:
            continue
        filters.append(
            f"[{last}]drawtext=fontfile={bold}:textfile={text(work, f'caption{i}', caption)}:fontsize={CAPTION_SIZE[lang]}"
            f":fontcolor={INK}:x=(w-tw)/2:y=({BAND}-th)/2+16:enable='between(t,{begin:.3f},{finish:.3f})'[c{i}]")
        last = f"c{i}"
    filters += [
        f"[1:a]atrim=0:{duration},aresample=48000,aformat=channel_layouts=stereo[main_a]",
        f"color=c={PAPER}:s={W}x{H}:d={CARD_SECONDS}:r={FPS}[card_bg]",
        "[2:v]scale=440:440[icon]",
        f"[card_bg][icon]overlay=({W}-440)/2:520:shortest=1,"
        f"drawtext=fontfile={bold}:textfile={text(work, 'title', CARD_TITLE)}:fontsize=110:fontcolor={INK}"
        f":x=(w-tw)/2:y=1060,"
        f"drawtext=fontfile={mid}:textfile={text(work, 'line', CARD_LINE[lang])}:fontsize=58:fontcolor={MUTE}"
        f":x=(w-tw)/2:y=1230[card]",
        f"anullsrc=r=48000:cl=stereo,atrim=0:{CARD_SECONDS}[card_a]",
        f"[{last}][main_a][card][card_a]concat=n=2:v=1:a=1[v][a]",
    ]
    subprocess.run([
        "ffmpeg", "-loglevel", "error", "-y",
        "-ss", f"{offset:.3f}", "-i", str(work / "screen.mov"),
        "-i", str(work / "reel.caf"),
        "-loop", "1", "-t", str(CARD_SECONDS), "-i", str(icon),
        "-loop", "1", "-t", f"{duration:.3f}", "-framerate", str(FPS), "-i", str(squad["lie"] / "000.png"),
        "-stream_loop", "-1", "-framerate", str(FPS), "-t", f"{duration:.3f}", "-i", str(squad["calm"] / "%03d.png"),
        "-stream_loop", "-1", "-framerate", str(FPS), "-t", f"{duration:.3f}", "-i", str(squad["fever"] / "%03d.png"),
        "-filter_complex", ";".join(filters), "-map", "[v]", "-map", "[a]",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-r", str(FPS),
        "-c:a", "aac", "-b:a", "192k", out,
    ], check=True)


if __name__ == "__main__":
    main()
