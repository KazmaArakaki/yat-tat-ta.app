#!/usr/bin/env python3
"""X の投稿の公開の数と、アカウントのフォロワーの数を、X の API で読んで記録に書く

読むだけ。投稿、返信、いいね、フォロー、DM はしない（申請した使い道もこれだけ）。
アプリは @yattattadotcom の開発者のアカウントの Default Project（Pay Per Use）にある。決まり事は docs/devops/x-operator#goals。

    python3 marketing/x/metrics.py            記録にある全部の投稿と、フォロワーの数
    python3 marketing/x/metrics.py <投稿のID>   その投稿だけ（宣伝の24時間の判定に）

鍵は .tmp/x-bearer-token.secret（Git に入らない）。読む1件 $0.005（2026 の公開値）。
使った分は x-api-usage.json に残し、月 $2 の見込みに届いたら読まずに止まる。
"""
import json
import re
import sys
import urllib.request
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
TOKEN = ROOT / ".tmp" / "x-bearer-token.secret"
POSTS = HERE / "posts.json"
WEEKLY = HERE / "weekly.json"
USAGE = HERE / "x-api-usage.json"
ACCOUNT = "yattattadotcom"
USD_PER_READ = 0.005
MONTHLY_STOP_USD = 2.0


def get(path: str) -> dict:
    request = urllib.request.Request(f"https://api.x.com/2/{path}",
                                     headers={"Authorization": f"Bearer {TOKEN.read_text().strip()}"})
    return json.load(urllib.request.urlopen(request, timeout=60))


def main() -> None:
    now = datetime.now().astimezone()
    stamp = now.strftime("%Y-%m-%dT%H:%M%z")
    posts = json.loads(POSTS.read_text())
    targets = {}
    for post in posts:
        match = re.search(r"/status/(\d+)", post.get("url") or "")
        if match and (len(sys.argv) < 2 or match.group(1) == sys.argv[1]):
            targets[match.group(1)] = post
    reads = len(targets) + (1 if len(sys.argv) < 2 else 0)

    month = now.strftime("%Y-%m")
    usage = json.loads(USAGE.read_text()) if USAGE.exists() else {}
    entry = usage.setdefault(month, {"reads": 0, "usd": 0.0})
    if entry["usd"] + reads * USD_PER_READ > MONTHLY_STOP_USD:
        sys.exit(f"error: 今月の見込みが ${entry['usd']:.3f}。${MONTHLY_STOP_USD} を超えるので読まない")

    if targets:
        # 100件まで1回で読める
        data = get(f"tweets?ids={','.join(targets)}&tweet.fields=public_metrics")
        for tweet in data.get("data", []):
            m = tweet["public_metrics"]
            post = targets[tweet["id"]]
            result = post.get("result") or {}
            result.update({
                "views": m.get("impression_count"), "likes": m.get("like_count"),
                "reposts": m.get("retweet_count"), "replies": m.get("reply_count"),
                "quotes": m.get("quote_count"), "bookmarks": m.get("bookmark_count"),
                "at": stamp, "by": "api",
            })
            post["result"] = result
            print(f"{tweet['id']}  表示 {m.get('impression_count')}  いいね {m.get('like_count')}  "
                  f"リポスト {m.get('retweet_count')}  返信 {m.get('reply_count')}  "
                  f"引用 {m.get('quote_count')}  ブックマーク {m.get('bookmark_count')}")
        for error in data.get("errors", []):
            print(f"読めなかった: {error.get('value')} {error.get('detail')}")
        POSTS.write_text(json.dumps(posts, ensure_ascii=False, indent=2) + "\n")

    if len(sys.argv) < 2:
        user = get(f"users/by/username/{ACCOUNT}?user.fields=public_metrics")["data"]
        followers = user["public_metrics"]["followers_count"]
        weekly = json.loads(WEEKLY.read_text())
        weekly[-1].setdefault("followers", []).append({"at": stamp, "count": followers})
        WEEKLY.write_text(json.dumps(weekly, ensure_ascii=False, indent=2) + "\n")
        print(f"フォロワー {followers}")

    entry["reads"] += reads
    entry["usd"] = round(entry["usd"] + reads * USD_PER_READ, 4)
    USAGE.write_text(json.dumps(usage, ensure_ascii=False, indent=2) + "\n")
    print(f"今月 {entry['reads']} 件、見込み ${entry['usd']:.3f}")


if __name__ == "__main__":
    main()
