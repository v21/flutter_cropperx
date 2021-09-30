import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class Cropper extends StatefulWidget {
  /// The cropper's key to reference when calling the crop function.
  final GlobalKey? cropperKey;

  /// The background color of the cropper widget, visible when the image won't
  /// fill the entire widget. Defaults to a light grey color: Color(0xFFCECECE).
  final Color backgroundColor;

  /// The color of the cropper's overlay. Defaults to semi-transparent black
  /// Colors.black54
  final Color overlayColor;

  /// The type of semi-transparent overlay. Can either be an
  /// [OverlayType.circle] or [OverlayType.none] to hide the overlay. Defaults
  /// to none so no overlay is shown by default.
  final OverlayType overlayType;

  /// The maximum scale the user is able to zoom. Defaults to 2.5
  final double zoomScale;

  /// The thickness of the grid lines. Defaults to 2.0.
  final double gridLineThickness;

  /// The image to crop.
  final Image image;

  const Cropper({
    Key? key,
    this.backgroundColor = const Color(0xFFCECECE),
    this.overlayColor = Colors.black54,
    this.overlayType = OverlayType.none,
    this.zoomScale = 2.5,
    this.gridLineThickness = 2.0,
    required this.cropperKey,
    required this.image,
  }) : super(key: key);

  @override
  State<Cropper> createState() => _CropperState();

  /// Crops the image as displayed in the cropper widget. The cropper widget should be referenced
  /// using its key.
  static Future<File> crop({
    required GlobalKey cropperKey,
    required String path,
    required String fileName,
  }) async {
    // Get cropped image
    final boundary = cropperKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);

    // Convert image to bytes in PNG format
    final ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    // Create and return file
    return File('$path/$fileName').writeAsBytes(pngBytes);
  }
}

class _CropperState extends State<Cropper> {
  final TransformationController _transformationController = TransformationController();

  /// Boolean to indicate if the image has been updated after a state change. Used so we don't do
  /// any unnecessary refreshes.
  late bool _hasImageUpdated;

  /// Boolean to indicate whether we need to set the initial scale of an image.
  bool _shouldSetInitialScale = false;

  /// The image configuration used to add the image stream listener to the image.
  final _imageConfiguration = const ImageConfiguration();

  /// Image stream listener which is used to indicate whether the image has finished loading. This
  /// is required to do the initial scaling of the [InteractiveViewer], where we'd like to fill the
  /// viewport by scaling the image down as much as possible.
  late final _imageStreamListener = ImageStreamListener(
    (_, __) {
      setState(() {
        _shouldSetInitialScale = true;
      });
    },
  );

  @override
  void initState() {
    super.initState();
    _hasImageUpdated = true;
  }

  @override
  void didUpdateWidget(covariant Cropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _hasImageUpdated = oldWidget.image.image != widget.image.image;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            key: widget.cropperKey,
            child: LayoutBuilder(
              builder: (_, constraint) {
                return InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  child: Builder(
                    builder: (context) {
                      final imageStream = widget.image.image.resolve(_imageConfiguration);
                      if (_hasImageUpdated && _shouldSetInitialScale) {
                        imageStream.removeListener(_imageStreamListener);
                        WidgetsBinding.instance?.addPostFrameCallback((_) {
                          final renderBox = context.findRenderObject() as RenderBox?;
                          final childSize = renderBox?.size ?? Size.zero;
                          if (childSize != Size.zero) {
                            final parentSize = constraint.biggest;
                            _transformationController.value =
                                Matrix4.identity() * _getCoverRatio(parentSize, childSize);
                          }
                        });
                      }

                      if (_hasImageUpdated && !_shouldSetInitialScale) {
                        imageStream.addListener(_imageStreamListener);
                      }

                      return widget.image;
                    },
                  ),
                  minScale: 0.1,
                  maxScale: widget.zoomScale,
                );
              },
            ),
          ),
          if (widget.overlayType == OverlayType.circle)
            ClipPath(
              clipper: _OverlayFrame(),
              child: Container(
                color: widget.overlayColor,
              ),
            ),
          if (widget.overlayType == OverlayType.grid ||
              widget.overlayType == OverlayType.gridHorizontal)
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Divider(
                  color: widget.overlayColor,
                  thickness: widget.gridLineThickness,
                ),
                Divider(
                  color: widget.overlayColor,
                  thickness: widget.gridLineThickness,
                ),
              ],
            ),
          if (widget.overlayType == OverlayType.grid ||
              widget.overlayType == OverlayType.gridVertical)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                VerticalDivider(
                  color: widget.overlayColor,
                  thickness: widget.gridLineThickness,
                ),
                VerticalDivider(
                  color: widget.overlayColor,
                  thickness: widget.gridLineThickness,
                ),
              ],
            ),
        ],
      ),
    );
  }

  double _getCoverRatio(Size outside, Size inside) {
    return outside.width / outside.height > inside.width / inside.height
        ? outside.width / inside.width
        : outside.height / inside.height;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}

enum OverlayType { circle, grid, gridHorizontal, gridVertical, none }

class _OverlayFrame extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(size.width / 2, size.height / 2),
            radius: size.width / 2,
          ),
        )
        ..close(),
    );
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}