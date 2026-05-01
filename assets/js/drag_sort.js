import Sortable from "../vendor/sortable";

const DragSort = {
  mounted() {
    this.sortable = Sortable.create(this.el, {
      animation: 150,
      handle: ".drag-handle",
      ghostClass: "drag-ghost",
      forceFallback: false,
      onEnd: (evt) => {
        const ids = Array.from(this.el.querySelectorAll("li[data-id]"))
          .map(li => parseInt(li.dataset.id, 10));
        this.pushEvent("reorder", { order: ids });
      }
    });
  },
  destroyed() {
    if (this.sortable) this.sortable.destroy();
  }
};

export default DragSort;
