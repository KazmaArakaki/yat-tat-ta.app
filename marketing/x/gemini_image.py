#!/usr/bin/env python3
"""小ネタの投稿に付ける画像を、Gemini（Nano Banana 2.1）で描く

研究の紹介と宣伝には使わない（数字と出典はカード、アプリは本物の画面で見せる）。
アプリと同じスクワットマンの絵を見本として渡し、同じ棒人間で描かせる。文字は描かせない。
決まり事は docs/devops/x-operator#images。

    python3 marketing/x/gemini_image.py "<場面の説明（英語）>" <書き出す PNG> [縦横比]

鍵は .tmp/gemini-api-key.secret（Git に入らない）。月の上限は1,000円で、
このスクリプトは月の見込みが900円に届いたら描かずに止まる。使った分は gemini-usage.json に残す。
"""
import base64
import json
import subprocess
import sys
import tempfile
import urllib.request
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KEY = ROOT / ".tmp" / "gemini-api-key.secret"
USAGE = Path(__file__).resolve().parent / "gemini-usage.json"
SQUAD = ROOT / "ios" / "Design" / "reel_squad.swift"
MODEL = "gemini-nano-banana-2.1"
# 1K の画像1枚 $0.0336（2026-10-08 の料金表）。入力の分と為替の揺れを見て、1枚7円で数える
YEN_PER_IMAGE = 7
MONTHLY_STOP_YEN = 900

STYLE = (
    "Draw the stick-figure characters exactly like the reference image: a thick dark outline (#1C1916), "
    "rounded line ends, a body made of a few thin straight strokes of equal width (legs, torso, one arm), "
    "a round head with no face, no fingers, no clothes, no filled body shapes. "
    "Every figure is seen from the side and faces right, like the reference. Never draw a figure facing the viewer. "
    "Each figure is one flat color: gold #E9A800, pink #E5337A, or blue #2F79F7. "
    "Flat 2D vector style, plain cream background #FBF6EE, no gradients, no shading, no realistic people. "
    "Absolutely no text, letters, numbers, signs, logos or speech bubbles anywhere in the image."
)


def reference(work: Path) -> Path:
    """見本：しゃがむ途中の隊列と、床で寝ている姿"""
    for pose in ["squat", "lie"]:
        subprocess.run(["swift", str(SQUAD), str(work / pose), "600", "300", pose, "36"],
                       check=True, capture_output=True)
    out = work / "reference.png"
    subprocess.run(["magick", "-size", "600x600", "xc:#FBF6EE",
                    str(work / "squat" / "018.png"), "-geometry", "+0+0", "-composite",
                    str(work / "lie" / "000.png"), "-geometry", "+0+300", "-composite", str(out)], check=True)
    return out


def main() -> None:
    scene, out = sys.argv[1], Path(sys.argv[2])
    aspect = sys.argv[3] if len(sys.argv) > 3 else "16:9"
    month = datetime.now().strftime("%Y-%m")
    usage = json.loads(USAGE.read_text()) if USAGE.exists() else {}
    spent = usage.get(month, {}).get("yen", 0)
    if spent + YEN_PER_IMAGE > MONTHLY_STOP_YEN:
        sys.exit(f"error: 今月の見込みが {spent} 円。{MONTHLY_STOP_YEN} 円を超えるので描かない")

    with tempfile.TemporaryDirectory() as tmp:
        ref = reference(Path(tmp))
        body = {
            "contents": [{"parts": [
                {"text": f"{STYLE}\n\nScene: {scene}"},
                {"inline_data": {"mime_type": "image/png", "data": base64.b64encode(ref.read_bytes()).decode()}},
            ]}],
            "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": aspect, "imageSize": "1K"}},
        }
    request = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": KEY.read_text().strip()})
    response = json.load(urllib.request.urlopen(request, timeout=180))

    # 失敗しても料金はかかりうるので、先に数える
    entry = usage.setdefault(month, {"images": 0, "yen": 0})
    entry["images"] += 1
    entry["yen"] += YEN_PER_IMAGE
    USAGE.write_text(json.dumps(usage, ensure_ascii=False, indent=2) + "\n")

    parts = response.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    images = [p for p in parts if "inlineData" in p or "inline_data" in p]
    if not images:
        sys.exit(f"error: 画像が返ってこなかった: {json.dumps(response, ensure_ascii=False)[:500]}")
    data = images[0].get("inlineData") or images[0].get("inline_data")
    out.parent.mkdir(parents=True, exist_ok=True)
    # 返ってくる形式（JPEG か PNG）の拡張子で一度書いてから、PNG にそろえる
    mime = data.get("mimeType") or data.get("mime_type") or "image/png"
    raw = out.with_name(out.stem + "-gemini." + mime.split("/")[-1])
    raw.write_bytes(base64.b64decode(data["data"]))
    subprocess.run(["magick", str(raw), str(out)], check=True)
    raw.unlink()
    print(f"できた: {out}（今月 {entry['images']} 枚、見込み {entry['yen']} 円）")


if __name__ == "__main__":
    main()
