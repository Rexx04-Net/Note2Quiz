import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsController extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _outputLanguageKey = 'output_language';

  static const List<String> supportedLanguages = <String>[
    'English',
    'Bahasa Melayu',
    'Chinese',
    'Tamil',
  ];

  SharedPreferences? _preferences;
  ThemeMode _themeMode = ThemeMode.dark;
  String _outputLanguage = supportedLanguages.first;

  ThemeMode get themeMode => _themeMode;
  String get outputLanguage => _outputLanguage;

  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    _themeMode = _themeModeFromString(_preferences?.getString(_themeModeKey));
    final savedLanguage =
        _preferences?.getString(_outputLanguageKey) ?? supportedLanguages.first;
    _outputLanguage = supportedLanguages.contains(savedLanguage)
        ? savedLanguage
        : supportedLanguages.first;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    await _preferences?.setString(_themeModeKey, value.name);
  }

  Future<void> setOutputLanguage(String value) async {
    if (_outputLanguage == value) return;
    _outputLanguage = value;
    notifyListeners();
    await _preferences?.setString(_outputLanguageKey, value);
  }

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required AppSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSettingsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}
