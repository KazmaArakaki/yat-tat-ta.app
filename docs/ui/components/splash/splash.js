// スプラッシュの動く見本。docs の見本だけで使う（アプリは SwiftUI で描く）
//
// Splash.render(root, opts) で、iPhone の枠の中にスプラッシュとその下のホームを描き、再生する。
// 時刻はアプリと同じ秒で持つ。T を変えたら、機能ページの表と Swift の値も合わせて直すこと。
var Splash = (function () {
  var NS = "http://www.w3.org/2000/svg";
  var FREEZE = (function () { var m = /[?&]t=([\d.]+)/.exec(location.search); return m ? parseFloat(m[1]) : null; })();
  var GOLD = "#E9A800", DOPA = "#E5337A", SIGNAL = "#2F79F7", ONGOLD = "#1C1916";

  // 動きの時刻（秒）。ふつうの場合
  var T = {
    waveStart: 0.15,  // 隊列の波が、いちばん古い日から動き出す
    waveSpan: 0.55,   // 波が、いちばん新しい日まで届くのにかかる時間
    squat: 0.34,      // 1人がしゃがんで立つまで
    beats: [0.15, 0.45, 0.75], // Yat / Tat / Ta の拍。振動もここ
    seat: 0.75,       // 波が今日の席に届く
    handoff: 1.25,    // ホームへの引き継ぎを始める
    end: 1.65         // スプラッシュが消えきる
  };
  // ひかえめモード。波もしゃがみも飛ぶ数字もなく、置いて、消すだけ。振動の3拍は変えない
  var STILL = { beats: [0.15, 0.45, 0.75], seat: 0, handoff: 0.9, end: 1.15 };

  // スクワット隊の点（SquatterLayer.stand / squat）。足元が原点、上が負
  var STAND = { legs: [[12, 0], [0, 0], [0, -21], [0, -42], [0, -72]], arm: [[0, -72], [4, -58], [6, -46]], head: [2, -86] };
  var SQUAT = { legs: [[12, 0], [0, 0], [15, -15], [-7, -25], [3, -55]], arm: [[3, -55], [17, -55], [31, -56]], head: [7, -69] };
  // 仰向けに寝た姿（ホームで寝ている隊）
  var LIE = { legs: [[44, -14], [40, -7], [19, -7], [-2, -7], [-32, -7]], arm: [[-32, -7], [-18, -3], [-6, -3]], head: [-46, -12] };

  function el(name, attrs, parent) {
    var n = document.createElementNS(NS, name);
    for (var k in attrs) n.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(n);
    return n;
  }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function mixPts(a, b, t) { return a.map(function (p, i) { return [lerp(p[0], b[i][0], t), lerp(p[1], b[i][1], t)]; }); }
  function pts(a) { return a.map(function (p) { return p[0].toFixed(1) + "," + p[1].toFixed(1); }).join(" "); }
  function clamp(x) { return Math.max(0, Math.min(1, x)); }
  function easeOut(x) { return 1 - Math.pow(1 - x, 3); }
  function easeInOut(x) { return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2; }

  // しゃがみの深さ。下りを速く（4割）、上りをゆっくり（6割）
  function dip(u) {
    if (u <= 0 || u >= 1) return 0;
    return u < 0.4 ? easeOut(u / 0.4) : 1 - easeInOut((u - 0.4) / 0.6);
  }

  // 人形1人。黒い縁は暗い配色でも黒のまま（隊と履歴と同じ）
  function figure(parent, color, pose) {
    var g = el("g", {}, parent);
    var round = { fill: "none", "stroke-linecap": "round", "stroke-linejoin": "round" };
    var o1 = el("polyline", Object.assign({ stroke: ONGOLD, "stroke-width": 15 }, round), g);
    var o2 = el("polyline", Object.assign({ stroke: ONGOLD, "stroke-width": 15 }, round), g);
    var c1 = el("polyline", Object.assign({ stroke: color, "stroke-width": 9 }, round), g);
    var c2 = el("polyline", Object.assign({ stroke: color, "stroke-width": 9 }, round), g);
    var h1 = el("circle", { r: 12, fill: ONGOLD }, g);
    var h2 = el("circle", { r: 8.5, fill: color }, g);
    function set(p) {
      var l = pts(p.legs), a = pts(p.arm);
      o1.setAttribute("points", l); c1.setAttribute("points", l);
      o2.setAttribute("points", a); c2.setAttribute("points", a);
      [h1, h2].forEach(function (h) { h.setAttribute("cx", p.head[0]); h.setAttribute("cy", p.head[1]); });
    }
    set(pose || STAND);
    return { g: g, squat: function (d) { set({ legs: mixPts(STAND.legs, SQUAT.legs, d), arm: mixPts(STAND.arm, SQUAT.arm, d), head: [lerp(STAND.head[0], SQUAT.head[0], d), lerp(STAND.head[1], SQUAT.head[1], d)] }); } };
  }

  // 今日の席。人形はいない。床の丸い印（スポット）に、上から薄い光が差している。
  //   叩けば、ここに1人が立つ。lit が false なら明日からの席（床の印の輪郭だけ）
  var spotUid = 0;
  function seat(parent, lit) {
    var g = el("g", {}, parent);
    if (lit === false) {
      el("ellipse", { cx: 6, cy: 0, rx: 21, ry: 6.5, fill: "none", stroke: "#A89C8E", "stroke-width": 3, "stroke-dasharray": "5 5", opacity: 0.8 }, g);
      return g;
    }
    var svg = parent.ownerSVGElement, id = "spot" + (++spotUid);
    var defs = el("defs", {}, g);
    var lg = el("linearGradient", { id: id, x1: 0, y1: 1, x2: 0, y2: 0 }, defs);
    el("stop", { offset: 0, "stop-color": DOPA, "stop-opacity": 0.32 }, lg);
    el("stop", { offset: 1, "stop-color": DOPA, "stop-opacity": 0 }, lg);
    // 上から差す光。床に近いほど濃い
    el("polygon", { points: "-4,-112 16,-112 32,0 -20,0", fill: "url(#" + id + ")" }, g);
    // 床の印。隊と同じ黒い縁
    el("ellipse", { cx: 6, cy: 0, rx: 24, ry: 7.5, fill: DOPA, stroke: ONGOLD, "stroke-width": 3.5 }, g);
    el("ellipse", { cx: 3, cy: -1.5, rx: 11, ry: 2.6, fill: "#fff", opacity: 0.35 }, g);
    return g;
  }

  // 人形の足元の影。今日の席の印と同じ位置に落とし、「ここに立つ」が読めるようにする
  function shadow(parent) {
    return el("ellipse", { cx: 6, cy: 1, rx: 20, ry: 6, fill: "#1C1916", opacity: 0.14 }, parent);
  }

  // 休み券の日。人形の代わりに青い札
  function ticket(parent) {
    var g = el("g", {}, parent);
    el("rect", { x: -3, y: -50, width: 30, height: 38, rx: 6, fill: SIGNAL, stroke: ONGOLD, "stroke-width": 4 }, g);
    el("line", { x1: 3, x2: 21, y1: -31, y2: -31, stroke: "rgba(255,255,255,.8)", "stroke-width": 3, "stroke-dasharray": "2 3" }, g);
    return g;
  }

  // 連続の日を、曜日にそろえて並べる。古い日が左上、今日が右下
  //   streak: 昨日までの連続日数（今日済みなら今日を含む）。rest: 休み券を使った日（今日から何日前か）
  //   todayWeekday: 0=日曜。週の始まりは日曜（アプリでは端末の Calendar.firstWeekday）
  function cells(o) {
    var list = [{ kind: o.done ? "today" : "seat" }];
    var need = o.done ? o.streak - 1 : o.streak, back = 1;
    var rest = o.rest || [];
    while (need > 0) {
      if (rest.indexOf(back) >= 0) list.unshift({ kind: "rest" });
      else { list.unshift({ kind: "past" }); need--; }
      back++;
    }
    var lead = ((o.todayWeekday - (list.length - 1)) % 7 + 7) % 7;
    var all = [];
    for (var i = 0; i < lead; i++) all.push({ kind: "blank" });
    all = all.concat(list);
    var rows = Math.ceil(all.length / 7), hidden = 0;
    if (rows > 8) {
      // 8週を超えたら、古い週を「＋N日」の札にまとめる
      var drop = (rows - 8) * 7;
      hidden = all.slice(0, drop).filter(function (c) { return c.kind === "past"; }).length;
      all = all.slice(drop);
      rows = 8;
    }
    return { cells: all, rows: rows, hidden: hidden };
  }

  // iPhone の枠と、その下に敷くホーム。スプラッシュが消えたあとに見えるもの
  function buildPhone(root, opts, W, H, paper, ink, mute, card) {
    root.innerHTML = "";
    var phone = document.createElement("div");
    phone.className = "splash-phone";
    phone.style.cssText = "position:relative;width:" + W + "px;height:" + H + "px;border-radius:44px;overflow:hidden;background:" + paper + ";color:" + ink + ";border:10px solid #0d0b0a;box-sizing:content-box;cursor:pointer;user-select:none;font-family:'Noto Sans JP',sans-serif;";
    root.appendChild(phone);

    var home = document.createElement("div");
    home.style.cssText = "position:absolute;inset:0;padding:52px 20px 18px;display:flex;flex-direction:column;";
    var headline = opts.streak > 0
      ? '<span data-home-num style="font-family:&quot;M PLUS Rounded 1c&quot;,sans-serif;font-weight:900;font-variant-numeric:tabular-nums;letter-spacing:-0.02em;font-size:44px;line-height:1;color:' + DOPA + '">' + opts.streak + '</span><span style="font-weight:900;font-size:15px">日連続</span>'
      : '<span style="font-weight:900;font-size:15px">' + (opts.best ? "今日の1回で" : "最初の1回で") + '</span><span data-home-num style="font-family:&quot;M PLUS Rounded 1c&quot;,sans-serif;font-weight:900;font-variant-numeric:tabular-nums;letter-spacing:-0.02em;font-size:44px;line-height:1;color:' + DOPA + '">1</span><span style="font-weight:900;font-size:15px">日目</span>';
    home.innerHTML =
      '<div style="display:flex;justify-content:space-between;align-items:flex-start">' +
        '<div><div style="display:flex;align-items:baseline;gap:2px">' + headline + '</div>' +
        '<div style="margin-top:4px;font-size:12px;font-weight:700;color:' + (opts.done ? DOPA : mute) + '">' + opts.sub + '</div></div>' +
        '<div style="text-align:right;font-size:10px;font-weight:700;color:' + mute + '">休み券<div style="display:flex;gap:4px;margin-top:4px"><span style="width:20px;height:14px;border-radius:4px;background:' + SIGNAL + ';border:2px solid ' + ink + '"></span><span style="width:20px;height:14px;border-radius:4px;border:1.5px dashed ' + mute + '"></span></div></div>' +
      '</div>' +
      '<div data-stage style="flex:1;position:relative"></div>' +
      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:10px">' +
        ['DPW', 'DT'].map(function (k, i) {
          return '<div style="background:' + card + ';border:2px solid ' + ink + ';border-radius:16px;box-shadow:4px 4px 0 ' + ink + ';padding:8px 10px"><div style="font:700 9px JetBrains Mono,monospace;color:' + mute + '">' + k + '</div><div style="font-family:&quot;M PLUS Rounded 1c&quot;,sans-serif;font-weight:900;font-variant-numeric:tabular-nums;letter-spacing:-0.02em;font-size:26px;line-height:1.1;color:' + (i ? ink : DOPA) + '">' + (i ? '987' : '347') + '</div></div>';
        }).join("") +
      '</div>';
    phone.appendChild(home);
    // 寝ている隊（長押しで起こす）
    var stage = home.querySelector("[data-stage]");
    var sv = el("svg", { width: W - 40, height: 260, viewBox: "0 0 " + (W - 40) + " 260", style: "position:absolute;left:0;bottom:30px" });
    stage.appendChild(sv);
    var cap = el("text", { x: (W - 40) / 2, y: 52, "text-anchor": "middle", "font-size": 12, "font-weight": 700, fill: mute }, sv);
    cap.textContent = "スクワット 残り";
    var remain = el("text", { x: (W - 40) / 2, y: 112, "text-anchor": "middle", "font-size": 60, "font-weight": 900, fill: ink, "font-family": "M PLUS Rounded 1c" }, sv);
    remain.textContent = "20";
    [0, 1, 2].forEach(function (i) {
      var g = el("g", { transform: "translate(" + (66 + i * 82) + ",200) scale(.62)" }, sv);
      figure(g, GOLD, LIE);
    });
    var hint = el("text", { x: (W - 40) / 2, y: 236, "text-anchor": "middle", "font-size": 11, "font-weight": 700, fill: mute }, sv);
    hint.textContent = "長押しで起こす";

    return { phone: phone, home: home };
  }

  function render(root, opts) {
    if (opts.intro) return renderIntro(root, opts);
    var W = 320, H = 660;
    var still = !!opts.still, dark = !!opts.dark;
    var Tm = still ? STILL : T;
    var paper = dark ? "#16120F" : "#FBF6EE", ink = dark ? "#F5EEE3" : "#1C1916", mute = dark ? "#A89C8E" : "#6E655C", card = dark ? "#231D18" : "#FFFFFF";
    var grid = cells(opts);
    var first = grid.cells.filter(function (c) { return c.kind === "past" || c.kind === "rest"; }).length === 0;

    var built = buildPhone(root, opts, W, H, paper, ink, mute, card);
    var phone = built.phone, home = built.home;

    // ── スプラッシュ
    var sp = document.createElement("div");
    sp.style.cssText = "position:absolute;inset:0;background:" + paper + ";";
    phone.appendChild(sp);

    // 社名ロゴの代わりに、名前そのものを3拍で踏む
    var mark = document.createElement("div");
    mark.setAttribute("aria-hidden", "true");
    mark.style.cssText = "position:absolute;left:0;right:0;top:78px;display:flex;justify-content:center;gap:9px;font-family:'M PLUS Rounded 1c',sans-serif;font-weight:900;font-size:30px;letter-spacing:-0.02em;";
    var words = ["Yat", "Tat", "Ta"].map(function (w, i) {
      var s = document.createElement("span");
      s.textContent = w;
      s.style.cssText = "display:inline-block;transform-origin:50% 100%;" + (i === 2 ? "color:" + DOPA + ";" : "");
      mark.appendChild(s);
      return s;
    });
    sp.appendChild(mark);

    // 隊列
    var gridTop = 140, gridBottom = 452, cols = 7, cellW = (W - 56) / cols;
    var rowH = first ? 0 : Math.min(58, (gridBottom - gridTop) / grid.rows);
    var k = first ? 1.3 : Math.min(rowH * 0.86 / 106, cellW * 0.95 / 52);
    var svg = el("svg", { width: W, height: H, style: "position:absolute;inset:0;overflow:visible", "aria-hidden": "true" });
    sp.appendChild(svg);
    var squad = [], seatNode = null, seatAt = null, todayFig = null;
    if (grid.hidden > 0) {
      var more = el("text", { x: 28, y: gridBottom - grid.rows * rowH - 8, "font-size": 11, "font-weight": 700, fill: mute, "font-family": "JetBrains Mono" }, svg);
      more.textContent = "＋" + grid.hidden + "日";
    }
    grid.cells.forEach(function (c, i) {
      var col = i % cols, row = Math.floor(i / cols);
      var cx = first ? W / 2 + 6 * k : 28 + cellW * (col + 0.5);
      var by = first ? 400 : gridBottom - (grid.rows - 1 - row) * rowH - 4;
      var g = el("g", { transform: "translate(" + (cx - 12 * k) + "," + by + ") scale(" + k + ")" }, svg);
      if (c.kind === "past") { shadow(g); squad.push(figure(g, GOLD)); }
      else if (c.kind === "rest") ticket(g);
      else if (c.kind === "seat") { seatNode = g; seat(g); seatAt = [cx - 6 * k, by]; }
      else if (c.kind === "today") { seat(g); todayFig = figure(g, GOLD); seatAt = [cx - 6 * k, by]; }
    });
    // 輪は床の上に広がる（楕円）
    var ring = el("ellipse", { cx: seatAt[0], cy: seatAt[1], rx: 10, ry: 3, fill: "none", stroke: DOPA, "stroke-width": 3, opacity: 0 }, svg);

    // 数と一言
    var info = document.createElement("div");
    info.style.cssText = "position:absolute;left:28px;right:28px;top:478px;";
    var big = opts.streak > 0 ? opts.streak : 1;
    info.innerHTML =
      '<div style="display:flex;align-items:baseline;gap:4px">' +
        (opts.streak > 0 ? '' : '<span style="font-weight:900;font-size:18px">' + (opts.best ? "今日の1回で" : "最初の1回で") + '</span>') +
        '<span data-fly style="font-family:&quot;M PLUS Rounded 1c&quot;,sans-serif;font-weight:900;font-variant-numeric:tabular-nums;letter-spacing:-0.02em;display:inline-block;font-size:88px;line-height:.9;color:' + DOPA + ';transform-origin:0 100%">' + big + '</span>' +
        '<span style="font-weight:900;font-size:18px">' + (opts.streak > 0 ? "日連続" : "日目") + '</span>' +
      '</div>' +
      '<div data-sub style="margin-top:12px;display:flex;align-items:center;gap:8px;font-size:15px;font-weight:900;opacity:0">' +
        '<span style="color:' + (opts.done ? DOPA : ink) + '">' + opts.line + '</span>' +
        (opts.milestone ? '<span style="font-size:11px;background:' + GOLD + ';color:' + ONGOLD + ';border:2px solid ' + ONGOLD + ';border-radius:999px;padding:1px 8px;box-shadow:0 2px 0 ' + ONGOLD + '">節目</span>' : '') +
      '</div>';
    sp.appendChild(info);
    var fly = info.querySelector("[data-fly]"), sub = info.querySelector("[data-sub]");
    var homeNum = home.querySelector("[data-home-num]");

    // 引き継ぎ：大きな数を、ホームの連続記録の数の位置まで飛ばす
    var flight = null;
    function measure() {
      var p = phone.getBoundingClientRect(), a = fly.getBoundingClientRect(), b = homeNum.getBoundingClientRect();
      flight = { dx: b.left - a.left, dy: b.bottom - a.bottom, s: b.height / a.height };
    }

    var t0 = null, raf = null, skipAt = null, fired = {};
    function frame(now) {
      if (t0 === null) t0 = now;
      var t = (now - t0) / 1000;
      // ?t=0.9 で、その時刻に止めて見る（見本の確認用）
      if (FREEZE !== null) t = FREEZE;
      // 叩いたら、その場で引き継ぎへ飛ぶ。まだ鳴っていない拍は鳴らさない
      if (skipAt !== null && t < Tm.handoff) { t0 = now - Tm.handoff * 1000; t = Tm.handoff; }
      if (skipAt !== null) words.forEach(function (w, i) { fired[i] = true; });
      // 拍。名前が1語ずつ落ちて、着地でつぶれる
      words.forEach(function (w, i) {
        var u = t - Tm.beats[i];
        if (still) {
          w.style.opacity = 1; w.style.transform = "none";
          if (u >= 0 && !fired[i]) { fired[i] = true; pulse(i); }
          return;
        }
        if (u < 0 && skipAt === null) { w.style.opacity = 0; return; }
        if (u < 0) u = 1;
        w.style.opacity = 1;
        var fall = clamp(u / 0.08), y = (1 - fall) * -14;
        var v = u - 0.08, sq = v < 0 ? 0 : Math.exp(-7 * v) * Math.cos(16 * v);
        w.style.transform = "translateY(" + y + "px) scale(" + (1 + 0.1 * sq) + "," + (1 - 0.22 * sq) + ")";
        if (!fired[i]) { fired[i] = true; pulse(i); }
      });
      // 隊列の波。古い日から今日へ
      squad.forEach(function (f, i) {
        if (still) return;
        var s = Tm.waveStart + Tm.waveSpan * (squad.length > 1 ? i / (squad.length - 1) : 1) - (squad.length > 0 ? Tm.squat * 0.6 : 0);
        f.squat(dip((t - s) / Tm.squat));
      });
      // 今日の席
      var su = t - Tm.seat;
      if (su >= 0) {
        sub.style.opacity = clamp(su / 0.18);
        sub.style.transform = "translateY(" + (1 - easeOut(clamp(su / 0.25))) * 6 + "px)";
        var ru = clamp(su / 0.5);
        var rr = 10 + 40 * easeOut(ru) * (first ? 1.6 : 1);
        ring.setAttribute("rx", rr); ring.setAttribute("ry", rr * 0.3);
        ring.setAttribute("opacity", still ? 0 : 1 - ru);
        if (seatNode) seatNode.setAttribute("opacity", still ? 1 : 0.55 + 0.45 * (0.5 + 0.5 * Math.cos(su * 2 * Math.PI / 1.1)));
        if (todayFig && !still) todayFig.squat(dip(su / 0.3) + dip((su - 0.3) / 0.3));
      } else if (seatNode) seatNode.setAttribute("opacity", 0.55);
      // 引き継ぎ
      var hu = clamp((t - Tm.handoff) / (Tm.end - Tm.handoff));
      if (t >= Tm.handoff) {
        if (!flight) measure();
        var e = easeInOut(hu);
        sp.style.background = "transparent";
        home.style.opacity = 1;
        [mark, svg, sub].forEach(function (n) { n.style.opacity = (1 - clamp(hu * 2)).toString(); });
        if (still) {
          info.style.opacity = 1 - hu;
          homeNum.style.opacity = 1;
        } else {
          homeNum.style.opacity = hu >= 1 ? 1 : 0;
          fly.style.transform = "translate(" + flight.dx * e + "px," + flight.dy * e + "px) scale(" + lerp(1, flight.s, e) + ")";
          // 数の脇の「日連続」は先に消し、数だけが飛ぶ
          Array.prototype.forEach.call(info.firstChild.children, function (n) { if (n !== fly) n.style.opacity = 1 - clamp(hu * 3); });
          if (hu >= 1) fly.style.opacity = 0;
        }
      } else {
        home.style.opacity = 0;
      }
      if (opts.onTime) opts.onTime(Math.min(t, Tm.end), Tm);
      if (t < Tm.end && FREEZE === null) raf = requestAnimationFrame(frame);
      else if (opts.onEnd) opts.onEnd();
    }
    // 振動の印。見本では枠を一瞬震わせる
    function pulse(i) {
      if (opts.onBeat) opts.onBeat(i);
      phone.animate([{ transform: "translateX(0)" }, { transform: "translateX(" + (i === 2 ? 2 : 1) + "px)" }, { transform: "translateX(0)" }], { duration: 70 });
    }
    phone.addEventListener("click", function () { if (skipAt === null) skipAt = true; });
    if (still) words.forEach(function (w) { w.style.opacity = 1; });
    raf = requestAnimationFrame(frame);
    return { stop: function () { cancelAnimationFrame(raf); }, times: Tm };
  }

  // はじめての幕。1度も起動したことがないときに1回だけ（14.0秒）
  //   場面ごとに一呼吸おく。言葉は1つずつ出して、読み終わる間を置いてから次へ。
  //   1人の人形が、食べたら、しゃがんで、叩く、をゆっくりやって見せ、
  //   その人形が今週の隊列の1つめの席に入り、明日からの6人を一瞬だけ見せる。
  var INTRO = {
    beats: [0.6, 1.0, 1.4],   // Yat / Tat / Ta。最初の0.6秒は地の色だけ
    eat: 2.6,                 // 「食べたら、」人形が静かに立つ
    squat: 3.8,               // 「しゃがんで、」1.4秒かけて1回
    tap: 5.4,                 // 「叩く。」足元から輪とドパの粒
    row: 7.0,                 // 一呼吸のあと、人形が今日の席へ縮んで入り、今週の席が並ぶ
    glimpse: 8.8,             // 明日からの6人が、1人ずつ立つ
    seat: 11.0,               // ほかの席が引き、今日の席と「1人目」の一言だけになる
    handoff: 13.6,
    end: 14.0,
    labels: ["名前", "やって見せる", "今週の席", "今日の席", "引き継ぎ"],
    marks: [["叩く", 5.7]]
  };
  var INTRO_STILL = Object.assign({}, INTRO);

  function easeSine(x) { return (1 - Math.cos(Math.PI * clamp(x))) / 2; }

  function renderIntro(root, opts) {
    var W = 320, H = 660;
    var still = !!opts.still, dark = !!opts.dark, Tm = still ? INTRO_STILL : INTRO;
    var paper = dark ? "#16120F" : "#FBF6EE", ink = dark ? "#F5EEE3" : "#1C1916", mute = dark ? "#A89C8E" : "#6E655C", card = dark ? "#231D18" : "#FFFFFF";
    var built = buildPhone(root, opts, W, H, paper, ink, mute, card);
    var phone = built.phone, home = built.home;
    var homeNum = home.querySelector("[data-home-num]");

    var sp = document.createElement("div");
    sp.style.cssText = "position:absolute;inset:0;background:" + paper + ";";
    phone.appendChild(sp);

    var mark = document.createElement("div");
    mark.style.cssText = "position:absolute;left:0;right:0;top:78px;display:flex;justify-content:center;gap:9px;font-family:'M PLUS Rounded 1c',sans-serif;font-weight:900;font-size:30px;letter-spacing:-0.02em;";
    var words = ["Yat", "Tat", "Ta"].map(function (w, i) {
      var s = document.createElement("span");
      s.textContent = w;
      s.style.cssText = "display:inline-block;transform-origin:50% 100%;opacity:0;" + (i === 2 ? "color:" + DOPA + ";" : "");
      mark.appendChild(s);
      return s;
    });
    sp.appendChild(mark);

    var svg = el("svg", { width: W, height: H, style: "position:absolute;inset:0;overflow:visible" });
    sp.appendChild(svg);

    // 今週の席。今日（左端）から7日。曜日は今日から数える
    var cols = 7, cellW = (W - 56) / cols, rowBase = 372, kRow = 0.46;
    var names = ["日", "月", "火", "水", "木", "金", "土"];
    var rowG = el("g", {}, svg);
    var seats = [], ghosts = [], dayLabels = [];
    for (var i = 0; i < cols; i++) {
      var cx = 28 + cellW * (i + 0.5);
      var g = el("g", { transform: "translate(" + (cx - 12 * kRow) + "," + rowBase + ") scale(" + kRow + ")", opacity: 0 }, rowG);
      seats.push(g);
      if (i === cols - 1) ticket(g); else seat(g, i === 0);
      if (i > 0 && i < cols - 1) {
        var gg = el("g", { transform: "translate(" + (cx - 12 * kRow) + "," + rowBase + ") scale(" + kRow + ")", opacity: 0 }, rowG);
        ghosts.push(figure(gg, GOLD));
      }
      var lab = el("text", { x: cx, y: rowBase + 22, "text-anchor": "middle", "font-size": 11, "font-weight": 700, fill: i === 0 ? DOPA : mute, opacity: 0 }, rowG);
      lab.textContent = i === 0 ? "今日" : names[(opts.todayWeekday + i) % 7];
      dayLabels.push(lab);
    }
    var passNote = el("text", { x: 28 + cellW * 6.5, y: rowBase + 40, "text-anchor": "middle", "font-size": 10, "font-weight": 700, fill: SIGNAL, opacity: 0 }, svg);
    passNote.textContent = "休み券";

    // やって見せる1人。まん中に大きく立ち、あとで今日の席へ縮んで入る
    var big = { cx: W / 2, by: 400, k: 2.1 };
    var seatPos = { cx: 28 + cellW * 0.5, by: rowBase, k: kRow };
    var actor = el("g", { opacity: 0 }, svg);
    var hero = figure(actor, GOLD);
    var ring = el("ellipse", { cx: W / 2 - 6 * 2.1, cy: 401, rx: 10, ry: 3, fill: "none", stroke: DOPA, "stroke-width": 3, opacity: 0 }, svg);
    var grains = [0, 1, 2, 3, 4, 5, 6, 7].map(function () { return el("circle", { r: 4, fill: DOPA, opacity: 0 }, svg); });
    var seatRing = el("ellipse", { cx: seatPos.cx - 6 * kRow, cy: rowBase, rx: 10, ry: 3, fill: "none", stroke: DOPA, "stroke-width": 3, opacity: 0 }, svg);

    // 言葉は1つずつ。前の言葉が消えてから、次の言葉が出る
    function line(top, size, html) {
      var d = document.createElement("div");
      d.style.cssText = "position:absolute;left:20px;right:20px;top:" + top + "px;text-align:center;font-weight:900;font-size:" + size + "px;line-height:1.6;opacity:0;white-space:nowrap;";
      d.innerHTML = html;
      sp.appendChild(d);
      return d;
    }
    var phr = [line(458, 24, "食べたら、"), line(458, 24, "しゃがんで、"), line(458, 24, "<span style='color:" + DOPA + "'>叩く。</span>")];
    var sayA = line(424, 17, "1日1回で、1人ずつ。");
    var sayB = line(452, 17, "<span style='color:" + DOPA + "'>来週には、7人の隊になる。</span>");

    // 終わりの一言と数
    var info = document.createElement("div");
    info.style.cssText = "position:absolute;left:28px;right:28px;top:478px;";
    info.innerHTML =
      '<div data-num style="display:flex;align-items:baseline;gap:4px;opacity:0"><span style="font-weight:900;font-size:18px">最初の1回で</span>' +
      '<span data-fly style="display:inline-block;font-family:&quot;M PLUS Rounded 1c&quot;,sans-serif;font-weight:900;font-size:88px;line-height:.9;color:' + DOPA + ';transform-origin:0 100%">1</span>' +
      '<span style="font-weight:900;font-size:18px">日目</span></div>' +
      '<div data-last style="margin-top:12px;font-size:15px;font-weight:900;opacity:0">1人目は、今日のあなたです。</div>';
    sp.appendChild(info);
    var fly = info.querySelector("[data-fly]"), numRow = info.querySelector("[data-num]"), last = info.querySelector("[data-last]");

    // 場面の頭。叩くと次の場面の頭へ進む（一度に最後まで飛ばない）
    var chapters = [Tm.eat, Tm.squat, Tm.tap, Tm.row, Tm.glimpse, Tm.seat, Tm.handoff];
    var t0 = null, raf = null, jumpTo = null, fired = {}, flight = null, nowT = 0;
    function at(t, a, d) { return clamp((t - a) / d); }
    // a から入って b の手前で消える。入りと消えはゆっくり
    function window_(t, a, b, fin, fout) { return easeSine(at(t, a, fin)) * (1 - easeSine(at(t, b - fout, fout))); }
    function place(g, p, k) { g.setAttribute("transform", "translate(" + (p.cx - 12 * k) + "," + p.by + ") scale(" + k + ")"); }
    function buzz(key, strong) {
      if (fired[key]) return;
      fired[key] = true;
      phone.animate([{ transform: "translateX(0)" }, { transform: "translateX(" + (strong ? 2 : 1) + "px)" }, { transform: "translateX(0)" }], { duration: 70 });
    }
    function frame(now) {
      if (t0 === null) t0 = now;
      if (jumpTo !== null) { t0 = now - jumpTo * 1000; jumpTo = null; }
      var t = (now - t0) / 1000;
      if (FREEZE !== null) t = FREEZE;
      nowT = t;
      // 名前。地の色だけの0.6秒のあと、1語ずつゆっくり落ちる
      words.forEach(function (w, i) {
        var u = t - Tm.beats[i];
        if (u < 0) { w.style.opacity = 0; return; }
        w.style.opacity = easeSine(u / 0.15);
        if (still) { w.style.transform = "none"; } else {
          var y = (1 - easeOut(clamp(u / 0.12))) * -16, v = u - 0.12, sq = v < 0 ? 0 : Math.exp(-6 * v) * Math.cos(13 * v);
          w.style.transform = "translateY(" + y + "px) scale(" + (1 + 0.1 * sq) + "," + (1 - 0.22 * sq) + ")";
        }
        if (u < 0.3) buzz("b" + i, false);
      });
      // 名前を眺める間を置いてから、小さく上へ退く
      var shrink = easeSine(at(t, Tm.eat - 0.6, 0.6));
      mark.style.transform = still ? "none" : "translateY(" + (-14 * shrink) + "px) scale(" + (1 - 0.25 * shrink) + ")";

      // やって見せる1人
      var appear = easeSine(at(t, Tm.eat, 0.6)), e = easeSine(at(t, Tm.row, 0.9));
      if (still) e = t >= Tm.row + 0.45 ? 1 : 0;
      var k = lerp(big.k, seatPos.k, e);
      place(actor, { cx: lerp(big.cx, seatPos.cx, e), by: lerp(big.by, seatPos.by, e) + (still ? 0 : (1 - appear) * 16) }, k);
      // 今日はまだ叩いていない。席に着いたら人形は消え、光の差す床の印だけが残る
      actor.setAttribute("opacity", (appear * (1 - easeSine(at(t, Tm.row + 0.8, 0.4)))).toString());
      var d = 0;
      var su = (t - Tm.squat - 0.4) / 1.4;
      if (!still) {
        // 0.6秒で下り、0.2秒とどまり、0.6秒で上る
        d = su <= 0 || su >= 1 ? 0 : su < 0.43 ? easeSine(su / 0.43) : su < 0.57 ? 1 : 1 - easeSine((su - 0.57) / 0.43);
      } else if (t >= Tm.squat + 0.4 && t < Tm.tap) d = 1;
      hero.squat(d);

      // 言葉。1つずつ、読み終わる間を置いて
      var ends = [Tm.squat, Tm.tap, Tm.row - 0.2];
      [Tm.eat, Tm.squat, Tm.tap].forEach(function (a, i) {
        phr[i].style.opacity = window_(t, a + 0.1, ends[i], 0.5, 0.45);
      });
      // 叩く：言葉が出てから、足元から輪とドパの粒
      var tapAt = Tm.tap + 0.3, tu = at(t, tapAt, 0.9);
      if (t >= tapAt) buzz("tap", true);
      ring.setAttribute("rx", 10 + 70 * easeOut(tu)); ring.setAttribute("ry", (10 + 70 * easeOut(tu)) * 0.3);
      ring.setAttribute("opacity", t >= tapAt && !still ? 1 - tu : 0);
      grains.forEach(function (gr, i) {
        var ang = -Math.PI * (0.15 + 0.7 * i / 7), dist = 30 + 76 * easeOut(tu);
        gr.setAttribute("cx", W / 2 - 6 * 2.1 + Math.cos(ang) * dist);
        gr.setAttribute("cy", 404 + Math.sin(ang) * dist);
        gr.setAttribute("opacity", t >= tapAt && !still ? 1 - tu : 0);
      });

      // 今週の席。1つずつ、間を置いて並ぶ
      var rowOut = easeSine(at(t, Tm.seat, 0.6));
      seats.forEach(function (g, i) {
        var s = easeSine(at(t, Tm.row + 1.0 + i * 0.12, 0.35));
        if (i === 0 && t >= Tm.seat) return;
        g.setAttribute("opacity", (i === 0 ? s : s * (1 - rowOut)).toString());
      });
      dayLabels.forEach(function (l, i) {
        var s = easeSine(at(t, Tm.row + 1.1 + i * 0.12, 0.35));
        l.setAttribute("opacity", (s * (1 - rowOut)).toString());
      });
      passNote.setAttribute("opacity", (easeSine(at(t, Tm.row + 1.9, 0.4)) * (1 - rowOut)).toString());
      sayA.style.opacity = window_(t, Tm.row + 1.2, Tm.seat + 0.2, 0.5, 0.5);
      // 明日からの6人が、1人ずつ立って、しゃがんで、いっしょに消える
      ghosts.forEach(function (f, i) {
        var a = Tm.glimpse + i * 0.15;
        var o = still ? 0 : easeSine(at(t, a, 0.25)) * (1 - easeSine(at(t, Tm.glimpse + 1.6, 0.5)));
        f.g.parentNode.setAttribute("opacity", (o * 0.85).toString());
        f.squat(still ? 0 : dip((t - a - 0.1) / 0.5));
      });
      sayB.style.opacity = window_(t, Tm.glimpse + 0.3, Tm.seat + 0.2, 0.5, 0.5);

      // 今日の席だけが残り、まん中へ寄る
      if (t >= Tm.seat) {
        var settle = still ? (t >= Tm.seat + 0.4 ? 1 : 0) : easeSine(at(t, Tm.seat + 0.2, 0.8));
        var to = { cx: lerp(seatPos.cx, W / 2 + 6 * 1.3, settle), by: lerp(rowBase, 404, settle) };
        var ks = lerp(kRow, 1.3, settle);
        place(seats[0], to, ks);
        var ru = at(t, Tm.seat + 1.0, 0.8);
        if (t >= Tm.seat + 1.0) buzz("seat", true);
        seatRing.setAttribute("cx", to.cx - 6 * ks);
        seatRing.setAttribute("cy", to.by);
        seatRing.setAttribute("rx", 10 + 56 * easeOut(ru)); seatRing.setAttribute("ry", (10 + 56 * easeOut(ru)) * 0.3);
        seatRing.setAttribute("opacity", t >= Tm.seat + 1.0 && !still ? 1 - ru : 0);
        // 息をするように、ゆっくり濃淡を繰り返す
        seats[0].setAttribute("opacity", (0.6 + 0.4 * (0.5 + 0.5 * Math.cos((t - Tm.seat) * 2 * Math.PI / 1.8))).toString());
      } else {
        seatRing.setAttribute("opacity", 0);
      }
      numRow.style.opacity = easeSine(at(t, Tm.seat + 1.0, 0.5));
      last.style.opacity = easeSine(at(t, Tm.seat + 1.6, 0.5));

      // 引き継ぎ
      var hu = at(t, Tm.handoff, Tm.end - Tm.handoff);
      if (t >= Tm.handoff) {
        if (!flight) {
          var a2 = fly.getBoundingClientRect(), b2 = homeNum.getBoundingClientRect();
          flight = { dx: b2.left - a2.left, dy: b2.bottom - a2.bottom, s: b2.height / a2.height };
        }
        var he = easeInOut(hu);
        sp.style.background = "transparent";
        home.style.opacity = 1;
        [mark, svg, last].forEach(function (n) { n.style.opacity = (1 - clamp(hu * 2)).toString(); });
        if (still) { info.style.opacity = 1 - hu; homeNum.style.opacity = 1; }
        else {
          homeNum.style.opacity = hu >= 1 ? 1 : 0;
          fly.style.transform = "translate(" + flight.dx * he + "px," + flight.dy * he + "px) scale(" + lerp(1, flight.s, he) + ")";
          Array.prototype.forEach.call(numRow.children, function (n) { if (n !== fly) n.style.opacity = 1 - clamp(hu * 3); });
          if (hu >= 1) fly.style.opacity = 0;
        }
      } else home.style.opacity = 0;
      if (opts.onTime) opts.onTime(Math.min(t, Tm.end), Tm);
      if (t < Tm.end && FREEZE === null) raf = requestAnimationFrame(frame);
    }
    phone.addEventListener("click", function () {
      var next = chapters.filter(function (c) { return c > nowT + 0.05; })[0];
      if (next === undefined) return;
      // 飛ばした場面の振動は鳴らさない
      if (next > Tm.beats[2]) ["b0", "b1", "b2"].forEach(function (k) { fired[k] = true; });
      if (next > Tm.tap + 0.3) fired.tap = true;
      jumpTo = next;
    });
    raf = requestAnimationFrame(frame);
    return { stop: function () { cancelAnimationFrame(raf); }, times: Tm };
  }

  // 見本の再生台。状態のタブ、暗い配色、ひかえめモード、もう一度、と時刻の帯を付ける
  //   states: [{ id, label, opts }]。root の中身は作り直す
  function stage(root, states, initial) {
    root.innerHTML =
      '<div class="flex flex-wrap items-center justify-between gap-3">' +
        '<div role="tablist" class="flex flex-wrap gap-2">' + states.map(function (s) {
          return '<button type="button" role="tab" data-tab="' + s.id + '" class="tabbtn rounded-full border-2 border-ink px-3 py-1 text-xs font-bold">' + s.label + '</button>';
        }).join("") + '</div>' +
        '<div class="flex flex-wrap items-center gap-4 font-mono text-xs text-mute">' +
          '<label class="flex cursor-pointer items-center gap-2"><input type="checkbox" data-dark class="accent-dopa"> 暗い配色</label>' +
          '<label class="flex cursor-pointer items-center gap-2"><input type="checkbox" data-still class="accent-dopa"> ひかえめモード</label>' +
          '<button type="button" data-replay class="rounded-full border-2 border-ink bg-gold px-3 py-1 font-sans text-xs font-black text-ink shadow-[0_3px_0_#1C1916] active:translate-y-[3px] active:shadow-none">▶ もう一度</button>' +
        '</div>' +
      '</div>' +
      '<div class="mt-6 grid items-start gap-8 rounded-2xl bg-[repeating-linear-gradient(45deg,#FBF6EE_0_10px,#F5EDE0_10px_20px)] p-5 sm:p-8 lg:grid-cols-[auto_1fr]">' +
        '<div data-phone class="mx-auto"></div>' +
        '<div class="min-w-0">' +
          '<p data-note-id class="font-mono text-xs text-mute"></p>' +
          '<p data-note-title class="mt-1 font-display text-xl"></p>' +
          '<div data-note class="mt-3 space-y-2 text-sm leading-relaxed text-ink/80"></div>' +
          '<div class="mt-8">' +
            '<p class="font-mono text-[10px] uppercase tracking-[0.2em] text-mute">timeline</p>' +
            '<div data-line class="relative mt-3 h-24 rounded-xl border-2 border-ink bg-white"></div>' +
            '<p class="mt-2 text-xs text-mute">枠の中を押すと、その場で引き継ぎへ飛びます（アプリでは画面のどこを叩いても同じ）。</p>' +
          '</div>' +
        '</div>' +
      '</div>';
    var tabs = root.querySelectorAll("[data-tab]"), dark = root.querySelector("[data-dark]"), still = root.querySelector("[data-still]");
    var phoneBox = root.querySelector("[data-phone]"), line = root.querySelector("[data-line]");
    var q = /[?&]s=(\w+)/.exec(location.search);
    var current = (q && q[1]) || initial || states[0].id, player = null;
    if (/[?&]dark=1/.test(location.search)) dark.checked = true;
    if (/[?&]still=1/.test(location.search)) still.checked = true;

    function drawLine(Tm) {
      var end = Tm.end, pct = function (t) { return (t / end * 100).toFixed(2) + "%"; };
      // 拍の間が帯の上で狭すぎるときは、名前を1つの札にまとめ、点だけを3つ打つ
      var tight = (Tm.beats[1] - Tm.beats[0]) / end < 0.05;
      var marks = (tight ? [['', Tm.beats[0], 'ink'], ['Yat Tat Ta', Tm.beats[1], 'ink'], ['', Tm.beats[2], 'dopa']] : [['Yat', Tm.beats[0], 'ink'], ['Tat', Tm.beats[1], 'ink'], ['Ta!', Tm.beats[2], 'dopa']]).concat((Tm.marks || []).map(function (m) { return [m[0], m[1], 'dopa']; }));
      var zones = Tm.labels
        ? [[0, Tm.eat, Tm.labels[0]], [Tm.eat, Tm.row, Tm.labels[1]], [Tm.row, Tm.seat, Tm.labels[2]], [Tm.seat, Tm.handoff, Tm.labels[3]], [Tm.handoff, end, Tm.labels[4]]]
        : [[0, Tm.seat, still.checked ? '置く' : '名前と波'], [Tm.seat, Tm.handoff, '今日の席'], [Tm.handoff, end, '引き継ぎ']];
      var tint = ['bg-dopa-soft/70', 'bg-white', 'bg-dopa-soft/40', 'bg-white', 'bg-[#F5EDE0]'];
      var html = '';
      zones.forEach(function (z, i) {
        var c = i === zones.length - 1 ? 'bg-[#F5EDE0]' : (zones.length === 3 ? ['bg-dopa-soft/70', 'bg-white'][i] : tint[i]);
        html += '<div class="absolute inset-y-0 ' + c + '" style="left:' + pct(z[0]) + ';width:' + ((z[1] - z[0]) / end * 100).toFixed(2) + '%"></div>' +
          ((z[1] - z[0]) / end > 0.06 ? '<p class="absolute top-1.5 whitespace-nowrap font-mono text-[9px] font-bold text-mute" style="left:calc(' + pct(z[0]) + ' + 6px)">' + z[2] + '</p>' : '');
      });
      marks.forEach(function (m) {
        html += '<div class="absolute bottom-6 -translate-x-1/2 text-center" style="left:' + pct(m[1]) + '"><span class="block font-mono text-[10px] font-black text-' + m[2] + '">' + m[0] + '</span><span class="mx-auto mt-0.5 block h-3 w-3 rounded-full border-2 border-ink ' + (m[2] === 'dopa' ? 'bg-dopa' : 'bg-gold') + '"></span></div>';
      });
      for (var t = 0; t < end - 0.2; t += end > 3 ? 1 : 0.5) {
        html += '<span class="absolute bottom-1 -translate-x-1/2 font-mono text-[9px] text-mute" style="left:' + pct(t) + '">' + t + 's</span>';
      }
      html += '<span class="absolute bottom-1 right-1 font-mono text-[9px] text-mute">' + end + 's</span>';
      html += '<div data-head class="absolute inset-y-0 w-0.5 bg-ink" style="left:0"></div>';
      line.innerHTML = '<div class="absolute inset-0 overflow-hidden rounded-[10px]">' + html + '</div>';
      return line.querySelector("[data-head]");
    }

    function play() {
      if (player) player.stop();
      var st = states.filter(function (s) { return s.id === current; })[0];
      var head = null;
      root.querySelector("[data-note-id]").textContent = "state / " + st.id;
      root.querySelector("[data-note-title]").textContent = st.label;
      root.querySelector("[data-note]").innerHTML = st.note || "";
      player = render(phoneBox, Object.assign({}, st.opts, {
        dark: dark.checked, still: still.checked,
        onTime: function (t, tm) { if (head) head.style.left = (t / tm.end * 100) + "%"; }
      }));
      head = drawLine(player.times);
    }
    function show(id) {
      current = id;
      tabs.forEach(function (t) { t.setAttribute("aria-selected", t.dataset.tab === id ? "true" : "false"); });
      play();
    }
    tabs.forEach(function (t) { t.addEventListener("click", function () { show(t.dataset.tab); }); });
    [dark, still].forEach(function (c) { c.addEventListener("change", play); });
    root.querySelector("[data-replay]").addEventListener("click", play);
    show(current);
  }

  return { render: render, stage: stage, T: T, STILL: STILL, cells: cells };
})();
