// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppSettingsService _settingsService;

  @override
  void initState() {
    super.initState();
    _settingsService = AppSettingsService.instance;
    _settingsService.addListener(_refresh);
  }

  @override
  void dispose() {
    _settingsService.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settingsService.currentSettings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mode Tema', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                      ButtonSegment(value: ThemeMode.system, label: Text('Ikuti sistem')),
                    ],
                    selected: <ThemeMode>{settings.themeMode},
                    onSelectionChanged: (selection) async {
                      await _settingsService.updateThemeMode(selection.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ukuran Huruf', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _fontSizeSlider('Arab', settings.fontSizeArabic, (value) async {
                    await _settingsService.updateFontSizeArabic(value);
                  }),
                  _fontSizeSlider('Latin', settings.fontSizeLatin, (value) async {
                    await _settingsService.updateFontSizeLatin(value);
                  }),
                  _fontSizeSlider('Terjemahan', settings.fontSizeTranslation, (value) async {
                    await _settingsService.updateFontSizeTranslation(value);
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pilihan Font Arab', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: settings.arabicFontFamily,
                    items: const [
                      DropdownMenuItem(value: 'Amiri', child: Text('Amiri')),
                      DropdownMenuItem(value: 'Scheherazade New', child: Text('Scheherazade New')),
                      DropdownMenuItem(value: 'Noto Naskh Arabic', child: Text('Noto Naskh Arabic')),
                      DropdownMenuItem(value: 'Noto Sans Arabic', child: Text('Noto Sans Arabic')),
                    ],
                    onChanged: (value) async {
                      if (value != null) {
                        await _settingsService.updateArabicFont(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pilihan Font Aplikasi', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: settings.appFontFamily,
                    items: const [
                      DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                      DropdownMenuItem(value: 'Nunito', child: Text('Nunito')),
                      DropdownMenuItem(value: 'Poppins', child: Text('Poppins')),
                      DropdownMenuItem(value: 'Noto Sans', child: Text('Noto Sans')),
                    ],
                    onChanged: (value) async {
                      if (value != null) {
                        await _settingsService.updateAppFont(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check),
            label: const Text('Simpan dan Kembali'),
          ),
        ],
      ),
    );
  }

  Widget _fontSizeSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${value.toInt()} pt'),
          ],
        ),
        Slider(
          min: 12,
          max: 32,
          divisions: 20,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
