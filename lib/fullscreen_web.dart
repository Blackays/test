import 'dart:js_interop';

@JS('document.documentElement.requestFullscreen')
external JSAny? _requestFullscreen();

// Browsers hide tabs/URL bars only when the page enters real Fullscreen,
// and only from inside a user-gesture handler (e.g. a tap).
void enterFullscreen() {
  try {
    _requestFullscreen();
  } catch (_) {/* already fullscreen, or denied — ignore */}
}
