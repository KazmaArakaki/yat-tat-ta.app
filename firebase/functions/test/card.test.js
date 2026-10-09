import { test } from "node:test";
import assert from "node:assert/strict";
import { normalize, hashOf, render, WIDTH, HEIGHT } from "../src/card.js";

const sample = { lang: "ja", day: 20261009, streak: 13, week: "1111121", today: 45, dpw: 145 };

test("届いた数字をそのまま受け取る", () => {
  assert.deepEqual(normalize(sample), sample);
});

test("言語は ja と en だけ。ほかは ja", () => {
  assert.equal(normalize({ ...sample, lang: "fr" }).lang, "ja");
  assert.equal(normalize({ ...sample, lang: "en" }).lang, "en");
});

test("ありえない値は断る", () => {
  for (const bad of [
    { streak: -1 }, { streak: 1.5 }, { streak: "13" }, { streak: 99999 },
    { week: "111112" }, { week: "1111123" }, { day: 20261399 }, { day: 19990101 },
    { today: -5 }, { dpw: 10 ** 9 },
  ]) {
    assert.throws(() => normalize({ ...sample, ...bad }), `${JSON.stringify(bad)}`);
  }
  assert.throws(() => normalize(null));
});

test("同じ見た目なら同じ名前、違えば違う名前", () => {
  assert.equal(hashOf(normalize(sample)), hashOf(normalize({ ...sample })));
  assert.notEqual(hashOf(normalize(sample)), hashOf(normalize({ ...sample, streak: 14 })));
  assert.notEqual(hashOf(normalize(sample)), hashOf(normalize({ ...sample, lang: "en" })));
  assert.match(hashOf(normalize(sample)), /^[0-9a-f]{20}$/);
});

test("1200 × 630 の PNG を描く", async () => {
  const png = await render(normalize(sample));
  assert.equal(png.subarray(1, 4).toString(), "PNG");
  assert.equal(png.readUInt32BE(16), WIDTH);
  assert.equal(png.readUInt32BE(20), HEIGHT);
});
