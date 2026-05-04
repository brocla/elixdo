const editableTags = new Set(["INPUT", "TEXTAREA", "SELECT"]);

const Swipe = {
  mounted() {
    let startX = null;
    let startY = null;
    let startedInToolbar = false;
    const threshold = 60;         // minimum horizontal distance to count as a swipe
    const angleThreshold = 0.5;   // swipe is ignored if |dy/dx| > this (more vertical than horizontal)
    const toolbar = document.getElementById("toolbar");

    this.el.addEventListener("touchstart", e => {
      startX = e.touches[0].clientX;
      startY = e.touches[0].clientY;
      startedInToolbar = toolbar && toolbar.contains(e.touches[0].target);
    }, { passive: true });

    this.el.addEventListener("touchend", e => {
      if (startX === null || startedInToolbar) { startX = null; startY = null; return; }
      const dx = e.changedTouches[0].clientX - startX;
      const dy = e.changedTouches[0].clientY - startY;
      // Reject if gesture is more vertical than horizontal
      if (Math.abs(dx) >= threshold && Math.abs(dy) / Math.abs(dx) <= angleThreshold) {
        this.pushEvent(dx < 0 ? "next_day" : "prev_day", {});
      }
      startX = null;
      startY = null;
    }, { passive: true });

    this._keyHandler = (e) => {
      if (editableTags.has(document.activeElement.tagName)) return;
      if (e.key === "ArrowLeft")  this.pushEvent("key_nav", { key: "ArrowLeft" });
      if (e.key === "ArrowRight") this.pushEvent("key_nav", { key: "ArrowRight" });
    };
    window.addEventListener("keydown", this._keyHandler);
  },

  destroyed() {
    window.removeEventListener("keydown", this._keyHandler);
  }
};

export default Swipe;
