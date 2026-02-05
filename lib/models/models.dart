import 'package:ultralytics_yolo/models/yolo_task.dart';

enum ModelType {
  detect('best', YOLOTask.detect);

  final String modelName;

  final YOLOTask task;

  const ModelType(this.modelName, this.task);
}

enum SliderType { none, confidence }
