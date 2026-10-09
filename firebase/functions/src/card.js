// 共有のリンクカード（OGP 画像）を描く。アプリの今日の記録カード（ios/YatTatTa/Share/ShareCardView.swift）の横長版
//
// X と LINE のリンクカードは横長なので、1200 × 630 で描く。アプリから受け取るのは数字だけで、画像は受け取らない
// （docs/features/share-card）。同じ数字からは同じ画像ができ、同じハッシュになる。
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import satori from "satori";
import { Resvg } from "@resvg/resvg-js";

export const WIDTH = 1200;
export const HEIGHT = 630;

const fonts = [
  { name: "Rounded", weight: 700, data: readFileSync(new URL("../fonts/MPLUSRounded1c-Bold.subset.ttf", import.meta.url)) },
  { name: "Rounded", weight: 900, data: readFileSync(new URL("../fonts/MPLUSRounded1c-Black.subset.ttf", import.meta.url)) },
];

// アプリの Theme と同じ色。カードはいつも明るい色で描く
const color = {
  paper: "#FBF6EE", ink: "#1C1916", card: "#FFFFFF", mute: "#6E655C", rule: "#E7DDCC",
  dopa: "#E5337A", gold: "#E9A800", signal: "#2F79F7",
};

const words = {
  ja: { streak: "日連続", today: "今日", dopa: "ドパ", tagline: "食べたら、しゃがんで、叩く。", weekdays: "日月火水木金土" },
  en: { streak: "days in a row", today: "Today", dopa: "Dopa", tagline: "Eat, squat, tap.", weekdays: "SMTWTFS" },
};

/// アプリから届いた数字を確かめて、決まった形にそろえる。合わなければ投げる
///
/// 数字はアプリの申告を信じる。偽れないようにはできないので、ありえない値だけを断る。
export function normalize(data) {
  const int = (v, min, max) => {
    if (!Number.isInteger(v) || v < min || v > max) throw new Error(`bad value: ${v}`);
    return v;
  };
  if (!data || typeof data !== "object") throw new Error("no data");
  const lang = data.lang === "en" ? "en" : "ja";
  const day = int(data.day, 20260101, 99991231);
  const month = Math.floor(day / 100) % 100, date = day % 100;
  if (month < 1 || month > 12 || date < 1 || date > 31) throw new Error(`bad day: ${day}`);
  if (typeof data.week !== "string" || !/^[012]{7}$/.test(data.week)) throw new Error(`bad week: ${data.week}`);
  return {
    lang,
    day,
    streak: int(data.streak, 0, 36500),
    week: data.week,
    today: int(data.today, 0, 100000),
    dpw: int(data.dpw, 0, 700000),
  };
}

/// 見た目を決める数字から作る名前。同じ見た目なら同じ名前
export function hashOf(card) {
  const key = [card.lang, card.day, card.streak, card.week, card.today, card.dpw].join("|");
  return createHash("sha256").update(key).digest("hex").slice(0, 20);
}

const h = (type, style, children) => ({ type, props: { style, children } });

/// しゃがんだスクワットマン。アプリの SquatterLayer.squat と同じ点、同じ太さ
function figure(height) {
  const legs = "12,0 0,0 15,-15 -7,-25 3,-55";
  const arm = "3,-55 17,-55 31,-56";
  const line = (points, stroke, width) => ({
    type: "polyline",
    props: { points, fill: "none", stroke, "stroke-width": width, "stroke-linecap": "round", "stroke-linejoin": "round" },
  });
  return {
    type: "svg",
    props: {
      width: height * 0.62, height, viewBox: "-17 -88 62 100",
      children: [
        line(legs, color.ink, 15), line(arm, color.ink, 15),
        line(legs, color.gold, 9), line(arm, color.gold, 9),
        { type: "circle", props: { cx: 7, cy: -69, r: 12, fill: color.ink } },
        { type: "circle", props: { cx: 7, cy: -69, r: 8.5, fill: color.gold } },
      ],
    },
  };
}

