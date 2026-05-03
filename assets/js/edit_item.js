// On touch devices, let Enter insert a newline naturally.
// On desktop, Enter submits the edit form (matching add-item behavior).
const isTouchDevice = () => window.matchMedia("(pointer: coarse)").matches;

const EditItem = {
  mounted() {
    this.el.addEventListener("keydown", e => {
      if (e.key === "Enter" && !e.shiftKey && !isTouchDevice()) {
        e.preventDefault();
        this.el.closest("form").dispatchEvent(new Event("submit", {bubbles: true}));
      }
    });
  }
};

export default EditItem;
