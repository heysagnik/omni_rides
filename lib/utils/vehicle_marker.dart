import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_colors.dart';

/// Returns a custom BitmapDescriptor showing a vehicle icon inside a
/// coloured circle. Falls back to a default blue marker on any error.
Future<BitmapDescriptor> buildVehicleMarker(String rideType) async {
  try {
    const size = 96.0;
    const iconSize = 48.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 4), size / 2 - 6, shadowPaint);

    // Circle background
    final bgPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 6, bgPaint);

    // White border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 6, borderPaint);

    // Icon
    final icon = rideType == 'parcel'
        ? Icons.inventory_2_rounded
        : Icons.directions_car_rounded;

    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: 'MaterialIcons',
      fontSize: iconSize,
    ))
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: iconSize,
        fontFamily: 'MaterialIcons',
      ))
      ..addText(String.fromCharCode(icon.codePoint));

    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: size));

    canvas.drawParagraph(
      paragraph,
      Offset((size - iconSize) / 2, (size - iconSize) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) return _fallback();

    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      width: 44,
      height: 44,
    );
  } catch (e) {
    debugPrint('Vehicle marker error: $e');
    return _fallback();
  }
}

BitmapDescriptor _fallback() =>
    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
