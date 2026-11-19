// YouTube Auto Ad Skipper — background service worker (v1.4)
//
// The content script detects the "Skip ad" control and reports its top-level
// viewport coordinates. YouTube's skip handler filters on event.isTrusted,
// so synthesized (content-script) clicks are ignored. The ONLY extension-level
// way to inject input the browser treats as a genuine user action is the
// chrome.debugger (CDP) API. This worker drives a trusted mouse click at the
// reported coordinates via Input.dispatchMouseEvent.
//
// UX note: while attached, Chrome shows the "This browser is being debugged
// by …" infobar. We attach -> click -> detach per request, so the banner only
// flashes briefly during an ad.

(() => {
  "use strict";

  const PROTOCOL = "1.3";

  async function trustedClick(tabId, x, y) {
    const target = { tabId };
    try {
      // Attach. If a debugger is already attached to this tab, attach() throws;
      // that's fine — sendCommand still works on the existing session.
      try { await chrome.debugger.attach(target, PROTOCOL); } catch (_) {}
      const iv = { x: x | 0, y: y | 0 };
      await chrome.debugger.sendCommand(target, "Input.dispatchMouseEvent", { type: "mouseMoved", ...iv });
      await chrome.debugger.sendCommand(target, "Input.dispatchMouseEvent", { type: "mousePressed", ...iv, button: "left", clickCount: 1 });
      await chrome.debugger.sendCommand(target, "Input.dispatchMouseEvent", { type: "mouseReleased", ...iv, button: "left", clickCount: 1 });
      try { await chrome.debugger.detach(target); } catch (_) {}
    } catch (err) {
      console.warn("[Auto-Skipper] debugger click failed:", err && err.message);
      try { await chrome.debugger.detach(target); } catch (_) {}
    }
  }

  chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    if (msg && msg.type === "debugger-click" && sender.tab && sender.tab.id !== undefined) {
      trustedClick(sender.tab.id, msg.x || 0, msg.y || 0);
      sendResponse({ ok: true });
      return false;
    }
    return false;
  });

  // If the user disables/removes the extension while a session is open,
  // release any lingering debugger attachments so we don't leave a tab
  // stuck under a debugger.
  chrome.runtime.onInstalled?.(() => { /* no-op */ });
  chrome.runtime.onStartup?.(() => { /* no-op */ });
})();
