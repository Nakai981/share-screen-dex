import 'dart:convert';

/// Fullscreen stays inside the browser's WebView. A system video presentation
/// would leave the desktop coordinate space used by the phone's pointer.
const browserDesktopFullscreenScript = r'''
(() => {
  if (window.__sideScreenFullscreenInstalled || !document.documentElement) return;
  window.__sideScreenFullscreenInstalled = true;
  let target = null, saved = [], exitButton = null;
  const notify = () => {
    document.dispatchEvent(new Event('fullscreenchange'));
    document.dispatchEvent(new Event('webkitfullscreenchange'));
  };
  const exit = () => {
    if (!target) return Promise.resolve();
    exitButton?.remove();
    saved.forEach(([el, style]) => {
      el.style.cssText = style || '';
      if (style === null) el.removeAttribute('style');
    });
    target = null; saved = []; exitButton = null;
    notify();
    return Promise.resolve();
  };
  const enter = el => {
    if (!(el instanceof Element)) return Promise.resolve();
    if (target) exit();
    target = el;
    const background = getComputedStyle(el).backgroundColor;
    for (let p = el; p; p = p.parentElement) {
      saved.push([p, p.getAttribute('style')]);
      ['transform','filter','perspective','clip-path','contain'].forEach(k => p.style.setProperty(k, 'none', 'important'));
      p.style.setProperty('overflow', 'visible', 'important');
      p.style.setProperty('z-index', '2147483646', 'important');
    }
    for (const [k,v] of Object.entries({position:'fixed',inset:'0',width:'100vw',height:'100vh','max-width':'none','max-height':'none',margin:'0','box-sizing':'border-box',background:background === 'rgba(0, 0, 0, 0)' ? '#000' : background})) el.style.setProperty(k,v,'important');
    if (el.matches('video')) el.style.setProperty('object-fit','contain','important');
    document.documentElement.style.setProperty('overflow','hidden','important');
    exitButton = document.createElement('button');
    exitButton.textContent = '✕';
    exitButton.setAttribute('aria-label','Thoát phóng lớn');
    exitButton.id = 'sidescreen-exit-fullscreen';
    exitButton.style.cssText = 'position:fixed!important;top:10px!important;right:10px!important;width:40px!important;height:40px!important;z-index:2147483647!important;border:1px solid #ffffff55!important;border-radius:20px!important;background:#18313fdd!important;color:white!important;font:20px system-ui!important;cursor:pointer!important;display:grid!important;place-items:center!important;';
    exitButton.addEventListener('click', e => { e.stopPropagation(); exit(); });
    document.body.appendChild(exitButton);
    notify();
    return Promise.resolve();
  };
  const define = (obj, name, descriptor) => { try { Object.defineProperty(obj,name,{configurable:true,...descriptor}); } catch (_) {} };
  ['requestFullscreen','webkitRequestFullscreen','webkitRequestFullScreen'].forEach(name => define(Element.prototype,name,{value:function(){return enter(this);}}));
  ['exitFullscreen','webkitExitFullscreen','webkitCancelFullScreen'].forEach(name => define(document,name,{value:exit}));
  ['fullscreenElement','webkitFullscreenElement'].forEach(name => define(document,name,{get:()=>target}));
  ['fullscreenEnabled','webkitFullscreenEnabled'].forEach(name => define(document,name,{get:()=>true}));
  define(document,'webkitIsFullScreen',{get:()=>!!target});
  if (window.HTMLVideoElement) {
    ['webkitEnterFullscreen','webkitEnterFullScreen'].forEach(name => define(HTMLVideoElement.prototype,name,{value:function(){return enter(this);}}));
    const presentation = HTMLVideoElement.prototype.webkitSetPresentationMode;
    if (presentation) define(HTMLVideoElement.prototype,'webkitSetPresentationMode',{value:function(mode){
      if (mode === 'fullscreen') return enter(this);
      if (mode === 'inline' && target) return exit();
      return presentation.call(this,mode);
    }});
  }
  document.addEventListener('click', e => {
    const button = e.target?.closest?.('.ytp-fullscreen-button');
    if (!button) return;
    const player = button.closest('.html5-video-player');
    if (!player) return;
    e.preventDefault(); e.stopImmediatePropagation();
    if (target) exit(); else enter(player);
  }, true);
  document.addEventListener('keydown', e => { if (e.key === 'Escape' && target) { e.preventDefault(); exit(); } }, true);
  document.addEventListener('webkitbeginfullscreen', e => {
    const video = e.target;
    try { video.webkitExitFullscreen?.(); } catch (_) {}
    enter(video);
  }, true);
  window.__sideScreenExitFullscreen = exit;
})();
''';

String browserPointerScript(double? x, double? y) =>
    '''
(() => {
  const p = ${jsonEncode({'x': x, 'y': y})};
  const x = p.x === null ? -1 : innerWidth * p.x;
  const y = p.y === null ? -1 : innerHeight * p.y;
  const el = document.elementFromPoint(x,y);
  const previous = window.__sideScreenHoverElement;
  const event = {bubbles:true,clientX:x,clientY:y,view:window};
  if (previous !== el) {
    previous?.dispatchEvent(new MouseEvent('mouseout',{...event,relatedTarget:el}));
    el?.dispatchEvent(new MouseEvent('mouseover',{...event,relatedTarget:previous || null}));
    window.__sideScreenHoverElement = el;
  }
  if (el) {
    if (window.PointerEvent) el.dispatchEvent(new PointerEvent('pointermove',{...event,pointerType:'mouse'}));
    el.dispatchEvent(new MouseEvent('mousemove',event));
  }
})();
''';
