// YouTube Auto Ad Skipper v1.4
//
// YouTube's skip handler filters on event.isTrusted, so synthesized
// (content-script) clicks are ignored even when aimed at the right element.
// v1.4 keeps the v1.3 local synthesized click (works when there's no gate /
// when the debugger path is unavailable) AND adds the path that gets past
// the gate: it reports the control's TOP-LEVEL viewport coordinates to the
// background service worker, which drives a TRUSTED click via
// chrome.debugger (CDP Input.dispatchMouseEvent). The browser delivers that
// as a genuine user action, so the handler accepts it.
//
// Tradeoff: requires the "debugger" permission; Chrome briefly shows the
// "This browser is being debugged" infobar while a click is driven.
//
// Carried from v1.3: broad ytp-* selector list, text-based "Skip ad" fallback,
// closest() ancestor resolution for full renames, getBoundingClientRect
// visibility, 60ms mutation debounce, 1s action throttle, same-origin iframe
// scan, status pill + [Auto-Skipper] console markers.

(() => {
  "use strict";

  const LOG = "[Auto-Skipper]";

  // Class-based matches, most specific first (current + legacy variants).
  const SELECTORS = [
    "button.ytp-skip-ad-button",
    ".ytp-ad-skip-button-inner",
    ".ytp-ad-skip-button-modern",
    ".ytp-ad-skip-button",
    ".ytp-skip-ad-button",
    ".ytp-skip-ad-button-modern",
    "button.ytp-ad-skip-button-text",
    ".ytp-ad-skip-button-text"
  ];

  const TEXT_RE = /^\s*(skip\s*ads?)\s*$/i;               // class-agnostic safety net
  const TEXT_SCAN_SELECTORS = "button, [role='button']";   // the control itself
  const AD_CONTAINER_SELECTOR = ".ytp-ad-showing, .html5-ads-container";

  let pill = null;
  let lastState = "idle";
  let lastClickTs = 0;

  const log = (m, extra) => {
    try { console.log(LOG, m, extra !== undefined ? extra : ""); } catch (_) {}
  };

  // Robust visibility: non-zero box + not hidden.
  // NOT `offsetParent !== null` (null for position:fixed/detached elements
  // even when on-screen — the classic silent break).
  function isVisible(el) {
    if (!el || !el.ownerDocument) return false;
    try {
      const r = el.getBoundingClientRect();
      if (r.width <= 0 || r.height <= 0) return false;
      const st = el.ownerDocument.defaultView.getComputedStyle(el);
      return st.visibility !== "hidden" && st.display !== "none";
    } catch (_) { return false; } // cross-origin or detached
  }

  // Locate the skip CONTROL. Always returns the activatable control (a button),
  // never an inner label.
  function findTarget(doc) {
    if (!doc || !doc.body) return null;

    // 1) class matches -> the matched element IS the control.
    for (const sel of SELECTORS) {
      let nodes;
      try { nodes = doc.querySelectorAll(sel); } catch (_) { continue; }
      for (const el of nodes) {
        if (isVisible(el)) return { el: el, how: "class:" + sel };
      }
    }

    // 2) text fallback on generic button-ish controls.
    try {
      for (const el of doc.querySelectorAll(TEXT_SCAN_SELECTORS)) {
        if (isVisible(el) && TEXT_RE.test((el.textContent || "").trim())) {
          return { el: el, how: "text:button" };
        }
      }
    } catch (_) {}

    // 3) ad-scoped leaf walk — full-rename survival: find the "Skip ad" label,
    //    resolve UP to the nearest button-like ancestor (the control).
    try {
      for (const root of doc.querySelectorAll(AD_CONTAINER_SELECTOR)) {
        const walker = doc.createTreeWalker(root, NodeFilter.SHOW_ELEMENT);
        while (walker.nextNode()) {
          const n = walker.currentNode;
          if (n.children.length === 0 && isVisible(n) && TEXT_RE.test((n.textContent || "").trim())) {
            let btn = n;
            try { btn = n.closest("button, [role='button']") || n; } catch (_) { btn = n; }
            return { el: btn, how: "adleaf->" + (btn.className || btn.tagName || "?").toString().slice(0, 30) };
          }
        }
      }
    } catch (_) {}

    return null;
  }

  // Center of the element in the TOP-LEVEL page viewport (what CDP
  // Input.dispatchMouseEvent expects). For an in-iframe control, walk up the
  // same-origin parent frames and add each iframe's offset within its parent.
  function topLevelCenter(el) {
    const view = el.ownerDocument.defaultView;
    let r;
    try { r = el.getBoundingClientRect(); } catch (_) { return { x: 0, y: 0 }; }
    let x = r.left + r.width / 2;
    let y = r.top + r.height / 2;
    let w = view;
    let guard = 0;
    while (w && w !== w.parent && guard++ < 10) {
      let frameEl = null;
      try { frameEl = w.frameElement; } catch (_) { frameEl = null; } // cross-origin -> stop
      if (frameEl) {
        const fr = frameEl.getBoundingClientRect();
        x += fr.left;
        y += fr.top;
      }
      w = w.parent;
    }
    return { x: Math.round(x), y: Math.round(y) };
  }

  // Local synthesized click (works when there's no isTrusted gate, or when the
  // debugger path is unavailable). Kept as a graceful fallback.
  function synthesizedClick(el) {
    const view = el.ownerDocument.defaultView;
    const c = topLevelCenter(el);
    const base = {
      bubbles: true, cancelable: true, composed: true,
      view: view || undefined,
      clientX: c.x, clientY: c.y, screenX: c.x, screenY: c.y, pointerId: 1
    };
    try {
      const mouse = (type) => el.dispatchEvent(new view.MouseEvent(type, base));
      mouse("pointerdown"); mouse("mousedown");
      mouse("pointerup"); mouse("mouseup");
      mouse("click");
    } catch (_) { try { el.click(); } catch (__) {} }
    // Keyboard Enter fallback for keyboard-activation handlers.
    try {
      el.focus({ preventScroll: true });
      const ko = {
        bubbles: true, cancelable: true, composed: true,
        key: "Enter", code: "Enter", keyCode: 13, which: 13
      };
      el.dispatchEvent(new view.KeyboardEvent("keydown", ko));
      el.dispatchEvent(new view.KeyboardEvent("keyup", ko));
    } catch (_) {}
  }

  // Request a TRUSTED click from the background (CDP) — the path that gets
  // past YouTube's event.isTrusted gate. Returns true if the request was sent.
  function requestTrustedClick(el) {
    const c = topLevelCenter(el);
    try {
      chrome.runtime.sendMessage({ type: "debugger-click", x: c.x, y: c.y }, () => {
        if (chrome.runtime.lastError) {
          log("debugger-click unavailable:", chrome.runtime.lastError.message);
        }
      });
      return true;
    } catch (_) {
      log("debugger-click send failed");
      return false;
    }
  }

  function activate(el) {
    const requested = requestTrustedClick(el);
    synthesizedClick(el);
    return requested;
  }

  function setState(state, detail) {
    if (state === lastState && !detail) return;
    lastState = state;
    if (!pill) return;
    pill.textContent =
      state === "clicked" ? `Auto-Skipper: skipped${detail ? ` (${detail})` : ""}` :
      state === "watching" ? "Auto-Skipper: ad in progress" :
      "Auto-Skipper: watching";
  }

  function ensurePill() {
    if (pill || !document.body) return;
    pill = document.createElement("div");
    pill.id = "yts-auto-skipper-pill";
    pill.textContent = "Auto-Skipper: watching";
    Object.assign(pill.style, {
      position: "fixed", bottom: "12px", right: "12px", zIndex: "2147483647",
      padding: "4px 10px", borderRadius: "999px", background: "rgba(15,15,15,0.85)",
      color: "#fff", font: "12px/1.4 -apple-system, Roboto, Arial, sans-serif",
      opacity: "0.9", pointerEvents: "none", userSelect: "none"
    });
    document.body.appendChild(pill);
  }

  function tryIn(doc) {
    const hit = findTarget(doc);
    if (!hit) return false;
    const now = Date.now();
    if (now - lastClickTs >= 1000) { // throttle the action, not the scan
      const trusted = activate(hit.el);
      lastClickTs = now;
      const c = topLevelCenter(hit.el);
      const text = ((hit.el.textContent || "").trim() || hit.el.tagName || "?").slice(0, 20);
      setState("clicked", text);
      log("activated", {
        how: hit.how,
        target: (hit.el.className || hit.el.tagName || "").toString().slice(0, 50),
        text,
        at: `${c.x},${c.y}`,
        trusted: trusted ? "cdp-requested" : "synthetic-only"
      });
    } else {
      setState("watching");
    }
    return true;
  }

  function scanIframes(win, depth = 0) { // same-origin frames only; cross-origin access throws -> skip
    if (depth > 3 || !win || !win.document) return;
    let frames;
    try { frames = win.document.querySelectorAll("iframe"); } catch (_) { return; }
    for (const f of frames) {
      let childDoc;
      try { childDoc = f.contentWindow && f.contentWindow.document; } catch (_) { continue; }
      if (!childDoc || !childDoc.body) continue;
      tryIn(childDoc);
      scanIframes(f.contentWindow, depth + 1);
    }
  }

  function trySkipAd() {
    ensurePill();
    if (!tryIn(document)) {
      scanIframes(window);
      setState("watching");
    }
  }

  // Debounced mutation handling: coalesce bursts, one scan per ~60ms.
  const observer = new MutationObserver(() => {
    if (!observer._pending) {
      observer._pending = true;
      setTimeout(() => { observer._pending = false; trySkipAd(); }, 60);
    }
  });

  function init() {
    if (!document.body) { document.addEventListener("DOMContentLoaded", init, { once: true }); return; }
    ensurePill();
    observer.observe(document.body, { childList: true, subtree: true, attributes: true });
    setInterval(trySkipAd, 1000);
    log("Initialized on", location.href);
  }

  document.readyState === "loading"
    ? document.addEventListener("DOMContentLoaded", init, { once: true })
    : init();
})();
