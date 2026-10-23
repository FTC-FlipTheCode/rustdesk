import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// [agent] Keeps the connection-manager window the way our pages need it. When the last client leaves, the
// stock code makes the window transparent, minimises and hides it, and on the next connection brings it back
// only part of the way (it can stay minimised); it also resizes it to 300x490 when a client connects, which
// can land after our own resize. Our pages call this on every tick, so the window is on screen at the right
// size whatever the stock code did last. Focus is taken only when asked (first show) or when it was hidden.
Future<void> ypHoldWindow(Size size, Alignment alignment, {bool focus = false}) async {
  if (await windowManager.getOpacity() < 1) {
    await windowManager.setOpacity(1);
    focus = true;
  }
  await windowManager.restore();
  await windowManager.show();
  if (focus) await windowManager.focus();
  final now = await windowManager.getSize();
  if ((now.width - size.width).abs() > 2 || (now.height - size.height).abs() > 2) {
    await windowManager.setSizeAlignment(size, alignment);
  }
}
