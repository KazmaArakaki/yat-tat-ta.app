// 履歴のグラフの見本。iOS の HistoryChart と同じ決まりで描く。
// 横に記録日、縦にその日の時刻（午前4時から翌朝4時、上ほど遅い）。
// 記録1件を、スクワットマンのしゃがんだ人形1つで置く。人形の面積はドパに比例する。押した人形は立つ⇄しゃがむを繰り返す。
// 背景には、日ごとのドパ（dopa 色の薄い面）と7日移動平均（signal 色の線と薄い面）を重ねる。斜線は使わない。
window.HistoryChart = (function () {
  var DAY_W = 34;      // 1日の列の幅。スマホの幅で7日ほど見える
  var AXIS_W = 34;     // 左の時刻の列
  var DATE_H = 34;     // 下の日付の帯
  var TOP = 10;
  var HOURS = [6, 9, 12, 15, 18, 21, 24, 27]; // 4時起点で並べた目盛り（24 = 0:00、27 = 3:00）
  var WEEK = ["日", "月", "火", "水", "木", "金", "土"];
  var NS = "http://www.w3.org/2000/svg";
  var uid = 0;

  // 決まった並びの乱数。見本がリロードで変わらないように
  function rng(seed) {
    return function () {
      seed = (seed * 1664525 + 1013904223) % 4294967296;
      return seed / 4294967296;
    };
  }

  function addDays(d, n) {
    var x = new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
    return x;
  }

  // サンプルの記録。today で終わる n 日分。朝昼晩に叩き、ときどき抜ける
  // rest: 記録のない日（休み券で埋まる日）を today から何日前かで
  function sample(opts) {
    var n = opts.days, rand = rng(opts.seed || 7);
    var today = opts.today || new Date(2026, 9, 6);
    var rest = opts.rest || [];
    var days = [];
    for (var i = n - 1; i >= 0; i--) {
      var date = addDays(today, -i), records = [];
      if (rest.indexOf(i) < 0) {
        if (i === 0 && opts.todayRecords) {
          records = opts.todayRecords.slice();
        } else {
          // 時計の時刻から4時間引いて、4時からの分にする
          var meals = [[7 * 60 + 20 - 240, 70], [12 * 60 + 5 - 240, 60], [19 * 60 - 240, 100]];
          meals.forEach(function (m, k) {
            if (rand() < (k === 1 ? 0.55 : 0.8)) {
              var reps = rand() < 0.15 ? 10 : rand() < 0.2 ? 30 : 20;
              var bonus = rand() < 0.22 ? 6 + Math.floor(rand() * 20) : 0;
              records.push({ min: m[0] + Math.floor(rand() * m[1]), reps: reps, bonus: bonus });
            }
          });
          // 夜食のあと。午前4時までは前の日
          if (rand() < 0.08) records.push({ min: 24 * 60 + 40 - 240 + Math.floor(rand() * 60), reps: 20, bonus: 0 });
          if (!records.length) records.push({ min: 20 * 60 - 240 + Math.floor(rand() * 90), reps: 20, bonus: 0 });
        }
      }
      records.sort(function (a, b) { return a.min - b.min; });
      days.push({ date: date, records: records, rest: rest.indexOf(i) >= 0, today: i === 0 });
    }
    return withTotals(days);
  }

  // 日ごとのドパと7日移動平均。記録を始める前の日は0ドパとして数える
  function withTotals(days) {
    days.forEach(function (d) {
      d.dopa = d.records.reduce(function (s, r) { return s + r.reps + r.bonus; }, 0);
    });
    days.forEach(function (d, i) {
      var s = 0;
      for (var k = Math.max(0, i - 6); k <= i; k++) s += days[k].dopa;
      d.avg = s / 7;
    });
    return days;
  }

  // 午前4時からの分（4:00 = 0、翌3:59 = 1439）
  function clock(min) {
    var h = Math.floor(min / 60) + 4, m = min % 60;
    if (h >= 24) h -= 24;
    return h + ":" + (m < 10 ? "0" : "") + m;
  }

  function label(d) {
    return (d.date.getMonth() + 1) + "/" + d.date.getDate() + "（" + WEEK[d.date.getDay()] + "）";
  }

  // 人形の高さ。面積をドパに比例させる（高さは平方根）。14〜46px
  function figureHeight(dopa) {
    return Math.max(14, Math.min(46, 6.5 * Math.sqrt(dopa)));
  }

  function el(name, attrs, parent) {
    var e = document.createElementNS(NS, name);
    for (var k in attrs) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  }

  // 点を通るなめらかな線（Catmull-Rom を3次ベジェに直す）
  function smooth(pts, floor) {
    var d = "M" + pts[0][0] + "," + pts[0][1];
    for (var i = 0; i < pts.length - 1; i++) {
      var p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2;
      // 制御点が底より下へ出ると、0ドパの日に線が底を突き抜ける。底で止める
      var c1x = p1[0] + (p2[0] - p0[0]) / 6, c1y = Math.min(floor, p1[1] + (p2[1] - p0[1]) / 6);
      var c2x = p2[0] - (p3[0] - p1[0]) / 6, c2y = Math.min(floor, p2[1] - (p3[1] - p1[1]) / 6);
      d += " C" + c1x + "," + c1y + " " + c2x + "," + c2y + " " + p2[0] + "," + p2[1];
    }
    return d;
  }

  // el: 描き込む先。opts.height: グラフ全体の高さ。opts.onSelect(day, record): 人形を押したとき
  function render(root, days, opts) {
    opts = opts || {};
    var id = "hc" + (++uid);
    var H = opts.height || 380;
    var P = H - TOP - DATE_H;               // 時刻を置く高さ
    var W = days.length * DAY_W;
    var dark = !!opts.dark;
    var ink = dark ? "#F5EEE3" : "#1C1916", mute = dark ? "#A89C8E" : "#6E655C", rule = dark ? "#3A312A" : "#E7DDCC";
    var y = function (min) { return TOP + P - (min / 1440) * P; };
    var max = Math.max(10, Math.max.apply(null, days.map(function (d) { return d.dopa; }))) * 1.15;
    var v = function (dopa) { return TOP + P - (dopa / max) * P; };

    root.innerHTML = "";
    root.style.display = "flex";

    // 左の時刻の列。横に流れても残す
    var axis = el("svg", { width: AXIS_W, height: H, "aria-hidden": "true" });
    axis.style.flex = "none";
    HOURS.forEach(function (h) {
      var t = el("text", { x: AXIS_W - 5, y: y((h - 4) * 60) + 3, "text-anchor": "end", "font-size": 9, "font-family": "JetBrains Mono", fill: mute }, axis);
      t.textContent = (h % 24) + ":00";
    });
    root.appendChild(axis);

    var scroller = document.createElement("div");
    // min-width:0 がないと、flex の子は中身（全日分の幅）まで広がり、スクロールせずに外で切られる
    scroller.style.cssText = "flex:1;min-width:0;overflow-x:auto;overflow-y:hidden;scrollbar-width:none;cursor:grab;touch-action:pan-x;";
    root.appendChild(scroller);
    var svg = el("svg", { width: W, height: H, role: "img", "aria-label": "日ごとのドパと7日移動平均、記録した時刻のグラフ" });
    svg.style.display = "block";
    scroller.appendChild(svg);

    var defs = el("defs", {}, svg);
    var fig = el("g", { id: id + "f" }, defs);
    [["12,0 0,0 15,-15 -7,-25 3,-55", 15, ink], ["3,-55 17,-55 31,-56", 15, ink]].forEach(function (s) {
      el("polyline", { points: s[0], fill: "none", stroke: s[2], "stroke-width": s[1], "stroke-linecap": "round", "stroke-linejoin": "round" }, fig);
    });
    el("circle", { cx: 7, cy: -69, r: 12, fill: ink }, fig);
    ["12,0 0,0 15,-15 -7,-25 3,-55", "3,-55 17,-55 31,-56"].forEach(function (s) {
      el("polyline", { points: s, fill: "none", stroke: "currentColor", "stroke-width": 9, "stroke-linecap": "round", "stroke-linejoin": "round" }, fig);
    });
    el("circle", { cx: 7, cy: -69, r: 8.5, fill: "currentColor" }, fig);

    // 押した人形。立つ⇄しゃがむを 0.8 秒で繰り返す（スクワットマンの点と同じ）
    var STAND = { legs: "12,0 0,0 0,-21 0,-42 0,-72", arm: "0,-72 4,-58 6,-46", head: [2, -86] };
    var SQUAT = { legs: "12,0 0,0 15,-15 -7,-25 3,-55", arm: "3,-55 17,-55 31,-56", head: [7, -69] };
    var still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    var moving = el("g", { id: id + "m" }, defs);
    function swing(node, attr, a, b) {
      if (still) return;
      el("animate", { attributeName: attr, dur: "0.8s", repeatCount: "indefinite", values: a + ";" + b + ";" + a,
        keyTimes: "0;0.45;1", calcMode: "spline", keySplines: ".3 0 .2 1;.4 0 .4 1" }, node);
    }
    [["legs", 15, ink], ["arm", 15, ink], ["legs", 9, "currentColor"], ["arm", 9, "currentColor"]].forEach(function (s) {
      var line = el("polyline", { points: SQUAT[s[0]], fill: "none", stroke: s[2], "stroke-width": s[1], "stroke-linecap": "round", "stroke-linejoin": "round" }, moving);
      swing(line, "points", STAND[s[0]], SQUAT[s[0]]);
    });
    [[12, ink], [8.5, "currentColor"]].forEach(function (c) {
      var head = el("circle", { cx: 7, cy: -69, r: c[0], fill: c[1] }, moving);
      swing(head, "cx", STAND.head[0], SQUAT.head[0]);
      swing(head, "cy", STAND.head[1], SQUAT.head[1]);
    });

    // 今日の列と休み券の日
    days.forEach(function (d, i) {
      if (d.today) el("rect", { x: i * DAY_W, y: 0, width: DAY_W, height: TOP + P, fill: dark ? "#3A1726" : "#FFE6F0", "fill-opacity": 0.8 }, svg);
    });
    // 時刻の横線と、日の境の縦線
    HOURS.forEach(function (h) {
      el("line", { x1: 0, x2: W, y1: y((h - 4) * 60), y2: y((h - 4) * 60), stroke: rule, "stroke-width": h === 12 || h === 24 ? 1.2 : 0.7, "stroke-dasharray": h === 24 ? "" : "2 3" }, svg);
    });

    // 面グラフ。列の真ん中を通し、両端は列の端まで伸ばす
    function area(key, color, opacity) {
      var pts = days.map(function (d, i) { return [i * DAY_W + DAY_W / 2, v(d[key])]; });
      pts.unshift([0, pts[0][1]]);
      pts.push([W, pts[pts.length - 1][1]]);
      var line = smooth(pts, TOP + P);
      el("path", { d: line + " L" + W + "," + (TOP + P) + " L0," + (TOP + P) + " Z", fill: color, "fill-opacity": opacity }, svg);
      el("path", { d: line, fill: "none", stroke: color, "stroke-width": 2, "stroke-linejoin": "round" }, svg);
    }
    area("dopa", "#E5337A", dark ? 0.22 : 0.14);
    area("avg", "#2F79F7", dark ? 0.16 : 0.1);
    el("line", { x1: 0, x2: W, y1: TOP + P, y2: TOP + P, stroke: ink, "stroke-width": 2 }, svg);

    // 日付の帯
    days.forEach(function (d, i) {
      var cx = i * DAY_W + DAY_W / 2;
      var first = d.date.getDate() === 1 || i === 0;
      var t = el("text", { x: cx, y: TOP + P + 14, "text-anchor": "middle", "font-size": 10, "font-weight": 900, "font-family": "M PLUS Rounded 1c, Noto Sans JP", fill: d.today ? "#E5337A" : ink }, svg);
      t.textContent = first ? (d.date.getMonth() + 1) + "/" + d.date.getDate() : d.date.getDate();
      var w = el("text", { x: cx, y: TOP + P + 26, "text-anchor": "middle", "font-size": 8, "font-weight": 700, "font-family": "Noto Sans JP", fill: d.today ? "#E5337A" : mute }, svg);
      w.textContent = d.today ? "今日" : WEEK[d.date.getDay()];
      if (d.rest) {
        // 休み券を使った日。帯の休み券と同じ青い札
        el("rect", { x: cx - 5, y: y(10 * 60) - 7, width: 10, height: 13, rx: 2, fill: "#2F79F7" }, svg);
        el("line", { x1: cx - 3.5, x2: cx + 3.5, y1: y(10 * 60) - 1, y2: y(10 * 60) - 1, stroke: "#fff", "stroke-width": 1.4, "stroke-dasharray": "1.4 1.4" }, svg);
      }
    });

    // 人形。押すと詳細
    var selected = null, selectedUse = null;
    days.forEach(function (d, i) {
      d.records.forEach(function (r, k) {
        var dopa = r.reps + r.bonus, h = figureHeight(dopa), s = h / 88;
        var cx = i * DAY_W + DAY_W / 2, cy = y(r.min);
        var g = el("g", { tabindex: 0, role: "button", "aria-label": label(d) + " " + clock(r.min) + "、" + r.reps + "回" + (r.bonus ? "、フィーバー" + r.bonus + "ドパ" : "") }, svg);
        g.style.cursor = "pointer";
        g.style.color = r.bonus ? "#E5337A" : "#E9A800";
        g.style.outline = "none";
        // 押しやすさのため、見えない当たりを 30px 四方以上にとる
        var hit = Math.max(30, h);
        el("rect", { x: cx - hit / 2, y: cy - hit / 2, width: hit, height: hit, fill: "transparent" }, g);
        var ring = el("circle", { cx: cx, cy: cy, r: h * 0.62, fill: "none", stroke: ink, "stroke-width": 2, "stroke-dasharray": "3 2", opacity: 0 }, g);
        // 位置と大きさは外側の g で決める。内側の use は、出てくるときの弾みだけを CSS で付ける
        var place = el("g", { transform: "translate(" + (cx - 11 * s) + "," + (cy + 37 * s) + ") scale(" + s + ")" }, g);
        var u = el("use", { href: "#" + id + "f" }, place);
        if (!opts.still) {
          u.style.transformBox = "fill-box";
          u.style.transformOrigin = "center";
          u.style.animation = "hcpop .4s cubic-bezier(.2,1.4,.4,1) both";
          u.style.animationDelay = Math.max(0, (i - days.length + 8)) * 60 + k * 30 + "ms";
        }
        function pick() {
          if (selected) selected.setAttribute("opacity", 0);
          if (selectedUse) selectedUse.setAttribute("href", "#" + id + "f");
          ring.setAttribute("opacity", 1);
          u.setAttribute("href", "#" + id + "m");
          selected = ring;
          selectedUse = u;
          if (opts.onSelect) opts.onSelect(d, r);
        }
        g.addEventListener("click", pick);
        g.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); pick(); } });
        if (opts.preselect && opts.preselect(d, r)) pick();
      });
    });

    if (!document.getElementById("hc-style")) {
      var st = document.createElement("style");
      st.id = "hc-style";
      st.textContent = "@keyframes hcpop{0%{transform:scale(.2);opacity:0}70%{transform:scale(1.12);opacity:1}100%{transform:scale(1)}}" +
        "[data-hc] div::-webkit-scrollbar{display:none}";
      document.head.appendChild(st);
    }
    root.setAttribute("data-hc", "");
    // マウスでも横になぞれるように。ドラッグで流し、縦のホイールも横に回す
    var drag = null, moved = false;
    scroller.addEventListener("pointerdown", function (e) {
      if (e.pointerType !== "mouse") return;
      drag = { x: e.clientX, left: scroller.scrollLeft };
      moved = false;
      scroller.style.cursor = "grabbing";
    });
    window.addEventListener("pointermove", function (e) {
      if (!drag) return;
      var dx = e.clientX - drag.x;
      if (Math.abs(dx) > 4) moved = true;
      scroller.scrollLeft = drag.left - dx;
    });
    window.addEventListener("pointerup", function () {
      drag = null;
      scroller.style.cursor = "grab";
    });
    // なぞったあとの click は人形を押したことにしない
    scroller.addEventListener("click", function (e) { if (moved) { e.stopPropagation(); moved = false; } }, true);
    scroller.addEventListener("wheel", function (e) {
      if (Math.abs(e.deltaY) > Math.abs(e.deltaX)) { scroller.scrollLeft += e.deltaY; e.preventDefault(); }
    }, { passive: false });

    // 開いた直後は今日が右端
    scroller.scrollLeft = W;
    requestAnimationFrame(function () { scroller.scrollLeft = W; });
  }

  return { sample: sample, withTotals: withTotals, render: render, clock: clock, label: label, figureHeight: figureHeight };
})();
