import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:mp_chart/mp/controller/controller.dart';
import 'package:mp_chart/mp/core/adapter_gesture_detector.dart';
import 'package:mp_chart/mp/core/local_position_util.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

abstract class Chart<C extends Controller> extends StatefulWidget {
  final C controller;

  @override
  State createState() {
    return controller.createChartState();
  }

  const Chart(this.controller);
}

abstract class ChartState<T extends Chart> extends State<T> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool isCapturing = false;
  bool _singleTap = false;

  void setStateIfNotDispose() {
    if (mounted) {
      setState(() {});
    }
  }

  void updatePainter();

  void capture() async {
    if (isCapturing) return;
    isCapturing = true;
    String directory = "";
    if (Platform.isAndroid) {
      directory = (await getExternalStorageDirectory()).path;
    } else if (Platform.isIOS) {
      directory = (await getApplicationDocumentsDirectory()).path;
    } else {
      return;
    }

    String fileName = DateTime.now().toIso8601String();
    String path = '$directory/$fileName.png';
    _screenshotController.capture(path: path, pixelRatio: 3.0).then((imgFile) {
      ImageGallerySaver.saveImage(Uint8List.fromList(imgFile.readAsBytesSync()))
          .then((value) {
        imgFile.delete();
      });
      isCapturing = false;
    }).catchError((error) {
      isCapturing = false;
    });
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.animator = oldWidget.controller.animator;
    widget.controller.state = this;
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.doneBeforePainterInit();
    widget.controller.initialPainter();
    updatePainter();

    return Screenshot(
        controller: _screenshotController,
        child: Container(
            decoration: BoxDecoration(color: ColorUtils.WHITE),
            child: Stack(
                // Center is a layout widget. It takes a single child and positions it
                // in the middle of the parent.
                children: [
                  ConstrainedBox(
                      constraints: BoxConstraints(
                          minHeight: double.infinity,
                          minWidth: double.infinity),
                      child: AdapterGestureDetector(
                          adapterOnTapDown: (detail, context) {
                            _singleTap = true;
                            onTapDown(
                                detail,
                                LocalPositionUtil.getLocalPosition(
                                    detail.globalPosition, context));
                          },
                          adapterOnTapUp: (detail, context) {
                            if (_singleTap) {
                              _singleTap = false;
                              onSingleTapUp(
                                  detail,
                                  LocalPositionUtil.getLocalPosition(
                                      detail.globalPosition, context));
                            }
                          },
                          adapterOnDoubleTap: (context) {
                            _singleTap = false;
                            onDoubleTap();
                          },
                          adapterOnScaleStart: (detail, context) {
                            onScaleStart(
                                detail,
                                LocalPositionUtil.getLocalPosition(
                                    detail.focalPoint, context));
                          },
                          adapterOnScaleUpdate: (detail, context) {
                            _singleTap = false;
                            onScaleUpdate(
                                detail,
                                LocalPositionUtil.getLocalPosition(
                                    detail.focalPoint, context));
                          },
                          adapterOnScaleEnd: (detail, context) {
                            onScaleEnd(detail);
                          },
                          child:
                              CustomPaint(painter: widget.controller.painter))),
                ])));
  }

  @override
  void reassemble() {
    super.reassemble();
    widget.controller.animator?.reset();
    widget.controller.painter?.reassemble();
  }

  void onDoubleTap();

  void onScaleStart(ScaleStartDetails detail, Offset localFocalPoint);

  void onScaleUpdate(ScaleUpdateDetails detail, Offset localFocalPoint);

  void onScaleEnd(ScaleEndDetails detail);

  void onTapDown(TapDownDetails detail, Offset localPosition);

  void onSingleTapUp(TapUpDetails detail, Offset localPosition);
}
