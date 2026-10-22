import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// [agent] The stock connection manager resizes its window to 300x490 when a client connects, and that can
// land after our own resize (a password connection is authorised at once), leaving a tall empty window.
// Our pages call this on every tick, so the size we want wins whichever came last.
Future<void> ypHoldWindowSize(Size size, Alignment alignment) async {
  final now = await windowManager.getSize();
  if ((now.width - size.width).abs() > 2 || (now.height - size.height).abs() > 2) {
    await windowManager.setSizeAlignment(size, alignment);
  }
}
