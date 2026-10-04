import 'package:flutter/widgets.dart';

import 'package:autodentifyr/core/localization/region_catalog.dart';
import 'package:autodentifyr/services/region_preference_store.dart';

enum RegionPreferenceSource { deviceRegion, manual }

class RegionPreferenceController extends ChangeNotifier {
  RegionPreferenceController({
    required RegionPreferenceStore store,
    required Locale Function() deviceLocale,
  }) : _store = store,
       _deviceLocale = deviceLocale;

  final RegionPreferenceStore _store;
  final Locale Function() _deviceLocale;
  CountryRegion? _region;
  RegionPreferenceSource _source = RegionPreferenceSource.deviceRegion;
  bool _isBusy = false;
  String? _error;
  bool _disposed = false;

  CountryRegion? get region => _region;
  RegionPreferenceSource get source => _source;
  bool get isBusy => _isBusy;
  String? get error => _error;

  String? get currencyCode => region?.currencyCode;

  Future<void> load() async {
    if (isBusy) return;
    _isBusy = true;
    _error = null;
    _notify();
    try {
      final savedCode = await _store.readCountryCode();
      final savedRegion = RegionCatalog.find(savedCode);
      if (savedCode != null && savedRegion == null) {
        throw const FormatException('Unsupported saved country');
      }
      _region = savedRegion ?? RegionCatalog.find(_deviceLocale().countryCode);
      _source = savedRegion == null
          ? RegionPreferenceSource.deviceRegion
          : RegionPreferenceSource.manual;
    } catch (_) {
      // A failed read must not silently replace an existing manual preference.
      _error = 'Could not load your region. Retry or choose a country.';
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  Future<bool> selectCountry(String? countryCode) async {
    if (isBusy) return false;
    final selected = RegionCatalog.find(countryCode);
    if (countryCode != null && selected == null) {
      _error = 'Choose a supported country.';
      _notify();
      return false;
    }
    _isBusy = true;
    _error = null;
    _notify();
    try {
      await _store.writeCountryCode(selected?.countryCode);
      _region = selected ?? RegionCatalog.find(_deviceLocale().countryCode);
      _source = selected == null
          ? RegionPreferenceSource.deviceRegion
          : RegionPreferenceSource.manual;
      return true;
    } catch (_) {
      _error = 'Could not save your region. Please try again.';
      return false;
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
