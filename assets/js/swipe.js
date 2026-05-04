const editableTags = new Set(["INPUT", "TEXTAREA", "SELECT"]);

const Swipe = {
  mounted() {
    let startX = null;
    let startedInToolbar = false;
    const threshold = 50;
    const toolbar = document.getElementById("toolbar");

    this.el.addEventListener("touchstart", e => {
      startX = e.touches[0].clientX;
      startedInToolbar = toolbar && toolbar.contains(e.touches[0].target);
    }, { passive: true });

    this.el.addEventListener("touchend", e => {
      if (startX === null || startedInToolbar) { startX = null; return; }
      const dx = e.changedTouches[0].clientX - startX;
      if (Math.abs(dx) >= threshold) {
        this.pushEvent(dx < 0 ? "next_day" : "prev_day", {});
      }
      startX = null;
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
