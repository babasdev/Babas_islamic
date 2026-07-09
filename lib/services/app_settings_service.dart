import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.fontSizeArabic = 24,
    this.fontSizeLatin = 15,
    this.fontSizeTranslation = 14,
    this.arabicFontFamily = 'Noto Naskh Arabic',
    this.appFontFamily = 'Noto Sans',
    this.qariCode = 'abdullah_basfar',
    this.qariName = 'Abdullah Basfar',
    this.playbackSpeed = 1.0,
  });

  final ThemeMode themeMode;
  final double fontSizeArabic;
  final double fontSizeLatin;
  final double fontSizeTranslation;
  final String arabicFontFamily;
  final String appFontFamily;
  final String qariCode;
  final String qariName;
  final double playbackSpeed;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? fontSizeArabic,
    double? fontSizeLatin,
    double? fontSizeTranslation,
    String? arabicFontFamily,
    String? appFontFamily,
    String? qariCode,
    String? qariName,
    double? playbackSpeed,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      fontSizeArabic: fontSizeArabic ?? this.fontSizeArabic,
      fontSizeLatin: fontSizeLatin ?? this.fontSizeLatin,
      fontSizeTranslation: fontSizeTranslation ?? this.fontSizeTranslation,
      arabicFontFamily: arabicFontFamily ?? this.arabicFontFamily,
      appFontFamily: appFontFamily ?? this.appFontFamily,
      qariCode: qariCode ?? this.qariCode,
      qariName: qariName ?? this.qariName,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }
}

class AppSettingsService extends ChangeNotifier {
  AppSettingsService._();

  factory AppSettingsService() => instance;

  static final AppSettingsService instance = AppSettingsService._();
  static const List<String> supportedArabicFonts = <String>[
    'Amiri',
    'Scheherazade New',
    'Noto Naskh Arabic',
    'Noto Sans Arabic',
  ];
  static const List<String> supportedAppFonts = <String>[
    'Roboto',
    'Nunito',
    'Poppins',
    'Noto Sans',
  ];

  AppSettings _settings = const AppSettings();
  AppSettings get currentSettings => _settings;

  String normalizeFontFamily(String? fontFamily, {required List<String> allowedFonts}) {
    final trimmed = fontFamily?.trim() ?? '';
    if (trimmed.isEmpty) {
      return allowedFonts.first;
    }
    return allowedFonts.contains(trimmed) ? trimmed : allowedFonts.first;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeValue = prefs.getString('theme_mode');
    final arabicFont = normalizeFontFamily(
      prefs.getString('arabic_font'),
      allowedFonts: supportedArabicFonts,
    );
    final appFont = normalizeFontFamily(
      prefs.getString('app_font'),
      allowedFonts: supportedAppFonts,
    );
    final qariCode = prefs.getString('qari_code') ?? 'abdullah_basfar';
    final qariName = prefs.getString('qari_name') ?? 'Abdullah Basfar';

    _settings = AppSettings(
      themeMode: themeModeValue == 'dark'
          ? ThemeMode.dark
          : themeModeValue == 'light'
              ? ThemeMode.light
              : ThemeMode.system,
      fontSizeArabic: prefs.getDouble('font_size_arabic') ?? 24,
      fontSizeLatin: prefs.getDouble('font_size_latin') ?? 15,
      fontSizeTranslation: prefs.getDouble('font_size_translation') ?? 14,
      arabicFontFamily: arabicFont,
      appFontFamily: appFont,
      qariCode: qariCode,
      qariName: qariName,
      playbackSpeed: prefs.getDouble('playback_speed') ?? 1.0,
    );
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  Future<void> updateFontSizeArabic(double value) async {
    _settings = _settings.copyWith(fontSizeArabic: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size_arabic', value);
    notifyListeners();
  }

  Future<void> updateFontSizeLatin(double value) async {
    _settings = _settings.copyWith(fontSizeLatin: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size_latin', value);
    notifyListeners();
  }

  Future<void> updateFontSizeTranslation(double value) async {
    _settings = _settings.copyWith(fontSizeTranslation: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size_translation', value);
    notifyListeners();
  }

  Future<void> updateArabicFont(String fontFamily) async {
    final normalized = normalizeFontFamily(
      fontFamily,
      allowedFonts: supportedArabicFonts,
    );
    _settings = _settings.copyWith(arabicFontFamily: normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('arabic_font', normalized);
    notifyListeners();
  }

  Future<void> updateAppFont(String fontFamily) async {
    final normalized = normalizeFontFamily(
      fontFamily,
      allowedFonts: supportedAppFonts,
    );
    _settings = _settings.copyWith(appFontFamily: normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_font', normalized);
    notifyListeners();
  }

  Future<void> updateQari(String code, String name) async {
    _settings = _settings.copyWith(qariCode: code, qariName: name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qari_code', code);
    await prefs.setString('qari_name', name);
    notifyListeners();
  }

  Future<void> updatePlaybackSpeed(double value) async {
    _settings = _settings.copyWith(playbackSpeed: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('playback_speed', value);
    notifyListeners();
  }
}
