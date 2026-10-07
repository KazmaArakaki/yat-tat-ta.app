// チュートリアルの見本。ホームのモックに案内を重ね、7つの場面を順に動かす
// 人形の描き方は ui/pages/home と同じ（アプリの SquatterLayer の点）
// スクワットマンの見本。横向きの棒人間を SVG で描き、立つ姿としゃがむ姿のあいだを動かす
var SQUAD = (function () {
  var P = {
    stand: { toe: [12, 0], ankle: [0, 0], knee: [0, -20], hip: [0, -40], sh: [0, -72], hand: [2, -46], head: [0, -88] },
    squat: { toe: [12, 0], ankle: [0, 0], knee: [14, -14], hip: [-6, -24], sh: [4, -55], hand: [30, -57], head: [8, -70] },
    // 仰向けに寝た姿と、上半身だけ起こした姿。長押しの0.5秒で寝た姿から起きかけへ動く
    lie: { toe: [44, -14], ankle: [40, -7], knee: [19, -7], hip: [-2, -7], sh: [-32, -7], hand: [-6, -3], head: [-46, -12] },
    rise: { toe: [44, -14], ankle: [40, -7], knee: [19, -7], hip: [-2, -7], sh: [4, -36], hand: [26, -18], head: [10, -50] }
  };
  // 手前の列から奥の列へ。列ごとの人数と大きさ
  var ROWS = [[3, 1], [5, 0.76], [7, 0.6], [9, 0.49], [11, 0.41], [13, 0.35], [15, 0.3]];
  var COLORS = { mix: ['#E9A800', '#E5337A', '#2F79F7'], dopa: ['#E5337A'], gold: ['#E9A800'] };
  var SLOTS = [];
  ROWS.forEach(function (r, ri) {
    var order = [0];
    for (var k = 1; k <= (r[0] - 1) / 2; k++) order.push(-k, k);
    order.forEach(function (c) { SLOTS.push({ row: ri, col: c, scale: r[1] }); });
  });
  var NS = 'http://www.w3.org/2000/svg';
  function mk(tag, attrs) { var e = document.createElementNS(NS, tag); for (var k in attrs) e.setAttribute(k, attrs[k]); return e; }
  function lerp(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]; }
  function pts(list) { return list.map(function (p) { return p[0].toFixed(1) + ',' + p[1].toFixed(1); }).join(' '); }
  function pose(a, b, t) { var o = {}; for (var k in P[a]) o[k] = lerp(P[a][k], P[b][k], t); return o; }

  function build(el, opts) {
    var W = el.clientWidth || 260, H = el.clientHeight || 300, unit = opts.unit || H / 235;
    var svg = mk('svg', { viewBox: '0 0 ' + W + ' ' + H, width: W, height: H, 'aria-hidden': 'true' });
    svg.style.cssText = 'position:absolute;inset:0;overflow:visible';
    el.appendChild(svg);
    var figs = [], t = opts.squat ? 1 : 0, A = opts.asleep ? 'lie' : 'stand', B = opts.asleep ? 'rise' : 'squat', palette = opts.palette || 'mix', count = 0, anim = null;
    function color(i) { var c = COLORS[palette]; return c[i % c.length]; }
    function draw() {
      var p = pose(A, B, t);
      figs.forEach(function (f) {
        var body = pts([p.toe, p.ankle, p.knee, p.hip, p.sh]), arm = pts([p.sh, p.hand]);
        f.bodyO.setAttribute('points', body); f.bodyC.setAttribute('points', body);
        f.armO.setAttribute('points', arm); f.armC.setAttribute('points', arm);
        f.head.setAttribute('cx', p.head[0]); f.head.setAttribute('cy', p.head[1]);
      });
    }
    function figure(i, pop) {
      var s = SLOTS[i], scale = s.scale * unit;
      var x = W / 2 + s.col * 50 * s.scale * unit - 6 * scale, y = H * 0.96 - s.row * H * 0.1;
      var g = mk('g', { transform: 'translate(' + x.toFixed(1) + ',' + y.toFixed(1) + ') scale(' + scale.toFixed(3) + ')' });
      var inner = mk('g', {});
      if (pop) inner.setAttribute('class', 'squad-pop');
      var line = { fill: 'none', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' };
      var f = {
        g: g, row: s.row,
        bodyO: mk('polyline', Object.assign({ stroke: '#1C1916', 'stroke-width': 12 }, line)),
        armO: mk('polyline', Object.assign({ stroke: '#1C1916', 'stroke-width': 12 }, line)),
        bodyC: mk('polyline', Object.assign({ stroke: color(i), 'stroke-width': 6.5 }, line)),
        armC: mk('polyline', Object.assign({ stroke: color(i), 'stroke-width': 6.5 }, line)),
        head: mk('circle', { r: 10, fill: color(i), stroke: '#1C1916', 'stroke-width': 3.5 })
      };
      [f.armO, f.bodyO, f.armC, f.bodyC, f.head].forEach(function (e) { inner.appendChild(e); });
      g.appendChild(inner);
      return f;
    }
    function setCount(n, pop) {
      n = Math.max(1, Math.min(30, SLOTS.length, n));
      while (count < n) { figs.push(figure(count, pop)); count++; }
      while (count > n) { var f = figs.pop(); f.g.remove(); count--; }
      // 奥の列を先に描き、手前を上に重ねる
      figs.slice().sort(function (a, b) { return b.row - a.row; }).forEach(function (f) { svg.appendChild(f.g); });
      draw();
    }
    function setPalette(p) {
      palette = p;
      figs.forEach(function (f, i) { [f.bodyC, f.armC].forEach(function (e) { e.setAttribute('stroke', color(i)); }); f.head.setAttribute('fill', color(i)); });
    }
    // 寝ている間は 寝る(0)〜起きかけ(1)、起きている間は 立つ(0)〜しゃがむ(1) のあいだを動かす
    function setAsleep(asleep) { A = asleep ? 'lie' : 'stand'; B = asleep ? 'rise' : 'squat'; }
    function animateTo(target, ms, linear) {
      if (anim) cancelAnimationFrame(anim);
      var from = t, start = performance.now();
      (function step(now) {
        var k = Math.min(1, (now - start) / ms);
        t = from + (target - from) * (linear ? k : 1 - Math.pow(1 - k, 3));
        draw();
        if (k < 1) anim = requestAnimationFrame(step);
      })(start);
    }
    setCount(opts.count || 1, false);
    function wake() { setAsleep(false); t = 1; draw(); animateTo(0, 120); }
    function collapse() { setAsleep(true); t = 0.6; draw(); animateTo(0, 180); }
    return { setCount: setCount, setPalette: setPalette, animateTo: animateTo, wake: wake, collapse: collapse,
             get asleep() { return A === 'lie'; }, get count() { return count; } };
  }

  // 指が触れたらしゃがみ、指が全部離れたら立つ。寝ている間は、0.5秒の長押しで起こす
  function bindTap(area, squad, onTap, onWake) {
    var down = 0, waking = null;
    area.addEventListener('pointerdown', function (e) {
      down++;
      if (squad.asleep) {
        if (waking) return;
        squad.animateTo(1, 500, true);
        waking = setTimeout(function () { waking = null; squad.wake(); if (onWake) onWake(); }, 500);
        return;
      }
      squad.animateTo(1, 80);
      if (onTap) onTap(e);
    });
    function up() {
      down = Math.max(0, down - 1);
      if (down > 0) return;
      // 起きる前に離したら、パタンと寝直す
      if (waking) { clearTimeout(waking); waking = null; squad.animateTo(0, 180); return; }
      if (!squad.asleep) squad.animateTo(0, 120);
    }
    area.addEventListener('pointerup', up);
    area.addEventListener('pointercancel', up);
    area.addEventListener('pointerleave', function () { down = 1; up(); });
  }
  return { build: build, bindTap: bindTap };
})();

