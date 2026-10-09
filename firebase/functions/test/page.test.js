import { test } from "node:test";
import assert from "node:assert/strict";
import { sharePage } from "../src/page.js";

const page = (lang) => sharePage({ id: "0123456789abcdef0123", origin: "https://yat-tat-ta.web.app", lang, streak: "13" });

test("リンクカードのメタタグに、同じハッシュの画像を入れる", () => {
  const html = page("ja");
  assert.match(html, /<meta property="og:image" content="https:\/\/yat-tat-ta.web.app\/s\/0123456789abcdef0123.png">/);
  assert.match(html, /<meta property="og:url" content="https:\/\/yat-tat-ta.web.app\/s\/0123456789abcdef0123">/);
  assert.match(html, /<meta name="twitter:card" content="summary_large_image">/);
  assert.match(html, /<title>13日連続 \| Yat Tat Ta<\/title>/);
});

test("人のブラウザは JavaScript で LP へ移す。英語なら英語の LP", () => {
  assert.match(page("ja"), /location.replace\("\/\?utm_source=share_card&utm_medium=social&utm_campaign=share"\)/);
  assert.match(page("en"), /location.replace\("\/en\/\?utm_source=share_card/);
  assert.match(page("en"), /13 days in a row/);
});

test("メタデータの値は HTML に埋める前に逃がす", () => {
  const html = sharePage({ id: "0123456789abcdef0123", origin: "https://x", lang: "ja", streak: '"><script>' });
  assert.doesNotMatch(html, /"><script>/);
});
