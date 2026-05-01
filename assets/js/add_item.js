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
    // After LiveView re-renders (post-submit), clear and focus the textarea.
    this.el.value = "";
    this.el.focus();
  }
};

export default AddItem;
