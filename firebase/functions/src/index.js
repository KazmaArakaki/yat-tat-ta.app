// 今日の記録カードを、X と LINE のリンクカードにする（docs/features/share-card）
//
// createShareCard：アプリから数字を受け取ってカードを描き、Cloud Storage の share/[ハッシュ].png に置き、共有する URL を返す。
// share：/s/[ハッシュ] に HTML を、/s/[ハッシュ].png に画像を返す。Hosting の振り分け（firebase.json）からここへ来る。
// どちらも、同じハッシュなら中身が変わらないので、CDN に1年キャッシュさせる。
import { initializeApp } from "firebase-admin/app";
import { getStorage } from "firebase-admin/storage";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { hashOf, normalize, render } from "./card.js";
import { sharePage } from "./page.js";

initializeApp();

const region = "asia-northeast1";
const immutable = "public, max-age=31536000, immutable";
const idPattern = /^[0-9a-f]{20}$/;

/// 公開ページの URL。Hosting のサイト名はプロジェクト ID と同じ
const origin = () => `https://${process.env.GCLOUD_PROJECT}.web.app`;
const cardFile = (id) => getStorage().bucket().file(`share/${id}.png`);

/// ログイン中（匿名を含む）のアプリからだけ受け付ける。App Check も確かめる
///
/// 受け取るのは数字と言語だけ。uid は確かめるのに使うだけで、どこにも残さない。
export const createShareCard = onCall({ region, enforceAppCheck: true, memory: "512MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "sign-in required");
  let card;
  try {
    card = normalize(request.data);
  } catch (error) {
    throw new HttpsError("invalid-argument", error.message);
  }
  const id = hashOf(card);
  const file = cardFile(id);
  const [exists] = await file.exists();
  if (!exists) {
    await file.save(await render(card), {
      contentType: "image/png",
      metadata: { cacheControl: immutable, metadata: { lang: card.lang, streak: String(card.streak) } },
    });
  }
  return { url: `${origin()}/s/${id}` };
});

/// クローラーと人が読みに来るところ
export const share = onRequest({ region, memory: "256MiB" }, async (req, res) => {
  const match = /^\/s\/([0-9a-f]+)(\.png)?\/?$/.exec(req.path);
  const id = match?.[1];
  if (!id || !idPattern.test(id)) {
    res.redirect(302, "/");
    return;
  }
  const file = cardFile(id);
  if (match[2]) {
    const [exists] = await file.exists();
    if (!exists) {
      res.status(404).send("not found");
      return;
    }
    res.set("Cache-Control", immutable).type("png");
    file.createReadStream().on("error", () => res.end()).pipe(res);
    return;
  }
  let meta;
  try {
    [meta] = await file.getMetadata();
  } catch {
    // 知らないカード。LP へ送るだけにして、覚えさせない
    res.set("Cache-Control", "no-store").redirect(302, "/");
    return;
  }
  const { lang = "ja", streak = "0" } = meta.metadata ?? {};
  res.set("Cache-Control", immutable).type("html").send(sharePage({ id, origin: origin(), lang, streak }));
});
