import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class RegionPreferenceStore {
  Future<String?> readCountryCode();
  Future<void> writeCountryCode(String? countryCode);
}

/// Stores only the manually selected country, locally on this device.
/// No coordinates, network lookups, or authentication data are needed.
class FileRegionPreferenceStore implements RegionPreferenceStore {
  FileRegionPreferenceStore({Future<File> Function()? resolveFile})
    : _resolveFile = resolveFile ?? _deviceFile;

  final Future<File> Function() _resolveFile;

  static Future<File> _deviceFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/region_preference.json');
  }

  @override
  Future<String?> readCountryCode() async {
    final file = await _resolveFile();
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, dynamic> ||
        json['version'] != 1 ||
        json['countryCode'] is! String) {
      throw const FormatException('Invalid region preference');
    }
    return json['countryCode'] as String;
  }

  @override
  Future<void> writeCountryCode(String? countryCode) async {
    final file = await _resolveFile();
    if (countryCode == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(
      jsonEncode({'version': 1, 'countryCode': countryCode}),
      flush: true,
    );
    await temporaryFile.rename(file.path);
  }
}
