{{flutter_js}}
{{flutter_build_config}}

// WebAssembly (dart2wasm + skwasm) on Chromium and Firefox 147+, which
// Flutter 3.50 leaves on JavaScript unless asked (N.90). Not on Safari
// (webkit): there the app never got past the loading spinner (N.91), so
// Safari keeps the JavaScript build. A browser without the WebAssembly
// features still gets the JavaScript build. index.html's preloads make the
// same choice: keep them in step.
_flutter.loader.load({
  config: {
    wasmAllowList: { blink: true, webkit: false, gecko: true },
  },
});
