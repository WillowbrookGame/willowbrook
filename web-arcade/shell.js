(() => {
  "use strict";
  if (window.WillowbrookArcade) return;
  const base = new URL(".", document.currentScript.src);
  const ids = new Set(["basketball","memory","road-hop","maze-chase","claw","air-hockey","brick-breaker","survivors"]);
  const allowed = {"air-hockey":new Set(["airHockeyFrame","airHockeyError"]),basketball:new Set(["hoops88","hoops88Leaderboard","error"])};
  const maxEarly = 16;
  let active = null;
  let nextTicket = 0;

  function disposeFrame(entry) {
    clearTimeout(entry.timeout);
    entry.early.length = 0;
    try { entry.frame?.contentWindow.arcadeDispose?.(); } catch {}
    entry.frame?.remove();
    entry.frame = null;
    entry.loaded = false;
  }
  function close() {
    const entry = active;
    if (!entry || entry.closing) return false;
    entry.closing = true;
    disposeFrame(entry);
    active = null;
    entry.wrapper.remove();
    window.dispatchEvent(new Event("willowbrook-arcade-changed"));
    try { entry.onClose(); } finally {
      requestAnimationFrame(() => {
        if (active) return;
        const target = entry.opener?.isConnected && (entry.opener.tabIndex >= 0 || entry.opener.tagName === "CANVAS")
          ? entry.opener : document.querySelector("canvas");
        target?.focus({preventScroll:true});
      });
    }
    return true;
  }
  function failed(entry, frame, force=false) {
    if (entry !== active || entry.frame !== frame || entry.loaded && !force) return;
    disposeFrame(entry);
    entry.notice.hidden = false;
    entry.message.textContent = "This cabinet did not load. Try again, or go back to the arcade.";
    entry.retry.hidden = false;
    if (!entry.wrapper.inert) entry.retry.focus();
  }
  function load(entry) {
    disposeFrame(entry);
    entry.message.textContent = "Loading cabinet…";
    entry.notice.hidden = false;
    entry.retry.hidden = true;
    const frame = document.createElement("iframe");
    frame.style.cssText = "border:0;width:100%;height:100%;min-height:0;display:block;visibility:hidden;grid-area:1/1";
    frame.title = entry.caption;
    frame.allow = "autoplay";
    const url = new URL("index.html",base);
    url.searchParams.set("cabinet",entry.id);
    // A retry uses a fresh frame/module graph, not an earlier failed import.
    url.searchParams.set("visit",String(++nextTicket));
    frame.src = url.href;
    entry.frame = frame;
    entry.wrapper.prepend(frame);
    frame.addEventListener("error",()=>failed(entry,frame),{once:true});
    entry.timeout = setTimeout(()=>failed(entry,frame),6000);
  }
  window.addEventListener("keydown", event => {
    if (active && !active.loaded && event.key === "Escape") {event.preventDefault();close();}
  });
  window.addEventListener("message", event => {
    if (event.origin === location.origin && active && event.source === active.frame?.contentWindow
        && event.data?.type === "willowbrook-arcade-close") close();
  });
  window.WillowbrookArcadeTransport = {
    available(owner) { return active?.frame?.contentWindow === owner && active.ready === true; },
    send(message, owner) {
      const entry = active;
      if (!entry?.ready || entry.frame?.contentWindow !== owner ||
          message?.type !== (entry.id === "air-hockey" ? "airHockey" : entry.id === "basketball" ? "hoops88" : "")) return false;
      const ticket = ++nextTicket;
      entry.sending = ticket;
      entry.sent = false;
      try {
        entry.onSend(JSON.stringify(message),ticket);
        return entry.sent;
      } catch { return false; }
      finally { entry.sending = 0; }
    }
  };
  window.WillowbrookArcade = {
    open(id,caption,onClose,onSend,ready=false) {
      if (!ids.has(id) || typeof onClose !== "function" || typeof onSend !== "function" || active) return false;
      if (document.pointerLockElement) document.exitPointerLock?.();
      const opener = document.activeElement;
      const wrapper = document.createElement("div");
      wrapper.id = "willowbrook-arcade-overlay";
      wrapper.setAttribute("role","dialog");
      wrapper.setAttribute("aria-modal","true");
      wrapper.setAttribute("aria-label",caption);
      wrapper.style.cssText = "position:fixed;inset:0;z-index:2147483600;background:#192a4a80;isolation:isolate;display:grid;overflow:hidden;touch-action:none";
      const notice = document.createElement("section");
      notice.style.cssText = "grid-area:1/1;place-self:center;z-index:1;max-width:min(360px,85vw);padding:22px;border-radius:16px;background:#fff8ed;color:#24334b;font:16px system-ui";
      const heading = document.createElement("h2");
      heading.textContent = caption;
      heading.style.marginTop = "0";
      const message = document.createElement("p");
      message.setAttribute("role","status");
      const retry = document.createElement("button");
      const back = document.createElement("button");
      for (const [button,label] of [[retry,"Retry"],[back,"Back to Arcade"]]) {
        button.type = "button";
        button.textContent = label;
        button.style.cssText = "font:inherit;min-height:44px;margin-right:8px;cursor:pointer";
      }
      const entry = {id,caption,wrapper,opener,onClose,onSend,ready:!!ready,loaded:false,early:[],notice,message,retry};
      retry.addEventListener("click",()=>{if (entry === active) load(entry);back.focus();});
      back.addEventListener("click",close);
      notice.append(heading,message,retry,back);
      wrapper.append(notice);
      active = entry;
      document.body.append(wrapper);
      window.dispatchEvent(new Event("willowbrook-arcade-changed"));
      load(entry);
      back.focus();
      return true;
    },
    ready(owner) {
      const entry = active;
      if (!entry || entry.loaded || entry.frame?.contentWindow !== owner || typeof owner.arcadeReceive !== "function") return false;
      entry.loaded = true;
      clearTimeout(entry.timeout);
      entry.notice.hidden = true;
      entry.frame.style.visibility = "visible";
      for (const packet of entry.early.splice(0)) owner.arcadeReceive(packet);
      owner.arcadeTransportChanged?.(entry.ready);
      if (!entry.wrapper.inert) owner.focus();
      return true;
    },
    fail(owner) { if (active?.frame?.contentWindow === owner) failed(active,active.frame,true); },
    reportSent(ticket,value) {
      if (active?.sending === ticket) active.sent = value === true;
    },
    close,
    isOpen() { return !!active; },
    focusActive() {
      if (!active || active.wrapper.inert) return false;
      if (active.loaded) active.frame?.contentWindow?.focus();
      else active.notice.querySelector("button:not([hidden])")?.focus();
      return true;
    },
    setTransportReady(value) {
      if (!active || active.ready === !!value) return;
      active.ready = !!value;
      if (!active.ready) active.early.length = 0;
      if (active.loaded) active.frame.contentWindow.arcadeTransportChanged?.(active.ready);
    },
    receive(packet) {
      const entry = active;
      if (!entry?.frame || !entry.ready || entry.closing || typeof packet !== "string" || packet.length > 65536) return;
      let type;
      try { type = JSON.parse(packet)?.type; } catch { return; }
      if (!allowed[entry.id]?.has(type) && !(entry.id === "basketball" && typeof type === "string" && type.startsWith("hoops88"))) return;
      if (entry.loaded) entry.frame.contentWindow.arcadeReceive(packet);
      else {
        if (entry.early.length >= maxEarly) entry.early.shift();
        entry.early.push(packet);
      }
    }
  };
})();