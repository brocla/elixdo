const AddItem = {
  mounted() {
    this.el.addEventListener("keydown", e => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        this.el.closest("form").dispatchEvent(new Event("submit", {bubbles: true}));
      }
    });
  },
  updated() {
    // Auto-focus after submit (LiveView re-renders the element)
  }
};

export default AddItem;
