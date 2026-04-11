document.addEventListener("DOMContentLoaded", function () {
  if (!window.mermaid) {
    console.warn("Mermaid not found on window");
    return;
  }

  mermaid.initialize({
    startOnLoad: false
  });

  try {
    mermaid.run({
      querySelector: ".language-mermaid, .mermaid"
    });
  } catch (e) {
    console.error("Mermaid run() failed:", e);
  }
});
