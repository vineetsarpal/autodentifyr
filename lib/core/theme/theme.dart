import 'package:autodentifyr/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static _outlineInputBorder({Color color = AppPalette.appGreen}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: 3),
      );

  static final darkThemeMode = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: AppPalette.appBlue,
    appBarTheme: const AppBarTheme(backgroundColor: AppPalette.appBlue),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.all(27),
      enabledBorder: _outlineInputBorder(),
      focusedBorder: _outlineInputBorder(color: AppPalette.appGreen),
    ),
  );
}
