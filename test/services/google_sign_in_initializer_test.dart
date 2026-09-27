import 'dart:async';

import 'package:autodentifyr/services/google_sign_in_initializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shares one pending Google Sign-In initialization', () async {
    final completer = Completer<void>();
    var initializationCount = 0;
    final initializer = GoogleSignInInitializer(
      initialize: () {
        initializationCount += 1;
        return completer.future;
      },
    );

    final firstInitialization = initializer.ensureInitialized();
    final secondInitialization = initializer.ensureInitialized();

    expect(initializationCount, 1);
    expect(identical(firstInitialization, secondInitialization), isTrue);

    completer.complete();
    await Future.wait([firstInitialization, secondInitialization]);

    await initializer.ensureInitialized();

    expect(initializationCount, 1);
  });
}
