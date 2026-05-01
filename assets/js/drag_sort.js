import Sortable from "../vendor/sortable";

const DragSort = {
  mounted() {
    this._init();
  },
  updated() {
    // LiveView may patch the list DOM after a reorder or item change.
    // Destroy and recreate so SortableJS stays bound to the current nodes.
    if (this.sortable) this.sortable.destroy();
    this._init();
  },
  destroyed() {
    if (this.sortable) this.sortable.destroy();
  },
  _init() {
    this.sortable = Sortable.create(this.el, {
      animation: 150,
      handle: ".drag-handle",
      ghostClass: "drag-ghost",
      forceFallback: false,
      onEnd: () => {
        const ids = Array.from(this.el.querySelectorAll("li[data-id]"))
          .map(li => parseInt(li.dataset.id, 10));
        this.pushEvent("reorder", { order: ids });
      }
    });
  }
};

export default DragSort;
