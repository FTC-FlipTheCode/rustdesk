import 'dart:io';
import 'dart:typed_data';

import 'package:window_manager/window_manager.dart';

// All monitors as one PNG. DPI-aware so a scaled 4K screen is captured whole; wider than
// _maxWidth is scaled down to stay under the bridge's 8 MB limit.
const _maxWidth = 2560;
const _captureScript = r'''
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();' -Name U -Namespace YpDpi
[void][YpDpi.U]::SetProcessDPIAware()
$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
if ($b.Width -gt MAXW) {
  $h = [int]($b.Height * MAXW / $b.Width)
  $small = New-Object System.Drawing.Bitmap MAXW, $h
  $g2 = [System.Drawing.Graphics]::FromImage($small)
  $g2.InterpolationMode = 'HighQualityBicubic'
  $g2.DrawImage($bmp, 0, 0, MAXW, $h)
  $bmp = $small
}
$bmp.Save('OUT', [System.Drawing.Imaging.ImageFormat]::Png)
''';

/// PNG of the screen, or null if Windows refused (locked session, no desktop).
Future<Uint8List?> captureScreen() async {
  final out = File('${Directory.systemTemp.path}\\yp-screenshot-${DateTime.now().millisecondsSinceEpoch}.png');
  final script = _captureScript.replaceAll('MAXW', '$_maxWidth').replaceAll('OUT', out.path.replaceAll("'", "''"));
  try {
    final r = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
    if (r.exitCode != 0 || !await out.exists()) return null;
    return await out.readAsBytes();
  } catch (_) {
    return null;
  } finally {
    if (await out.exists()) await out.delete();
  }
}

/// The agent window hides for the shot so the technician sees what the client sees.
Future<Uint8List?> captureScreenWithoutAgent() async {
  await windowManager.hide();
  await Future.delayed(const Duration(milliseconds: 400));
  try {
    return await captureScreen();
  } finally {
    await windowManager.show();
    await windowManager.focus();
  }
}
