// /s/[ハッシュ] の HTML。X と LINE のクローラーはメタタグだけを読み、人のブラウザは LP へ移る
//
// クローラーは JavaScript を動かさないので、移す処理は JavaScript で書く。HTTP のリダイレクトにすると、
// クローラーまで LP に移って、LP の OGP が出てしまう。クローラーにも人にも同じ HTML を返す（docs/features/share-card）。

const text = {
  ja: { title: (s) => `${s}日連続 | Yat Tat Ta`, description: "食べたら、しゃがんで、叩く。", landing: "/" },
  en: { title: (s) => `${s} days in a row | Yat Tat Ta`, description: "Eat, squat, tap.", landing: "/en/" },
};

const escape = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

/// カードのページ。id はハッシュ、origin は https://{プロジェクト}.web.app
export function sharePage({ id, origin, lang, streak }) {
  const t = text[lang] ?? text.ja;
  const url = `${origin}/s/${id}`;
  const image = `${origin}/s/${id}.png`;
  const title = escape(t.title(streak));
  return `<!doctype html>
<html lang="${lang === "en" ? "en" : "ja"}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta name="robots" content="noindex">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Yat Tat Ta">
<meta property="og:url" content="${escape(url)}">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${escape(t.description)}">
<meta property="og:image" content="${escape(image)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${title}">
<meta name="twitter:description" content="${escape(t.description)}">
<meta name="twitter:image" content="${escape(image)}">
</head>
<body>
<script>location.replace(${JSON.stringify(t.landing)})</script>
<noscript><a href="${t.landing}">Yat Tat Ta</a></noscript>
</body>
</html>
`;
}