// 場面。照らす場所（target）と、吹き出しを置く場所（place）と、進み方（next）を持つ
var TUTORIAL_STEPS = [
  { id: 'wake', target: 'stage', place: 'bottom', sec: 5, next: false,
    title: 'スクワットマンを起こす',
    body: 'スクワットマンは寝ています。ポケットの中で数えないように。画面を長押しして起こしてください。' },
  { id: 'mash', target: 'stage', place: 'bottom', sec: 12, next: false,
    title: 'スクワット1回で、1回叩く',
    body: '本番は、しゃがんだ回数だけ叩きます。いまは練習。しゃがまずに10回どうぞ。' },
  { id: 'after', target: 'stage', place: 'bottom', sec: 8, next: true,
    title: 'いまのは練習',
    body: '練習は記録に残りません。本番は、食べてしゃがんだあとに。途中でやめても、叩いた分は残ります。' },
  { id: 'streak', target: 'bar', place: 'below', sec: 9, next: true,
    title: '続けた日',
    body: '叩いた日は、ここが1日伸びます。休んだ日は、休み券がつなぎます。押すと、今日の記録。' },
  { id: 'totals', target: 'cards', place: 'above', sec: 9, next: true,
    title: 'ためたドパ',
    body: 'スクワット1回が1ドパ。DPW は7日間、DT はこれまでの全部。押すと、履歴。' },
  { id: 'gear', target: 'gear', place: 'below', sec: 6, next: true,
    title: '回数を変える',
    body: '1回に叩く数は、いま20回。ここで5〜100回に変えられます。' },
  { id: 'finish', target: null, place: 'center', sec: 5, next: true,
    title: '食べたら、しゃがんで、叩く。',
    body: '最初の1回で、1日目。' }
];

