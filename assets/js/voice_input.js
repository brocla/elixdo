const VoiceInput = {
  mounted() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) return; // leave hidden on unsupported browsers

    this.el.style.display = "";

    const recognition = new SpeechRecognition();
    recognition.lang = "en-US";
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;

    let recording = false;

    recognition.onresult = (e) => {
      const transcript = e.results[0][0].transcript;
      this.pushEvent("voice_input", {text: transcript});
    };

    recognition.onend = () => {
      recording = false;
      this.el.classList.remove("mic-recording");
    };

    recognition.onerror = () => {
      recording = false;
      this.el.classList.remove("mic-recording");
    };

    this.el.addEventListener("click", () => {
      if (recording) {
        recognition.stop();
      } else {
        recognition.start();
        recording = true;
        this.el.classList.add("mic-recording");
      }
    });
  }
};

export default VoiceInput;
