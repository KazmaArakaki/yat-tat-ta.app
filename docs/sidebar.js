// docs 共通サイドバー。各ページの </body> 直前で defer 読み込みする。
// 自分の <script src> から docs ルートへの相対パスを求めるので、file:// でも動く。
(function () {
  var script =
    document.currentScript ||
    document.querySelector('script[src$="sidebar.js"]');
  var src = script.getAttribute("src") || "sidebar.js";
  var root = src.replace(/sidebar\.js(\?.*)?$/, ""); // "", "../", "../../"

  // セッション一覧（新しい順）。新しいセッションは先頭に足す。
  var sessions = [
    {
      path: "sessions/20261006-1312-heavy-effects/index.html",
      label: "10/06 処理落ちを確かめる"
    },
    {
      path: "sessions/20261006-1258-health-claims/index.html",
      label: "10/06 健康効果の書き方を決める"
    },
    {
      path: "sessions/20261006-0312-main-build/index.html",
      label: "10/06 本作りの設計",
      children: [
        { path: "sessions/20261006-0312-main-build/dopadopa.html", label: "ドパドパの見本" },
        { path: "sessions/20261006-0312-main-build/fullscreen.html", label: "画面全体の演出の見本" }
      ]
    },
    {
      path: "sessions/20261006-0215-subject/index.html",
      label: "10/06 題材を決める",
      children: [
        { path: "sessions/20261006-0215-subject/duolingo.html", label: "Duolingo の継続の仕組み" }
      ]
    },
    {
      path: "sessions/20261006-0140-feel-prototype/index.html",
      label: "10/06 手触りの試作"
    },
    {
      path: "sessions/20261006-0128-app-name/index.html",
      label: "10/06 アプリ名を決める"
    },
    {
      path: "sessions/20261006-0059-ios-app-baseline/index.html",
      label: "10/06 iOS アプリの土台を決める"
    },
    {
      path: "sessions/20261006-0019-ios-dev-environment-setup/index.html",
      label: "10/06 iOS 開発環境の準備"
    },
    {
      path: "sessions/20261005-1815-dopa-apps-research/index.html",
      label: "10/05 ドパ〇〇アプリ調査",
      children: [
        { path: "sessions/20261005-1815-dopa-apps-research/dopa-drill.html", label: "ドパドリル" },
        { path: "sessions/20261005-1815-dopa-apps-research/dopa-calc.html", label: "ドパ電卓" },
        { path: "sessions/20261005-1815-dopa-apps-research/dopa-kuku.html", label: "ドパ九九" },
        { path: "sessions/20261005-1815-dopa-apps-research/dopanyan.html", label: "ドパにゃん" },
        { path: "sessions/20261005-1815-dopa-apps-research/dopa-shogi.html", label: "ドパ将棋！" }
      ]
    }
  ];

  var RECENT = 5;
  var sessionItems = [];
  sessions.slice(0, RECENT).forEach(function (s) {
    sessionItems.push({ label: s.label, path: s.path, level: 1 });
    (s.children || []).forEach(function (c) {
      sessionItems.push({ label: c.label, path: c.path, level: 2 });
    });
  });

  var groups = [
    { label: "トップ", items: [{ label: "トップ", path: "index.html", level: 0 }] },
    { label: "用語集", items: [{ label: "用語集", path: "glossary.html", level: 0 }] },
    {
      label: "Sessions",
      note: sessions.length > RECENT ? "直近" + RECENT + "件 / 全" + sessions.length + "件" : null,
      items: [{ label: "セッション一覧", path: "sessions/index.html", level: 0 }].concat(sessionItems)
    },
    {
      label: "Features",
      items: [
        { label: "機能一覧", path: "features/index.html", level: 0 },
        { label: "完了連打", path: "features/done-mash/index.html", level: 1 },
        { label: "ドパの合計", path: "features/dopa-totals/index.html", level: 1 },
        { label: "連続記録と休み券", path: "features/streak/index.html", level: 1 },
        { label: "今日まだ通知", path: "features/today-reminder/index.html", level: 1 }
      ]
    },
    {
      label: "UI",
      items: [
        { label: "基本方針", path: "ui/principles.html", level: 0 },
        { label: "コンポーネント一覧", path: "ui/components/index.html", level: 0 },
        { label: "スクワット隊", path: "ui/components/squat-squad/index.html", level: 1 },
        { label: "ドパ突破", path: "ui/components/dopa-toppa/index.html", level: 1 },
        { label: "フィーバータイム", path: "ui/components/fever/index.html", level: 1 },
        { label: "ページ一覧", path: "ui/pages/index.html", level: 0 },
        { label: "ホーム", path: "ui/pages/home/index.html", level: 1 },
        { label: "設定シート", path: "ui/pages/settings/index.html", level: 1 }
      ]
    },
    {
      label: "Database",
      items: [
        { label: "データベース", path: "database/index.html", level: 0 },
        { label: "SquatRecord", path: "database/squat-record/index.html", level: 1 }
      ]
    },
    {
      label: "DevOps",
      items: [
        { label: "開発/運用一覧", path: "devops/index.html", level: 0 },
        { label: "iOS 開発環境", path: "devops/ios-dev-environment/index.html", level: 1 },
        { label: "iOS プロジェクトの設定", path: "devops/ios-project/index.html", level: 1 },
        { label: "声と効果音の出どころ", path: "devops/sound-assets/index.html", level: 1 },
        { label: "健康効果の書き方", path: "devops/health-wording/index.html", level: 1 },
        { label: "処理落ちの確かめ方", path: "devops/perf-check/index.html", level: 1 }
      ]
    },
    {
      label: "Issues",
      items: [
        { label: "課題一覧", path: "issues/index.html", level: 0 },
        { label: "多言語展開の進め方", path: "issues/localization/index.html", level: 1 },
        { label: "演出を盛ったときの処理落ち", path: "issues/heavy-effects-performance/index.html", level: 1 },
        { label: "記録の取り消し", path: "issues/undo-record/index.html", level: 1 }
      ]
    }
  ];

  function norm(href) {
    return href.replace(/[?#].*$/, "").replace(/\/index\.html$/, "/");
  }
  var here = norm(location.href);

  var indent = ["pl-3", "pl-6", "pl-10"];
  var nav = document.createElement("nav");
  nav.setAttribute("aria-label", "ドキュメント");
  nav.className = "flex flex-col gap-5 p-5 text-sm";

  groups.forEach(function (g) {
    var sec = document.createElement("div");
    var h = document.createElement("p");
    h.className = "mb-1.5 font-mono text-[11px] uppercase tracking-[0.18em] text-mute";
    h.textContent = g.label;
    sec.appendChild(h);
    if (g.note) {
      var n = document.createElement("p");
      n.className = "mb-1.5 text-[11px] text-mute";
      n.textContent = g.note;
      sec.appendChild(n);
    }
    var ul = document.createElement("ul");
    ul.className = "flex flex-col gap-0.5";
    g.items.forEach(function (it) {
      var li = document.createElement("li");
      var a = document.createElement("a");
      a.href = root + it.path;
      a.textContent = it.label;
      var active = norm(a.href) === here;
      a.className =
        "block rounded-md py-1.5 pr-2 border-l-4 transition-colors " +
        indent[it.level] + " " +
        (it.level === 2 ? "text-[13px] " : "") +
        (active
          ? "border-dopa bg-dopa-soft font-bold text-ink"
          : "border-transparent text-ink/75 hover:bg-dopa-pale hover:text-ink");
      if (active) a.setAttribute("aria-current", "page");
      li.appendChild(a);
      ul.appendChild(li);
    });
    sec.appendChild(ul);
    nav.appendChild(sec);
  });

  function brand() {
    var a = document.createElement("a");
    a.href = root + "index.html";
    a.className = "font-display text-lg tracking-wide text-ink";
    a.innerHTML = 'docs<span class="text-dopa">.</span>';
    return a;
  }

  // デスクトップ：左固定
  var aside = document.createElement("aside");
  aside.className =
    "hidden lg:flex fixed inset-y-0 left-0 z-30 w-64 flex-col overflow-y-auto border-r border-rule bg-paper";
  var top = document.createElement("div");
  top.className = "border-b border-rule px-5 py-4";
  top.appendChild(brand());
  aside.appendChild(top);
  aside.appendChild(nav);

  // スマホ：上部の折りたたみ
  var mobile = document.createElement("details");
  mobile.className = "lg:hidden sticky top-0 z-30 border-b border-rule bg-paper/95 backdrop-blur";
  var sum = document.createElement("summary");
  sum.className = "flex cursor-pointer list-none items-center justify-between px-4 py-3";
  sum.appendChild(brand());
  var m = document.createElement("span");
  m.className = "font-mono text-xs text-mute";
  m.textContent = "MENU ▾";
  sum.appendChild(m);
  mobile.appendChild(sum);
  mobile.appendChild(nav.cloneNode(true));

  document.body.insertBefore(aside, document.body.firstChild);
  document.body.insertBefore(mobile, document.body.firstChild);

  var main = document.querySelector("main");
  if (main) main.classList.add("lg:ml-64");
})();
