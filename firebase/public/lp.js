// Yat Tat Ta の公開ページ（LP）の動き（docs/features/landing-page）
//
// 1. Google アナリティクス 4。LP を見た人数と、App Store のボタンを押した数（app_store_click）を数える。
//    EEA、英国、スイスからの人には、同意がないものとして Cookie を使わせない（同意モード）。
// 2. App Store へのリンクに、キャンペーンの印（ct）を付ける。App Store Connect の分析で、どのボタンから来た人が入れたかを見る。
// 3. 動画は見えている間だけ流す。音は押したときだけ。
// 4. 行進するスクワットマンと、スクロールで下から出てくる演出。
(() => {
  // GA4 の測定 ID と、App Store Connect のプロバイダ ID（キャンペーンのリンクに要る）。
  // どちらも空なら、その仕組みは動かさない
  const GA_ID = "";
  const PROVIDER_TOKEN = "";
  const APP_ID = "6819943075";

  // ---- 1. Google アナリティクス ----
  window.dataLayer = window.dataLayer || [];
  function gtag() { window.dataLayer.push(arguments); }
  if (GA_ID) {
    const eea = ["AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IS", "IE", "IT", "LV", "LI",
      "LT", "LU", "MT", "NL", "NO", "PL", "PT", "RO", "SK", "SI", "ES", "SE", "GB", "CH"];
    gtag("consent", "default", { ad_storage: "denied", ad_user_data: "denied", ad_personalization: "denied", analytics_storage: "denied", region: eea });
    gtag("consent", "default", { ad_storage: "denied", ad_user_data: "denied", ad_personalization: "denied", analytics_storage: "granted" });
    const script = document.createElement("script");
    script.async = true;
    script.src = `https://www.googletagmanager.com/gtag/js?id=${GA_ID}`;
    document.head.appendChild(script);
    gtag("js", new Date());
    // 広告の機能は使わない
    gtag("config", GA_ID, { allow_google_signals: false, allow_ad_personalization_signals: false });
  }

  // ---- 2. App Store へのリンク ----
  document.querySelectorAll("a[data-store]").forEach((a) => {
    const placement = a.dataset.store;
    if (PROVIDER_TOKEN) {
      const url = new URL(`https://apps.apple.com/app/apple-store/id${APP_ID}`);
      url.searchParams.set("pt", PROVIDER_TOKEN);
      url.searchParams.set("ct", `lp_${document.documentElement.lang}_${placement}`);
      url.searchParams.set("mt", "8");
      a.href = url.toString();
    }
    a.addEventListener("click", () => {
      gtag("event", "app_store_click", { placement, transport_type: "beacon" });
    });
  });

  // ---- 3. 動画 ----
  const video = document.querySelector(".reel video");
  const sound = document.querySelector(".sound");
  if (video) {
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (!reduce) {
      new IntersectionObserver(([entry]) => {
        if (entry.isIntersecting) video.play().catch(() => {});
        else video.pause();
      }, { threshold: 0.3 }).observe(video);
    }
    sound?.addEventListener("click", () => {
      video.muted = !video.muted;
      if (!video.muted) {
        video.currentTime = 0;
        video.play().catch(() => {});
        gtag("event", "video_sound_on");
      }
      sound.textContent = video.muted ? sound.dataset.on : sound.dataset.off;
    });
  }

  // ---- 4. スクワットマンの行進 ----
  // アプリの SquatterLayer と同じ点（ios/YatTatTa/Home/SquatStageView.swift）
  const pose = (legs, arm, head) => `
    <svg viewBox="-20 -98 60 104" aria-hidden="true">
      <polyline points="${legs}" fill="none" stroke="#1C1916" stroke-width="15" stroke-linecap="round" stroke-linejoin="round"/>
      <polyline points="${arm}" fill="none" stroke="#1C1916" stroke-width="15" stroke-linecap="round" stroke-linejoin="round"/>
      <polyline points="${legs}" fill="none" stroke="var(--c)" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>
      <polyline points="${arm}" fill="none" stroke="var(--c)" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="${head[0]}" cy="${head[1]}" r="12" fill="#1C1916"/><circle cx="${head[0]}" cy="${head[1]}" r="8.5" fill="var(--c)"/>
    </svg>`;
  const up = pose("12,0 0,0 0,-21 0,-42 0,-72", "0,-72 4,-58 6,-46", [2, -86]);
  const down = pose("12,0 0,0 15,-15 -7,-25 3,-55", "3,-55 17,-55 31,-56", [7, -69]);
  document.querySelectorAll(".march").forEach((march) => {
    const one = Array.from({ length: 24 }, () => `<span class="guy"><span class="up">${up}</span><span class="down">${down}</span></span>`).join("");
    march.innerHTML = `<div class="row">${one}${one}</div>`;
    march.querySelectorAll(".up, .down").forEach((el) => { el.style.position = "absolute"; el.style.inset = "0"; });
  });

  // ---- 下から出てくる ----
  const reveals = document.querySelectorAll(".reveal");
  const seen = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("in");
      seen.unobserve(entry.target);
    });
  }, { threshold: 0.15 });
  reveals.forEach((el) => seen.observe(el));
})();
