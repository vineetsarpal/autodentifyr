// Run with flutter run --release -t tool/check_model_inference.dart -d DEVICE.
// Exercises the packaged model and native runtime without authentication or photos.
import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/services/model_manager.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:ultralytics_yolo/yolo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(home: Scaffold(body: Text('Testing model inference'))),
  );
  YOLO? yolo;
  var status = 'FAIL';
  try {
    final path = await ModelManager().getModelPath(ModelType.detect);
    if (path == null) throw StateError('No detection model found');
    yolo = YOLO(modelPath: path, task: ModelType.detect.task);
    await yolo.loadModel();
    final result = await yolo.predict(
      img.encodePng(img.Image(width: 64, height: 64)),
    );
    if (result['boxes'] is! List) throw StateError('Missing prediction boxes');
    status = 'PASS';
  } catch (error, stack) {
    debugPrint('[model-smoke] $error\n$stack');
  } finally {
    await yolo?.dispose();
  }
  debugPrint('[model-smoke] $status');
  runApp(
    MaterialApp(
      home: Scaffold(body: Center(child: Text('Model inference: $status'))),
    ),
  );
}
