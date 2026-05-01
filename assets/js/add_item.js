// On touch devices (phones/tablets), let Enter insert a newline naturally
// and rely on the Add button to submit. On desktop, Enter submits.
const isTouchDevice = () => window.matchMedia("(pointer: coarse)").matches;

const AddItem = {
  mounted() {
    // Server sends this after successfully adding an item
    this.handleEvent("clear_add_input", () => {
      this.el.value = "";
      this.el.focus();
    });

    this.el.addEventListener("keydown", e => {
      if (e.key === "Enter" && !e.shiftKey && !isTouchDevice()) {
        e.preventDefault();
        this.el.closest("form").dispatchEvent(new Event("submit", {bubbles: true}));
      }
    });
  }
};

export default AddItem;
