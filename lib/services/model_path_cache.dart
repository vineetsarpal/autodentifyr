import 'dart:async';
import 'dart:io';

typedef ModelPathKey = ({String platform, String modelName, String task});

/// Shares successful model paths and in-flight resolutions across managers.
class ModelPathCache {
  final _paths = <ModelPathKey, String>{};
  final _pending = <ModelPathKey, _PathResolution>{};

  Future<String?> resolve({
    required ModelPathKey key,
    required Future<String?> Function(
      void Function(String) status,
      void Function(double) progress,
    )
    load,
    void Function(String)? onStatus,
    void Function(double)? onProgress,
  }) {
    final existing = _pending[key];
    if (existing != null) {
      existing.subscribe(onStatus, onProgress);
      return existing.result.future;
    }

    final resolution = _PathResolution();
    _pending[key] = resolution;
    resolution.subscribe(onStatus, onProgress);
    unawaited(_resolve(key, resolution, load));
    return resolution.result.future;
  }

  Future<void> _resolve(
    ModelPathKey key,
    _PathResolution resolution,
    Future<String?> Function(
      void Function(String) status,
      void Function(double) progress,
    )
    load,
  ) async {
    try {
      final cached = _paths[key];
      String? path;
      if (cached != null && await _exists(key, cached)) {
        path = cached;
      } else {
        _paths.remove(key);
        path = await load(resolution.status, resolution.progress);
        if (path != null) _paths[key] = path;
      }
      _pending.remove(key);
      resolution.result.complete(path);
    } catch (error, stack) {
      _pending.remove(key);
      resolution.result.completeError(error, stack);
    } finally {
      resolution.subscribers.clear();
    }
  }

  Future<bool> _exists(ModelPathKey key, String path) async {
    if (key.platform == 'ios') {
      // Bundle identifiers remain valid for the life of the installed process.
      if (path == key.modelName) return true;
      return await Directory(path).exists() &&
          await File('$path/Manifest.json').exists();
    }
    return File(path).exists();
  }
}

class _PathResolution {
  final result = Completer<String?>();
  final subscribers =
      <({void Function(String)? status, void Function(double)? progress})>[];
  String? lastStatus;
  double? lastProgress;

  void subscribe(
    void Function(String)? onStatus,
    void Function(double)? onProgress,
  ) {
    subscribers.add((status: onStatus, progress: onProgress));
    if (lastStatus != null) onStatus?.call(lastStatus!);
    if (lastProgress != null) onProgress?.call(lastProgress!);
  }

  void status(String message) {
    lastStatus = message;
    for (final subscriber in subscribers.toList()) {
      subscriber.status?.call(message);
    }
  }

  void progress(double value) {
    lastProgress = value;
    for (final subscriber in subscribers.toList()) {
      subscriber.progress?.call(value);
    }
  }
}
