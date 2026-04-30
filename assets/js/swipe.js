const Swipe = {
  mounted() {
    let startX = null;
    const threshold = 50;

    this.el.addEventListener("touchstart", e => {
      startX = e.touches[0].clientX;
    }, { passive: true });

    this.el.addEventListener("touchend", e => {
      if (startX === null) return;
      const dx = e.changedTouches[0].clientX - startX;
      if (Math.abs(dx) >= threshold) {
        this.pushEvent(dx < 0 ? "next_day" : "prev_day", {});
      }
      startX = null;
    }, { passive: true });
  }
};

export default Swipe;
