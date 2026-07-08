import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../services/quran_audio_service.dart';
import '../services/quran_service.dart';

class MurottalScreen extends StatefulWidget {
  const MurottalScreen({super.key});

  @override
  State<MurottalScreen> createState() => _MurottalScreenState();
}

class _MurottalScreenState extends State<MurottalScreen> {
  final QuranService _service = QuranService();
  final AppSettingsService _settingsService = AppSettingsService.instance;
  final QuranAudioService _audioService = QuranAudioService();
  late Future<List<dynamic>> _surahsFuture;
  String _selectedQariCode = 'abdullah_basfar';
  String _selectedQariName = 'Abdullah Basfar';

  @override
  void initState() {
    super.initState();
    _surahsFuture = Future.value(const <dynamic>[]);
    _settingsService.addListener(_refreshSettings);
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _surahsFuture = _service.fetchSurahs();
        });
      }
    });
  }

  @override
  void dispose() {
    _settingsService.removeListener(_refreshSettings);
    _audioService.dispose();
    _service.dispose();
    super.dispose();
  }

  void _refreshSettings() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSettings() async {
    final settings = _settingsService.currentSettings;
    setState(() {
      _selectedQariCode = settings.qariCode;
      _selectedQariName = settings.qariName;
    });
  }

  Future<void> _playSurah(int surahNumber) async {
    await _audioService.setQari(_selectedQariCode, _selectedQariName);
    await _audioService.playAyah(surahNumber: surahNumber, ayahNumber: 1, totalAyahs: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Murottal Al-Qur\'an')),
      body: FutureBuilder<List<dynamic>>(
        future: _surahsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final surahs = snapshot.data ?? <dynamic>[];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedQariCode,
                  decoration: const InputDecoration(labelText: 'Pilih Qari'),
                  items: const [
                    DropdownMenuItem(value: 'abdullah_basfar', child: Text('Abdullah Basfar')),
                    DropdownMenuItem(value: 'mishary_alafasy', child: Text('Mishary Alafasy')),
                    DropdownMenuItem(value: 'sahl_yassin', child: Text('Sahl Yassin')),
                  ],
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }
                    final name = value == 'abdullah_basfar'
                        ? 'Abdullah Basfar'
                        : value == 'mishary_alafasy'
                            ? 'Mishary Alafasy'
                            : 'Sahl Yassin';
                    setState(() {
                      _selectedQariCode = value;
                      _selectedQariName = name;
                    });
                    await _audioService.setQari(value, name);
                    await _settingsService.updateQari(value, name);
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: surahs.length,
                  itemBuilder: (context, index) {
                    final surah = surahs[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(surah.number.toString())),
                      title: Text(surah.englishName),
                      subtitle: Text('${surah.name} • ${surah.numberOfAyahs} ayat'),
                      trailing: IconButton(
                        icon: Icon(_audioService.currentSurahNumber == surah.number ? Icons.pause_circle : Icons.play_circle_fill),
                        onPressed: () => _playSurah(surah.number),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