/// day の n 日前の曜日（0 が日曜）
function weekday(day, back) {
  const d = new Date(Date.UTC(Math.floor(day / 10000), Math.floor(day / 100) % 100 - 1, day % 100 - back));
  return d.getUTCDay();
}

/// 連続日数の文字の大きさ。左の枠に収まるよう、桁が増えたら小さくする
function streakSize(streak) {
  const digits = String(streak).length;
  return digits <= 2 ? 190 : digits === 3 ? 136 : digits === 4 ? 104 : 84;
}

function dateText(card) {
  const y = Math.floor(card.day / 10000), m = String(Math.floor(card.day / 100) % 100).padStart(2, "0"), d = String(card.day % 100).padStart(2, "0");
  return card.lang === "en" ? `${m}/${d}/${y}` : `${y}/${m}/${d}`;
}

function tree(card) {
  const w = words[card.lang];
  const cells = [...card.week].map((c, i) => {
    const last = i === 6;
    const fill = c === "1" ? color.dopa : c === "2" ? color.signal : color.rule;
    return h("div", { display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }, [
      h("div", { width: 66, height: 66, borderRadius: 16, background: fill, border: last ? `5px solid ${color.ink}` : "none" }),
      h("div", { fontSize: 22, fontWeight: last ? 900 : 700, color: last ? color.ink : color.mute }, w.weekdays[weekday(card.day, 6 - i)]),
    ]);
  });
  const stat = (label, value) =>
    h("div", {
      display: "flex", alignItems: "baseline", flex: 1, gap: 8, padding: "12px 22px",
      background: color.card, border: `4px solid ${color.rule}`, borderRadius: 24,
    }, [
      h("div", { fontSize: 22, color: color.mute, flex: 1 }, label),
      h("div", { fontSize: 50, fontWeight: 900 }, String(value)),
      h("div", { fontSize: 22 }, w.dopa),
    ]);

  return h("div", {
    width: WIDTH, height: HEIGHT, display: "flex", gap: 48, padding: 56,
    background: color.paper, color: color.ink, fontFamily: "Rounded", fontWeight: 700,
  }, [
    // 左：連続日数
    h("div", {
      display: "flex", alignItems: "center", justifyContent: "center", gap: 28, width: 470,
      background: color.card, border: `6px solid ${color.ink}`, borderRadius: 44,
      boxShadow: `12px 12px 0 ${color.ink}`,
    }, [
      figure(230),
      h("div", { display: "flex", flexDirection: "column" }, [
        h("div", { fontSize: streakSize(card.streak), fontWeight: 900, lineHeight: 1 }, String(card.streak)),
        h("div", { fontSize: card.lang === "en" ? 30 : 48, fontWeight: 900, marginTop: 8 }, w.streak),
      ]),
    ]),
    // 右：ロゴ、7日、今日と DPW、言葉
    h("div", { display: "flex", flexDirection: "column", flex: 1, justifyContent: "space-between" }, [
      h("div", { display: "flex", alignItems: "baseline", justifyContent: "space-between" }, [
        // このフォントの空白は広いので、語の間は gap で空ける
        h("div", { display: "flex", gap: 16, fontSize: 54, fontWeight: 900 }, [
          h("span", {}, "Yat"), h("span", {}, "Tat"), h("span", { color: color.dopa }, "Ta"),
        ]),
        h("div", { fontSize: 26, color: color.mute }, dateText(card)),
      ]),
      h("div", { display: "flex", justifyContent: "space-between" }, cells),
      h("div", { display: "flex", gap: 16 }, [stat(w.today, card.today), stat("DPW", card.dpw)]),
      h("div", { display: "flex", justifyContent: "space-between", alignItems: "baseline" }, [
        h("div", { fontSize: 26, fontWeight: 900 }, w.tagline),
        h("div", { fontSize: 20, color: color.mute }, "yat-tat-ta.web.app"),
      ]),
    ]),
  ]);
}

/// PNG を描く
export async function render(card) {
  const svg = await satori(tree(card), { width: WIDTH, height: HEIGHT, fonts });
  return new Resvg(svg, { fitTo: { mode: "width", value: WIDTH } }).render().asPng();
}
