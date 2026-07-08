import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quran_model.dart';

class QuranService {
  static const String _lastReadSurahKey = 'last_read_surah_number';
  static const String _lastReadAyahKey = 'last_read_ayah_number';
  static const String _lastReadNameKey = 'last_read_surah_name';
  static const String _lastReadPageKey = 'last_read_page_number';
  static const String _bookmarkedSurahKey = 'bookmarked_surahs';
  static const String _bookmarkedAyahKey = 'bookmarked_ayahs';
  static const String _bookmarkedPagesKey = 'bookmarked_pages';
  static const String _bookmarkedJuzKey = 'bookmarked_juz';
  static const String _khatamDaysKey = 'khatam_target_days';
  static const String _khatamStartedAtKey = 'khatam_started_at';
  static const String _khatamReadAyahsKey = 'khatam_read_ayahs';
  static const int _quranTotalAyahs = 6236;
  List<QuranPageStart>? _pageStartsCache;
  List<Map<String, dynamic>>? _catalogCache;

  Future<List<Map<String, dynamic>>> _loadCatalogData() async {
    if (_catalogCache != null) {
      return _catalogCache!;
    }

    try {
      final raw = await rootBundle.loadString('assets/data/quran_complete.json');
      final decoded = jsonDecode(raw);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      if (data is List) {
        _catalogCache = data.whereType<Map<String, dynamic>>().toList();
        return _catalogCache!;
      }
    } catch (_) {}

    _catalogCache = const <Map<String, dynamic>>[];
    return _catalogCache!;
  }

  Future<List<QuranSurahSummary>> fetchSurahs() async {
    final data = await _loadCatalogData();
    return data.map(QuranSurahSummary.fromJson).toList();
  }

  Future<List<QuranJuz>> fetchJuzs() async {
    final data = await _loadCatalogData();
    if (data.isNotEmpty) {
      final surahs = data.whereType<Map<String, dynamic>>().toList();
      final ayahEntries = <QuranJuzAyah>[];
        for (final surah in surahs) {
          final surahNumber = _parseInt(surah['number']);
          final surahName = surah['englishName']?.toString() ?? 'Surah $surahNumber';
          final ayahs = surah['ayahs'] is List ? surah['ayahs'] as List : <dynamic>[];
          for (final ayah in ayahs.whereType<Map<String, dynamic>>()) {
            final juzNumber = _parseInt(ayah['juz']);
            if (juzNumber > 0) {
              ayahEntries.add(QuranJuzAyah(
                juzNumber: juzNumber,
                surahNumber: surahNumber,
                surahName: surahName,
                ayahNumber: _parseInt(ayah['numberInSurah']),
              ));
            }
          }
        }

        final grouped = <int, List<QuranJuzAyah>>{};
        for (final item in ayahEntries) {
          grouped.putIfAbsent(item.juzNumber, () => <QuranJuzAyah>[]).add(item);
        }

        final juzs = <QuranJuz>[];
        for (var i = 1; i <= 30; i++) {
          final entries = grouped[i] ?? <QuranJuzAyah>[];
          if (entries.isEmpty) {
            continue;
          }
          final first = entries.first;
          final last = entries.last;
          juzs.add(QuranJuz(
            number: i,
            title: 'Juz $i',
            startSurahNumber: first.surahNumber,
            startAyahNumber: first.ayahNumber,
            endSurahNumber: last.surahNumber,
            endAyahNumber: last.ayahNumber,
          ));
        }
        return juzs;
      }
    } catch (_) {}