var TUTORIAL = (function () {
  var PRACTICE = 10;
  // 案内の見た目。この見本を埋め込むページでも同じに出るよう、ここで足す
  var css = document.createElement('style');
  css.textContent =
    '.app{--a-bg:#FBF6EE;--a-card:#FFFFFF;--a-ink:#1C1916;--a-mute:#6E655C;--a-rule:#E7DDCC;--a-line:#1C1916;--a-soft:#FFE6F0;}' +
    '.app.dark{--a-bg:#16120F;--a-card:#231D18;--a-ink:#F5EEE3;--a-mute:#A89C8E;--a-rule:#3A312A;--a-line:#F5EEE3;--a-soft:#3A1726;}' +
    '.a-bg{background:var(--a-bg);color:var(--a-ink)}.a-card{background:var(--a-card)}.a-ink{color:var(--a-ink)}.a-mute{color:var(--a-mute)}.a-line{border-color:var(--a-line)}.a-soft{background:var(--a-soft)}.a-shadow{box-shadow:4px 4px 0 var(--a-line)}' +
    '.num{font-family:"M PLUS Rounded 1c","Noto Sans JP",sans-serif;font-weight:900;font-variant-numeric:tabular-nums;letter-spacing:-0.02em}' +
    '.ticket{width:14px;height:18px;border-radius:3px;background:#2F79F7;position:relative}.ticket.empty{background:transparent;border:2px dashed var(--a-rule)}' +
    '.ring{position:absolute;border-radius:9999px;border:3px solid #E5337A;pointer-events:none}' +
    '@keyframes pop{0%{transform:scale(.3);opacity:0}60%{transform:scale(1.08);opacity:1}100%{transform:scale(1)}}.pop{animation:pop .45s cubic-bezier(.2,1.4,.4,1) both}' +
    '@keyframes ringout{0%{transform:translate(-50%,-50%) scale(.2);opacity:1}100%{transform:translate(-50%,-50%) scale(1);opacity:0}}' +
    '@keyframes rise{0%{opacity:0;transform:translateY(8px)}100%{opacity:1;transform:none}}' +
    '.squad-pop{transform-box:fill-box;transform-origin:50% 100%;animation:squadpop .5s cubic-bezier(.2,1.6,.4,1) both}@keyframes squadpop{0%{transform:scale(0)}100%{transform:scale(1)}}' +
    '.stage{position:relative;touch-action:manipulation;user-select:none;-webkit-user-select:none;cursor:pointer}' +
    '.coach-hole{position:absolute;box-shadow:0 0 0 999px rgba(22,18,15,.62);transition:all .45s cubic-bezier(.4,0,.2,1);}' +
    '.coach-hole.pulse::after{content:"";position:absolute;inset:-4px;border-radius:inherit;border:3px dashed #E9A800;animation:coachpulse 1.6s ease-in-out infinite;}' +
    '@keyframes coachpulse{0%,100%{opacity:.35}50%{opacity:1}}' +
    '.coach-bubble{position:absolute;left:12px;right:12px;bottom:14px;background:#fff;color:#1C1916;border:2px solid #1C1916;border-radius:20px;padding:12px 14px;box-shadow:4px 4px 0 #1C1916;animation:rise .35s ease-out both;}' +
    '.coach-bubble.center{top:50%;bottom:auto;transform:translateY(-50%);padding:24px 20px;text-align:center;animation:none;}' +
    '.metal{background:linear-gradient(180deg,#FFF6D8 0%,#E9A800 45%,#8A5A00 55%,#FFE08A 100%);-webkit-background-clip:text;background-clip:text;color:transparent;-webkit-text-stroke:1.5px #1C1916;animation:pop .45s cubic-bezier(.2,1.4,.4,1) both;}' +
    '@media (prefers-reduced-motion: reduce){.coach-hole{transition:none}.coach-hole.pulse::after{animation:none;opacity:1}.coach-bubble{animation:none}}';
  document.head.appendChild(css);
  var BANNERS = { 3: ['CHANCE!!', '#E5337A'], 6: ['激熱!!', '#E5337A'], 8: ['PUSH!!', '#E9A800'] };

  function phoneHTML() {
    return '' +
'<div class="w-[300px] shrink-0 rounded-[2.8rem] border-[6px] border-ink bg-ink p-1.5 shadow-[10px_10px_0_#E5337A]">' +
' <div data-screen class="app a-bg relative flex h-[650px] flex-col overflow-hidden rounded-[2.2rem] px-5 pb-6 pt-11 transition-colors duration-300">' +
'  <div class="absolute left-1/2 top-2.5 z-[60] h-6 w-24 -translate-x-1/2 rounded-full bg-black"></div>' +
'  <div class="flex items-start justify-between">' +
'   <div data-bar class="rounded-xl pr-2">' +
'    <p class="a-ink flex items-baseline gap-1 text-sm font-bold">最初の1回で<span class="num text-[40px] leading-none text-dopa">1</span>日目</p>' +
'    <p class="mt-1.5 text-[11px] font-bold a-mute">まだ叩いていません</p>' +
'   </div>' +
'   <div class="flex flex-col items-end gap-2">' +
'    <span data-gear class="a-ink grid h-8 w-8 place-items-center rounded-full border-2 a-line a-card text-base leading-none">⚙︎</span>' +
'    <div class="flex items-center gap-1"><span class="text-[9px] font-bold a-mute">休み券</span><span class="ticket empty"></span><span class="ticket empty"></span></div>' +
'   </div>' +
'  </div>' +
'  <div data-mid class="relative mt-3 flex flex-1 flex-col">' +
'   <div class="text-center"><p data-cap class="text-[11px] font-bold a-mute">スクワット</p><p data-num class="num a-ink text-[56px] leading-[.95]">20</p></div>' +
'   <div data-stage class="stage flex-1" role="button" aria-label="完了連打"></div>' +
'   <p data-hint class="text-center text-lg font-black text-dopa">長押しで起こす</p>' +
'   <p data-gain class="num text-center text-2xl text-dopa" style="visibility:hidden">+0 <span class="font-sans text-sm font-black">ドパ</span></p>' +
'   <p data-banner class="pointer-events-none absolute inset-x-0 top-[38%] text-center font-display text-[44px] leading-none opacity-0 [text-shadow:3px_3px_0_#1C1916]"></p>' +
'  </div>' +
'  <div data-cards class="mt-auto grid grid-cols-2 gap-3 pt-4">' +
'   <div class="a-card a-shadow rounded-2xl border-2 a-line px-3 py-2.5"><p class="font-mono text-[9px] font-bold tracking-widest a-mute">DPW</p><p class="num text-[30px] leading-none">0</p><p class="mt-1 text-[9px] font-bold a-mute">比べるのは8日目から</p></div>' +
'   <div class="a-card a-shadow rounded-2xl border-2 a-line px-3 py-2.5"><p class="font-mono text-[9px] font-bold tracking-widest a-mute">DT</p><p class="num text-[30px] leading-none">0</p><div class="mt-1.5 h-1.5 rounded-full a-soft"></div><p class="mt-1 text-[9px] font-bold a-mute">次の節目 100</p></div>' +
'  </div>' +
'  <div data-coach class="pointer-events-none absolute inset-0 z-40">' +
'   <div data-hole class="coach-hole"></div>' +
'   <div data-bubble class="coach-bubble pointer-events-auto"></div>' +
'  </div>' +
'  <div data-finale class="absolute inset-0 z-50 hidden flex-col items-center justify-center" style="background:radial-gradient(circle at 50% 45%, #3A1726 0%, #16120F 70%)"></div>' +
' </div>' +
'</div>';
  }

  function mount(root, opts) {
    opts = opts || {};
    root.innerHTML = phoneHTML();
    var $ = function (k) { return root.querySelector('[data-' + k + ']'); };
    var screen = $('screen'), stageEl = $('stage'), coach = $('coach'), hole = $('hole'), bubble = $('bubble');
    var num = $('num'), cap = $('cap'), hint = $('hint'), gain = $('gain'), banner = $('banner'), fin = $('finale');
    var squad = SQUAD.build(stageEl, { count: 1, palette: 'mix', asleep: true });
    var step = 0, left = PRACTICE, done = 0, locked = false, timers = [];
    function later(fn, ms) { timers.push(setTimeout(fn, ms)); }

    function targetRect(name) {
      var s = screen.getBoundingClientRect();
      var el = name === 'stage' ? $('mid') : name === 'bar' ? $('bar') : name === 'cards' ? $('cards') : $('gear');
      var r = el.getBoundingClientRect(), pad = name === 'gear' ? 6 : 8;
      return { x: r.left - s.left - pad, y: r.top - s.top - pad, w: r.width + pad * 2, h: r.height + pad * 2, round: name === 'gear' };
    }

    function render() {
      var st = TUTORIAL_STEPS[step];
      if (opts.onStep) opts.onStep(step);
      // 下の文字は吹き出しが代わりに言う。練習のドパは数えないので「+N ドパ」も出さない
      hint.style.display = 'none';
      // 照らす場所。ないときは、穴を画面のまん中で点にして全体を暗くする
      if (st.target) {
        var r = targetRect(st.target);
        hole.style.cssText = 'left:' + r.x + 'px;top:' + r.y + 'px;width:' + r.w + 'px;height:' + r.h + 'px;border-radius:' + (r.round ? '9999px' : '22px');
      } else {
        hole.style.cssText = 'left:50%;top:50%;width:0;height:0;border-radius:9999px';
      }
      hole.classList.toggle('pulse', !!st.target);
      // 照らした場所だけ触れる。叩く場面は穴の中を叩かせ、ほかは吹き出しで進める
      coach.style.pointerEvents = st.next ? 'auto' : 'none';
      var dots = TUTORIAL_STEPS.slice(0, 6).map(function (_, i) {
        return '<span class="h-1.5 rounded-full ' + (i === step ? 'w-5 bg-dopa' : i < step ? 'w-1.5 bg-ink' : 'w-1.5 bg-rule') + '"></span>';
      }).join('');
      if (st.place === 'center') {
        bubble.className = 'coach-bubble pointer-events-auto center';
        bubble.innerHTML =
          '<p class="font-display text-[26px] leading-snug">食べたら、<br>しゃがんで、<br><span class="text-dopa">叩く。</span></p>' +
          '<p class="mt-3 text-sm font-bold text-mute">' + st.body + '</p>' +
          '<button data-go class="mt-6 w-full rounded-full border-2 border-ink bg-gold py-3 text-base font-black text-ink shadow-[0_4px_0_#1C1916] active:translate-y-1 active:shadow-none">はじめる</button>';
      } else {
        bubble.className = 'coach-bubble pointer-events-auto ' + st.place;
        bubble.innerHTML =
          '<div class="flex items-center justify-between"><div class="flex items-center gap-1">' + dots + '</div>' +
          '<button data-skip class="text-[11px] font-bold text-mute underline underline-offset-2">スキップ</button></div>' +
          '<p class="mt-2 text-[15px] font-black leading-snug">' + st.title + '</p>' +
          '<p class="mt-1 text-[12px] leading-relaxed text-ink/75">' + st.body + '</p>' +
          (st.next ? '<p class="mt-2 text-right text-[12px] font-black text-dopa">タップで次へ ›</p>' : '');
        if (st.place === 'below') { var r2 = targetRect(st.target); bubble.style.cssText = 'bottom:auto;top:' + (r2.y + r2.h + 12) + 'px'; }
        else if (st.place === 'above') { var r3 = targetRect(st.target); bubble.style.cssText = 'top:auto;bottom:' + (screen.clientHeight - r3.y + 12) + 'px'; }
        else bubble.style.cssText = '';
      }
      var skip = bubble.querySelector('[data-skip]');
      if (skip) skip.addEventListener('click', function (e) { e.stopPropagation(); finish(true); });
      var go = bubble.querySelector('[data-go]');
      if (go) go.addEventListener('click', function (e) { e.stopPropagation(); finish(false); });
    }

    coach.addEventListener('click', function () {
      var st = TUTORIAL_STEPS[step];
      if (st.next && st.place !== 'center') go(step + 1);
    });

    function finish(skipped) {
      coach.style.display = 'none';
      hint.textContent = '長押しで起こす'; hint.style.display = '';
      if (opts.onEnd) opts.onEnd(skipped);
    }

    function go(i) {
      step = Math.max(0, Math.min(TUTORIAL_STEPS.length - 1, i));
      render();
    }

    function resetPractice(asleep) {
      left = PRACTICE; done = 0; locked = false;
      num.textContent = asleep ? '20' : PRACTICE; cap.textContent = asleep ? 'スクワット' : '練習 残り';
      gain.style.visibility = 'hidden';
      screen.classList.remove('dark');
      squad.setCount(1, false); squad.setPalette('mix');
    }

    function showBanner(text, color) {
      banner.textContent = text; banner.style.color = color;
      banner.animate([{ opacity: 0, transform: 'scale(2.2)' }, { opacity: 1, transform: 'scale(1)', offset: .25 }, { opacity: 1, offset: .75 }, { opacity: 0, transform: 'scale(1.1)' }], { duration: 900, easing: 'ease-out' });
    }

    function finale() {
      fin.classList.remove('hidden'); fin.classList.add('flex');
      fin.innerHTML = '<div class="text-center"><p class="metal font-display text-[52px] leading-[1.05]">筋肉<br>確定</p>' +
        '<p class="mt-4 text-sm font-black text-[#F5EEE3]">やったった！　練習 <span class="num">10</span> 回</p></div>';
      later(function () {
        fin.innerHTML = '<p class="metal text-center font-display text-[40px] leading-tight">あんたは<br>えらい！</p>';
      }, 1200);
      later(function () {
        fin.classList.add('hidden'); fin.classList.remove('flex');
        resetPractice(true);
        hint.textContent = '長押しで起こす'; hint.style.display = '';
        go(2);
      }, 2800);
    }

    SQUAD.bindTap(stageEl, squad, function (e) {
      if (TUTORIAL_STEPS[step].id !== 'mash' || locked) return;
      hint.style.display = 'none';
      left -= 1; done += 1;
      num.textContent = left; cap.textContent = '練習 残り';
      var r = stageEl.getBoundingClientRect();
      var ring = document.createElement('span');
      ring.className = 'ring';
      var size = 60 + done / PRACTICE * 80;
      ring.style.cssText = 'left:' + (e.clientX - r.left) + 'px;top:' + (e.clientY - r.top) + 'px;width:' + size + 'px;height:' + size + 'px;animation:ringout .32s ease-out forwards';
      stageEl.appendChild(ring); setTimeout(function () { ring.remove(); }, 340);
      if (done % 2 === 0 && left > 0) squad.setCount(1 + done / 2, true);
      if (BANNERS[done]) {
        showBanner(BANNERS[done][0], BANNERS[done][1]);
        if (done === 6) { screen.classList.add('dark'); squad.setPalette('dopa'); }
        if (done === 8) squad.setPalette('gold');
      }
      if (left === 0) {
        locked = true;
        squad.collapse();
        later(finale, 250);
      }
    }, function () {
      // 起こしたら、練習の10回へ
      if (TUTORIAL_STEPS[step].id === 'wake') {
        resetPractice(false);
        hint.textContent = '叩いてしゃがむ';
        go(1);
      }
    });

    // タブから場面を選んだとき。練習の途中は頭からにする
    function jump(i) {
      timers.forEach(clearTimeout); timers = [];
      fin.classList.add('hidden'); fin.classList.remove('flex');
      coach.style.display = '';
      var id = TUTORIAL_STEPS[i].id;
      if (id === 'mash') { if (squad.asleep) squad.wake(); resetPractice(false); hint.textContent = '叩いてしゃがむ'; hint.style.display = ''; }
      else {
        resetPractice(true);
        if (!squad.asleep) squad.collapse();
        hint.textContent = '長押しで起こす'; hint.style.display = '';
      }
      go(i);
    }

    // 枠の大きさが決まってから照らす場所を測る
    requestAnimationFrame(function () { go(opts.start || 0); });
    return { jump: jump };
  }

  return { mount: mount, STEPS: TUTORIAL_STEPS };
})();
