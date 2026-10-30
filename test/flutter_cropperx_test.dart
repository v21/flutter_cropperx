import 'dart:ui' as ui;

import 'package:cropperx/cropperx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// An image that finishes loading only when [complete] is called.
class _LateImage extends ImageProvider<_LateImage> {
  final completer = _ManualCompleter();

  @override
  Future<_LateImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_LateImage key, ImageDecoderCallback decode) => completer;

  Future<void> complete(WidgetTester tester) async {
    final image = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint());
      return recorder.endRecording().toImage(4, 4);
    });
    completer.finish(ImageInfo(image: image!));
  }
}

class _ManualCompleter extends ImageStreamCompleter {
  void finish(ImageInfo info) => setImage(info);
}

Widget _cropper(ImageProvider provider) => Directionality(
      textDirection: TextDirection.ltr,
      child: Cropper(cropperKey: GlobalKey(), image: Image(image: provider)),
    );

void main() {
  testWidgets('an image that loads after the cropper is gone does nothing', (tester) async {
    final provider = _LateImage();
    await tester.pumpWidget(_cropper(provider));
    await tester.pumpWidget(const SizedBox());

    await provider.complete(tester);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('an image that loads while the cropper is showing is fine', (tester) async {
    final provider = _LateImage();
    await tester.pumpWidget(_cropper(provider));

    await provider.complete(tester);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
