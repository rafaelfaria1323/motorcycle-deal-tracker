{{flutter_js}}
{{flutter_build_config}}

// WebAssembly (dart2wasm + skwasm) on every engine that can run it, not only
// Chromium: Flutter 3.50 runs it on Safari 26.2+ and Firefox 147+ but leaves
// them on JavaScript unless asked (N.90). A browser without the WebAssembly
// features still gets the JavaScript build. index.html's preloads make the
// same choice: keep them in step.
_flutter.loader.load({
  config: {
    wasmAllowList: { blink: true, webkit: true, gecko: true },
  },
});
