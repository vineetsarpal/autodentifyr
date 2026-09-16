import 'package:autodentifyr/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static _outlineInputBorder({required Color color, double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  static final darkThemeMode = ThemeData.dark().copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppPalette.appGreen,
      brightness: Brightness.dark,
      primary: AppPalette.appGreen,
    ),
    scaffoldBackgroundColor: AppPalette.appBlue,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.appBlue,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: _outlineInputBorder(color: AppPalette.separatorColor),
      focusedBorder: _outlineInputBorder(color: AppPalette.appGreen, width: 2),
    ),
  );
}
