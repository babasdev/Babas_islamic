import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:babas_app/services/quran_audio_service.dart';
import 'package:babas_app/services/quran_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Quran service loads complete surah catalog and full verse details', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final service = QuranService();

    final surahs = await service.fetchSurahs();
    expect(surahs.length, 114);

    final fatihah = await service.fetchSurahDetail(1);
    expect(fatihah.summary.number, 1);
    expect(fatihah.arabicAyahs.length, 7);
    expect(fatihah.transliterationAyahs.length, 7);
    expect(fatihah.translationAyahs.length, 7);

    final baqarah = await service.fetchSurahDetail(2);
    expect(baqarah.summary.number, 2);
    expect(baqarah.arabicAyahs.length, 286);
    expect(baqarah.transliterationAyahs.length, 286);
    expect(baqarah.translationAyahs.length, 286);
  });

  test('Quran service stores khatam target and tracks read progress', () async {
    SharedPreferences.setMockInitialValues({});
    final service = QuranService();

    await service.saveTargetKhatam(days: 30, startedAt: DateTime(2026, 1, 1));
    await service.markAyahRead(1, 1);
    await service.markAyahRead(1, 2);

    final target = await service.getTargetKhatam();
    final progress = await service.getKhatamProgress();

    expect(target['days'], 30);
    expect(target['startedAt'], '2026-01-01');
    expect(progress['completedAyahs'], 2);
    expect(progress['percentage'], greaterThan(0));
    expect(progress['dailyProgress'], greaterThanOrEqualTo(0));
  });

  test('Quran service exposes all 30 juz and resolves the first page for juz 1', () async {
    final service = QuranService();

    final juzs = await service.fetchJuzs();
    expect(juzs.length, 30);

    final firstPage = await service.resolvePageForJuz(1);
    expect(firstPage, 1);
  });

  test('Quran service maps mushaf pages from the page start dataset', () async {
    final service = QuranService();

    final firstPage = await service.fetchPage(1);
    expect(firstPage.ayahs.isNotEmpty, isTrue);
    expect(firstPage.ayahs.first.surahNumber, 1);
    expect(firstPage.ayahs.first.numberInSurah, 1);

    final secondPage = await service.fetchPage(2);
    expect(secondPage.ayahs.isNotEmpty, isTrue);
    expect(secondPage.ayahs.first.surahNumber, 2);
  });

  test('Quran service exposes the full mushaf page range and terminal page', () async {
    final service = QuranService();

    final page604 = await service.fetchPage(604);
    expect(page604.ayahs.isNotEmpty, isTrue);

    final pageRange = await service.resolvePageForAyah(114, 6);
    expect(pageRange, greaterThan(0));
  });

  test('Quran audio service resolves a public verse audio URL for a valid qari', () async {
    final service = QuranAudioService();

    final url = await service.resolveAudioUrl(surahNumber: 1, ayahNumber: 1);

    expect(url, isNotNull);
    expect(url, startsWith('https://'));
    expect(url, contains('.mp3'));

    await service.dispose();
  });

  test('Quran service returns local Asbabun Nuzul text for a known ayah', () async {
    final service = QuranService();

    final text = await service.fetchAsbabunNuzul(2, 232);

    expect(text, isNotNull);
    expect(text, contains('Asbabun'));
  });
}
