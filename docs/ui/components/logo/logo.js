// ロゴのマークを SVG で描く。アプリのアイコンは ios/Design/app_icon.py が書き出す層から作る（A の点と大きさはそちらと同じ）
// B と C は 2026-10-07 のセッションで比べた没案。人形の点は ios/YatTatTa/Home/SquatStageView.swift の SquatterLayer と同じ
(function () {
  var POSE = {
    stand: { legs: [[12, 0], [0, 0], [0, -21], [0, -42], [0, -72]], arm: [[0, -72], [4, -58], [6, -46]], head: [2, -86] },
    squat: { legs: [[12, 0], [0, 0], [15, -15], [-7, -25], [3, -55]], arm: [[3, -55], [17, -55], [31, -56]], head: [7, -69] }
  };
  var C = { paper: '#FBF6EE', ink: '#1C1916', night: '#16120F', dopa: '#E5337A', gold: '#E9A800' };

  function mix(s) {
    var a = POSE.stand, b = POSE.squat;
    var m = function (p, q) { return [p[0] + (q[0] - p[0]) * s, p[1] + (q[1] - p[1]) * s]; };
    return {
      legs: a.legs.map(function (p, i) { return m(p, b.legs[i]); }),
      arm: a.arm.map(function (p, i) { return m(p, b.arm[i]); }),
      head: m(a.head, b.head)
    };
  }

  // 人形1人。x, y はかかと、k は点1つぶんの大きさ、squat は 0 が立った姿、1 がしゃがんだ姿
  function doll(x, y, k, squat, color, outline) {
    var j = mix(squat);
    var pt = function (p) { return (x + p[0] * k).toFixed(1) + ',' + (y + p[1] * k).toFixed(1); };
    var line = function (ps) { return 'M' + ps.map(pt).join('L'); };
    var d = line(j.legs) + line(j.arm);
    var hx = x + j.head[0] * k, hy = y + j.head[1] * k;
    var out = '';
    if (outline) {
      out += '<path d="' + d + '" fill="none" stroke="' + outline + '" stroke-width="' + 15 * k + '" stroke-linecap="round" stroke-linejoin="round"/>';
      out += '<circle cx="' + hx + '" cy="' + hy + '" r="' + 12 * k + '" fill="' + outline + '"/>';
    }
    out += '<path d="' + d + '" fill="none" stroke="' + color + '" stroke-width="' + 9 * k + '" stroke-linecap="round" stroke-linejoin="round"/>';
    out += '<circle cx="' + hx + '" cy="' + hy + '" r="' + 8.5 * k + '" fill="' + color + '"/>';
    return out;
  }

  // mode: light | dark | tinted
  var MARKS = {
    // A しゃがむ1人。金の地は「押せるもの」の色。アイコンそのものが、叩けば始まるボタン
    a: function (mode) {
      var k = 7.6, x = 512 - 12 * k, y = 770;
      var bg = { light: C.gold, dark: C.night, tinted: '#000' }[mode];
      var body = { light: C.dopa, dark: C.dopa, tinted: '#F2F2F2' }[mode];
      var ring = { light: C.ink, dark: C.gold, tinted: '#8A8A8A' }[mode];
      var s = '<rect width="1024" height="1024" fill="' + bg + '"/>';
      s += '<ellipse cx="' + (x + 8 * k) + '" cy="' + (y + 40) + '" rx="300" ry="70" fill="none" stroke="' + ring + '" stroke-width="26" opacity=".9"/>';
      if (mode === 'light') s += doll(x + 14, y + 22, k, 1, C.ink, C.ink);
      s += doll(x, y, k, 1, body, mode === 'light' ? C.ink : null);
      return s;
    },
    // B 3拍。立つ、半分、しゃがむ。Yat、Tat、Ta の順
    b: function (mode) {
      var k = 4.7, y = 730;
      var bg = { light: C.paper, dark: C.night, tinted: '#000' }[mode];
      var fg = { light: C.ink, dark: C.paper, tinted: '#9A9A9A' }[mode];
      var hit = { light: C.dopa, dark: C.dopa, tinted: '#F2F2F2' }[mode];
      var s = '<rect width="1024" height="1024" fill="' + bg + '"/>';
      s += '<rect x="130" y="' + (y + 46) + '" width="764" height="22" rx="11" fill="' + fg + '" opacity=".25"/>';
      s += doll(215, y, k, 0, fg, null);
      s += doll(430, y, k, .5, fg, null);
      s += doll(655, y, k, 1, hit, mode === 'light' ? C.ink : null);
      return s;
    },
    // C 名前の3語を積む。Ta だけ dopa で、着地でつぶれた形
    c: function (mode) {
      var bg = { light: C.ink, dark: C.night, tinted: '#000' }[mode];
      var fg = { light: C.paper, dark: C.paper, tinted: '#9A9A9A' }[mode];
      var hit = { light: C.dopa, dark: C.dopa, tinted: '#F2F2F2' }[mode];
      var t = function (txt, y, color, sx, sy) {
        return '<text x="512" y="' + y + '" text-anchor="middle" font-family="M PLUS Rounded 1c" font-weight="900" font-size="300" fill="' + color + '" transform="translate(512 ' + y + ') scale(' + sx + ' ' + sy + ') translate(-512 -' + y + ')">' + txt + '</text>';
      };
      var s = '<rect width="1024" height="1024" fill="' + bg + '"/>';
      s += t('Yat', 360, fg, 1, 1) + t('Tat', 620, fg, 1, 1) + t('Ta', 880, hit, 1.12, .82);
      return s;
    }
  };

  function svg(id, mode, size) {
    return '<svg viewBox="0 0 1024 1024" width="' + size + '" height="' + size + '" role="img" aria-label="ロゴ案 ' + id.toUpperCase() + '" style="display:block">' + MARKS[id](mode) + '</svg>';
  }

  // iOS のアイコンの角。正方形の 22.37% の丸み
  function icon(id, mode, size) {
    return '<div style="width:' + size + 'px;height:' + size + 'px;border-radius:' + size * 0.2237 + 'px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.18)">' + svg(id, mode, size) + '</div>';
  }

  window.Logo = { svg: svg, icon: icon, doll: doll };

  document.querySelectorAll('[data-icon]').forEach(function (el) {
    el.innerHTML = icon(el.dataset.icon, el.dataset.mode || 'light', +el.dataset.size || 120);
  });
})();
