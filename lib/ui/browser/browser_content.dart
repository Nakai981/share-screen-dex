import 'dart:convert';

String browserCommandScript(Map<String, Object?> command) =>
    '''
(() => {
  const c = ${jsonEncode(command)};
  if (c.type === 'exitFullscreen') { window.__sideScreenExitFullscreen?.(); return; }
  if (c.type === 'scroll') { window.scrollBy({top: c.dy || 0, behavior: 'auto'}); return; }
  if (c.type === 'text') {
    const el = document.activeElement;
    if (el && ('value' in el)) { el.value = c.text || ''; el.dispatchEvent(new Event('input', {bubbles:true})); }
    else if (el && el.isContentEditable) { el.textContent = c.text || ''; el.dispatchEvent(new Event('input', {bubbles:true})); }
    return;
  }
  const el = document.elementFromPoint(innerWidth * c.x, innerHeight * c.y);
  if (el) { if (typeof el.focus === 'function') el.focus(); el.click(); }
})();
''';

const browserDemoHtml = r'''<!doctype html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Trang thử SideScreen</title><style>
*{box-sizing:border-box}body{margin:0;background:#f4f7f8;color:#18313f;font:15px/1.7 system-ui,sans-serif}
main{max-width:780px;margin:auto;padding:44px 36px}header{display:flex;align-items:center;gap:12px;color:#358677;font-weight:650}
.mark{background:#18313f;color:#a6d4ca;width:38px;height:38px;display:grid;place-items:center;border-radius:12px}
h1{font-size:38px;line-height:1.2;letter-spacing:-1.4px;margin:28px 0 16px}p{color:#637783}
section{background:white;border:1px solid #e2e8ed;border-radius:18px;padding:24px;margin-top:24px}
h2{font-size:19px;margin:0 0 12px}button{border:0;border-radius:10px;padding:13px 20px;background:#3864de;color:white;font:600 14px system-ui;cursor:pointer}
button:hover{background:#2852c4;transform:translateY(-2px)}button:active{transform:scale(.96)}
input{display:block;width:100%;padding:14px 16px;border:1px solid #d5e0e6;border-radius:10px;font:15px system-ui;outline-color:#3864de}
.count{font-size:30px;font-weight:700;display:inline-block;margin-right:20px;min-width:35px}a{color:#3864de}
footer{padding-top:34px;color:#74838c;font-size:12px}#echo{min-height:28px;color:#358677}
</style></head><body><main>
<header><div class="mark">▥</div> SideScreen / Trang thử</header>
<h1>Một trang web thật.<br>Ngay trong không gian của bạn.</h1>
<p>Trang HTML này chạy bằng trình duyệt nhúng, có JavaScript, biểu mẫu và nội dung cuộn được.</p>
<section id="fullscreen-demo"><h2>Thử tương tác</h2><span class="count" id="count">0</span>
<button id="counter" onclick="document.getElementById('count').textContent=++window.clickCount">Tăng bộ đếm</button>
<button id="fullscreen-button" onclick="document.fullscreenElement ? document.exitFullscreen() : document.getElementById('fullscreen-demo').requestFullscreen()">Phóng lớn vùng thử</button></section>
<section><h2>Thử nhập chữ</h2><input id="message" placeholder="Viết một lời chào…" oninput="document.getElementById('echo').textContent=this.value">
<p id="echo"></p></section>
<section><h2>Thử mở một website</h2><p>Nhập địa chỉ vào thanh trên cùng để mở website của bạn.</p>
<p>Ở bản web, một số website từ chối hiển thị trong khung nhúng. Khi đó hãy dùng nút mở tab ngoài.</p></section>
<section><h2>Cuộn xuống được rồi!</h2><p>Bạn cũng có thể dùng các nút cuộn trong mục Trình duyệt trên điện thoại.</p></section>
<footer>Trang thử cục bộ · Không cần kết nối internet</footer>
</main><script>window.clickCount=0;
window.addEventListener('message', e => {
  if (e.source !== parent || !e.data || e.data.source !== 'sidescreen') return;
  const c = e.data.command;
  if (c.type === 'scroll') { window.scrollBy(0, c.dy || 0); return; }
  if (c.type === 'text') { const el=document.activeElement; if(el && 'value' in el){el.value=c.text||'';el.dispatchEvent(new Event('input',{bubbles:true}));}return; }
  const el=document.elementFromPoint(innerWidth*c.x,innerHeight*c.y);if(el){if(el.focus)el.focus();el.click();}
});</script></body></html>''';