    return <QuranJuz>[];
  }

  Future<SurahDetail> fetchSurahDetail(int number) async {
    final summaryList = await fetchSurahs();
    final summary = summaryList.firstWhere(
      (surah) => surah.number == number,
      orElse: () => QuranSurahSummary(
        number: number,
        name: 'Surah $number',
        englishName: 'Surah $number',
        englishNameTranslation: '',
        revelationType: '',
        numberOfAyahs: 0,
      ),
    );

    try {
      final data = await _loadCatalogData();
      final surahJson = data.whereType<Map<String, dynamic>>().firstWhere(
        (entry) => _parseInt(entry['number']) == number,
        orElse: () => <String, dynamic>{},
      );

      if (surahJson.isNotEmpty) {
          final ayahs = surahJson['ayahs'] is List ? surahJson['ayahs'] as List : <dynamic>[];
          final arabic = ayahs
              .whereType<Map<String, dynamic>>()
              .map(
                (entry) {
                  final numberInSurah = _parseInt(entry['numberInSurah']);
                  return QuranAyah(
                    surahNumber: number,
                    number: _parseInt(entry['number']),
                    numberInSurah: numberInSurah > 0 ? numberInSurah : _parseInt(entry['number']),
                    juz: _parseInt(entry['juz']),
                    text: entry['arab']?.toString() ?? '',
                  );
                },
              )
              .toList();

          final translit = ayahs
              .whereType<Map<String, dynamic>>()
              .map(
                (entry) {
                  final numberInSurah = _parseInt(entry['numberInSurah']);
                  return QuranAyah(
                    surahNumber: number,
                    number: _parseInt(entry['number']),
                    numberInSurah: numberInSurah > 0 ? numberInSurah : _parseInt(entry['number']),
                    juz: _parseInt(entry['juz']),
                    text: entry['latin']?.toString() ?? '',
                  );
                },
              )
              .toList();

          final translation = ayahs
              .whereType<Map<String, dynamic>>()
              .map(
                (entry) {
                  final numberInSurah = _parseInt(entry['numberInSurah']);
                  return QuranAyah(
                    surahNumber: number,
                    number: _parseInt(entry['number']),
                    numberInSurah: numberInSurah > 0 ? numberInSurah : _parseInt(entry['number']),
                    juz: _parseInt(entry['juz']),
                    text: entry['translation']?.toString() ?? '',
                  );
                },
              )
              .toList();

          return SurahDetail(
            summary: summary,
            arabicAyahs: arabic,
            transliterationAyahs: translit,
            translationAyahs: translation,
          );
        }
      }
    } catch (_) {}

    return SurahDetail(
      summary: summary,
      arabicAyahs: const <QuranAyah>[],
      transliterationAyahs: const <QuranAyah>[],
      translationAyahs: const <QuranAyah>[],
    );
  }

  Future<void> saveLastRead(int surahNumber, int ayahNumber, String surahName, {int? pageNumber}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReadSurahKey, surahNumber);
    await prefs.setInt(_lastReadAyahKey, ayahNumber);
    await prefs.setString(_lastReadNameKey, surahName);
    await prefs.setInt(_lastReadPageKey, pageNumber ?? 1);
  }

  Future<Map<String, dynamic>?> getLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final surahNumber = prefs.getInt(_lastReadSurahKey);
    if (surahNumber == null) {
      return null;
    }
    return <String, dynamic>{
      'surahNumber': surahNumber,
      'ayahNumber': prefs.getInt(_lastReadAyahKey) ?? 1,
      'surahName': prefs.getString(_lastReadNameKey) ?? 'Surah $surahNumber',
      'pageNumber': prefs.getInt(_lastReadPageKey) ?? 1,
    };
  }

  Future<void> toggleSurahBookmark(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarkedSurahKey) ?? <String>[];
    final key = surahNumber.toString();
    if (bookmarks.contains(key)) {
      bookmarks.remove(key);
    } else {
      bookmarks.add(key);
    }
    await prefs.setStringList(_bookmarkedSurahKey, bookmarks);
  }

  Future<bool> isSurahBookmarked(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarkedSurahKey) ?? <String>[];
    return bookmarks.contains(surahNumber.toString());
  }

  Future<Set<int>> getBookmarkedSurahs() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarkedSurahKey) ?? <String>[];
    return bookmarks.map(int.parse).toSet();
  }

  Future<void> toggleAyahBookmark(int surahNumber, int ayahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarkedAyahKey) ?? <String>[];
    final key = '$surahNumber:$ayahNumber';
    if (bookmarks.contains(key)) {
      bookmarks.remove(key);
    } else {
      bookmarks.add(key);
    }
    await prefs.setStringList(_bookmarkedAyahKey, bookmarks);
  }

  Future<bool> isAyahBookmarked(int surahNumber, int ayahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarkedAyahKey) ?? <String>[];
    return bookmarks.contains('$surahNumber:$ayahNumber');
  }

  Future<Set<String>> getBookmarkedAyahs() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_bookmarkedAyahKey) ?? <String>[]).toSet();
  }

  Future<void> togglePageBookmark(int surahNumber, int pageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarkedPagesKey) ?? <String>[];
    final key = '$surahNumber:$pageNumber';
    if (bookmarks.contains(key)) {
      bookmarks.remove(key);
    } else {
      bookmarks.add(key);
    }
    await prefs.setStringList(_bookmarkedPagesKey, bookmarks);
  }

  Future<bool> isPageBookmarked(int surahNumber, int pageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarkedPagesKey) ?? <String>[];
    return bookmarks.contains('$surahNumber:$pageNumber');
  }

  Future<void> toggleJuzBookmark(int juzNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarkedJuzKey) ?? <String>[];
    final key = juzNumber.toString();
    if (bookmarks.contains(key)) {
      bookmarks.remove(key);
    } else {
      bookmarks.add(key);
    }
    await prefs.setStringList(_bookmarkedJuzKey, bookmarks);
  }

  Future<bool> isJuzBookmarked(int juzNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarkedJuzKey) ?? <String>[];
    return bookmarks.contains(juzNumber.toString());
  }

  Future<Set<int>> getBookmarkedJuzs() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarkedJuzKey) ?? <String>[];
    return bookmarks.map(int.parse).toSet();
  }

  Future<String?> fetchAsbabunNuzul(int surahNumber, int ayahNumber) async {
    try {
      final raw = await rootBundle.loadString('assets/data/tafsir_jalalain.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final surahs = decoded['surahs'];
        if (surahs is List) {
          final surahJson = surahs.whereType<Map<String, dynamic>>().firstWhere(
            (entry) => _parseInt(entry['number']) == surahNumber,
            orElse: () => <String, dynamic>{},
          );

          if (surahJson.isNotEmpty) {
            final ayahs = surahJson['ayahs'] is List ? surahJson['ayahs'] as List : <dynamic>[];
            final entry = ayahs.whereType<Map<String, dynamic>>().firstWhere(
              (item) => _parseInt(item['ayah']) == ayahNumber,
              orElse: () => <String, dynamic>{},
            );

            if (entry.isNotEmpty) {
              final text = entry['text']?.toString() ?? '';
              if (text.isNotEmpty) {
                return text.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
              }
            }
          }
        }
      }
    } catch (_) {}

    try {
      final response = await http.get(
        Uri.parse('https://api.quran.com/api/v4/tafsirs/169/by_ayah/$surahNumber:$ayahNumber'),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final tafsir = decoded['tafsir'];
          if (tafsir is Map<String, dynamic>) {
            final text = tafsir['text']?.toString();
            final cleaned = text == null ? '' : _stripHtml(text);
            if (cleaned.isNotEmpty) {
              return cleaned;
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<List<int>> fetchSurahPageRange(int surahNumber) async {
    try {
      final response = await http.get(Uri.parse('https://api.quran.com/api/v4/chapters/$surahNumber?language=id'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final chapter = decoded['chapter'];
          if (chapter is Map<String, dynamic>) {
            final pages = chapter['pages'];
            if (pages is List) {
              final start = _parseInt(pages.firstOrNull);
              final end = _parseInt(pages.lastOrNull);
              if (start > 0 && end >= start) {
                return List<int>.generate(end - start + 1, (index) => start + index);
              }
            }
          }
        }
      }
    } catch (_) {}

    return <int>[1];
  }

  Future<List<QuranPageStart>> _fetchPageStarts() async {
    if (_pageStartsCache != null) {
      return _pageStartsCache!;
    }
    try {
      final raw = await rootBundle.loadString('assets/data/quran_page_starts.json');
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _pageStartsCache = decoded
            .whereType<Map<String, dynamic>>()
            .map(QuranPageStart.fromJson)
            .toList();
        return _pageStartsCache!;
      }
    } catch (_) {}
    _pageStartsCache = const <QuranPageStart>[];
    return _pageStartsCache!;
  }

  Future<QuranPage> fetchPage(int pageNumber) async {
    final pageStarts = await _fetchPageStarts();
    if (pageNumber < 1 || pageNumber > 604) {
      return QuranPage(number: pageNumber, juzNumber: 0, ayahs: const <QuranAyah>[]);
    }

    try {
      final data = await _loadCatalogData();
      if (data.isNotEmpty) {
        final pageStart = pageStarts.firstWhere((item) => item.page == pageNumber, orElse: () => QuranPageStart(page: pageNumber, surah: 1, ayah: 1, juz: 0));
        final pageIndex = data.whereType<Map<String, dynamic>>().toList().indexWhere((entry) => _parseInt(entry['number']) == pageStart.surah);
        if (pageIndex >= 0) {
          final surahJson = data.whereType<Map<String, dynamic>>().elementAt(pageIndex);
          final ayahs = surahJson['ayahs'] is List ? surahJson['ayahs'] as List : <dynamic>[];
          final currentSurahNumber = _parseInt(surahJson['number']);

          // Build page ayahs across surah boundaries until next page starts or end of surah.
          final nextPageStart = pageStarts.firstWhere(
            (item) => item.page == pageNumber + 1,
            orElse: () => QuranPageStart(page: pageNumber + 1, surah: currentSurahNumber, ayah: ayahs.length + 1, juz: pageStart.juz),
          );

          final collectedAyahs = <QuranAyah>[];

          for (var currentIndex = pageIndex; currentIndex < data.length; currentIndex++) {
            final currentSurahJson = data.whereType<Map<String, dynamic>>().elementAt(currentIndex);
            final currentSurahNumber = _parseInt(currentSurahJson['number']);
            final currentAyahs = currentSurahJson['ayahs'] is List ? currentSurahJson['ayahs'] as List : <dynamic>[];
            final startAyah = currentSurahNumber == pageStart.surah ? pageStart.ayah : 1;
            final endAyah = currentSurahNumber == nextPageStart.surah ? nextPageStart.ayah - 1 : 9999;

            for (final entry in currentAyahs.whereType<Map<String, dynamic>>()) {
              final numberInSurah = _parseInt(entry['numberInSurah']);
              if (numberInSurah >= startAyah && numberInSurah <= endAyah) {
                collectedAyahs.add(QuranAyah(
                  surahNumber: currentSurahNumber,
                  number: _parseInt(entry['number']),
                  numberInSurah: numberInSurah,
                  juz: _parseInt(entry['juz']),
                  text: entry['arab']?.toString() ?? '',
                ));
              }
            }

            if (currentSurahNumber == nextPageStart.surah) {
              break;
            }
          }

          return QuranPage(
            number: pageNumber,
            juzNumber: pageStart.juz,
            ayahs: collectedAyahs,
          );
        }
      }
    } catch (_) {}

    return QuranPage(number: pageNumber, juzNumber: 0, ayahs: const <QuranAyah>[]);
  }

  Future<int> resolvePageForAyah(int surahNumber, int ayahNumber) async {
    final pageStarts = await _fetchPageStarts();
    final sorted = pageStarts.toList()..sort((a, b) => a.page.compareTo(b.page));
    for (var i = sorted.length - 1; i >= 0; i--) {
      final page = sorted[i];
      if (surahNumber > page.surah || (surahNumber == page.surah && ayahNumber >= page.ayah)) {
        return page.page;
      }
    }
    return 1;
  }

  Future<int> resolvePageForJuz(int juzNumber) async {
    final juzs = await fetchJuzs();
    final targetJuz = juzs.where((juz) => juz.number == juzNumber).toList();
    if (targetJuz.isNotEmpty) {
      return resolvePageForAyah(targetJuz.first.startSurahNumber, targetJuz.first.startAyahNumber);
    }
    return 1;
  }

  Future<void> saveTargetKhatam({required int days, required DateTime startedAt}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_khatamDaysKey, days);
    await prefs.setString(_khatamStartedAtKey, '${startedAt.year}-${startedAt.month.toString().padLeft(2, '0')}-${startedAt.day.toString().padLeft(2, '0')}');
  }

  Future<Map<String, dynamic>> getTargetKhatam() async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(_khatamDaysKey) ?? 30;
    final startedAt = prefs.getString(_khatamStartedAtKey) ?? '2026-01-01';
    return <String, dynamic>{'days': days, 'startedAt': startedAt};
  }

  Future<void> markAyahRead(int surahNumber, int ayahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final readAyahs = prefs.getStringList(_khatamReadAyahsKey) ?? <String>[];
    final today = DateTime.now();
    final marker = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}:$surahNumber:$ayahNumber';
    if (!readAyahs.contains(marker)) {
      readAyahs.add(marker);
      await prefs.setStringList(_khatamReadAyahsKey, readAyahs);
    }
  }

  Future<Map<String, dynamic>> getKhatamProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final readAyahs = prefs.getStringList(_khatamReadAyahsKey) ?? <String>[];
    final target = await getTargetKhatam();
    final days = target['days'] as int? ?? 30;
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todayReads = readAyahs.where((entry) => entry.startsWith('$todayKey:')).length;
    final totalReads = readAyahs.length;
    final dailyTarget = (_quranTotalAyahs / days).ceil();
    final percentage = (totalReads / _quranTotalAyahs * 100).clamp(0.0, 100.0);

    return <String, dynamic>{
      'days': days,
      'startedAt': target['startedAt'],
      'completedAyahs': totalReads,
      'dailyProgress': todayReads,
      'dailyTarget': dailyTarget,
      'percentage': percentage,
      'remainingAyahs': (_quranTotalAyahs - totalReads).clamp(0, _quranTotalAyahs),
    };
  }

  Future<void> dispose() async {}

  String _stripHtml(String input) {
    final withoutTags = input.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}

