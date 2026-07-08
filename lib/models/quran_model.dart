class QuranSurahSummary {
  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final String revelationType;
  final int numberOfAyahs;

  QuranSurahSummary({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.revelationType,
    required this.numberOfAyahs,
  });

  factory QuranSurahSummary.fromJson(Map<String, dynamic> json) {
    final numberOfAyahs = json['numberOfAyahs'] is int
        ? json['numberOfAyahs'] as int
        : json['ayahs'] is List
            ? (json['ayahs'] as List).length
            : 0;

    return QuranSurahSummary(
      number: json['number'] is int ? json['number'] as int : int.tryParse('${json['number']}') ?? 0,
      name: json['name']?.toString() ?? '',
      englishName: json['englishName']?.toString() ?? '',
      englishNameTranslation: json['englishNameTranslation']?.toString() ?? '',
      revelationType: json['revelationType']?.toString() ?? '',
      numberOfAyahs: numberOfAyahs,
    );
  }
}

class QuranAyah {
  final int surahNumber;
  final int number;
  final int numberInSurah;
  final int juz;
  final String text;

  QuranAyah({
    required this.surahNumber,
    required this.number,
    required this.numberInSurah,
    required this.juz,
    required this.text,
  });

  factory QuranAyah.fromJson(Map<String, dynamic> json, {int surahNumber = 0}) {
    return QuranAyah(
      surahNumber: surahNumber,
      number: json['number'] is int ? json['number'] as int : int.tryParse('${json['number']}') ?? 0,
      numberInSurah: json['numberInSurah'] is int
          ? json['numberInSurah'] as int
          : int.tryParse('${json['numberInSurah']}') ?? 0,
      juz: json['juz'] is int ? json['juz'] as int : int.tryParse('${json['juz']}') ?? 0,
      text: json['text']?.toString() ??
          json['arab']?.toString() ??
          json['latin']?.toString() ??
          json['translation']?.toString() ??
          '',
    );
  }
}

class QuranJuzAyah {
  final int juzNumber;
  final int surahNumber;
  final String surahName;
  final int ayahNumber;

  QuranJuzAyah({
    required this.juzNumber,
    required this.surahNumber,
    required this.surahName,
    required this.ayahNumber,
  });
}

class QuranJuz {
  final int number;
  final String title;
  final int startSurahNumber;
  final int startAyahNumber;
  final int endSurahNumber;
  final int endAyahNumber;

  QuranJuz({
    required this.number,
    required this.title,
    required this.startSurahNumber,
    required this.startAyahNumber,
    required this.endSurahNumber,
    required this.endAyahNumber,
  });
}

class QuranPageStart {
  final int page;
  final int surah;
  final int ayah;
  final int juz;

  QuranPageStart({
    required this.page,
    required this.surah,
    required this.ayah,
    required this.juz,
  });

  factory QuranPageStart.fromJson(Map<String, dynamic> json) {
    int parse(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return QuranPageStart(
      page: parse(json['page']),
      surah: parse(json['surah']),
      ayah: parse(json['ayah']),
      juz: parse(json['juz']),
    );
  }
}

class QuranPage {
  final int number;
  final int juzNumber;
  final List<QuranAyah> ayahs;

  QuranPage({
    required this.number,
    required this.juzNumber,
    required this.ayahs,
  });
}

class QuranEdition {
  final String identifier;
  final String language;
  final String name;
  final String englishName;
  final String format;
  final String type;
  final String direction;

  QuranEdition({
    required this.identifier,
    required this.language,
    required this.name,
    required this.englishName,
    required this.format,
    required this.type,
    required this.direction,
  });

  factory QuranEdition.fromJson(Map<String, dynamic> json) {
    return QuranEdition(
      identifier: json['identifier']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      englishName: json['englishName']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'ltr',
    );
  }
}

class QuranSurah {
  final QuranSurahSummary summary;
  final List<QuranAyah> ayahs;
  final QuranEdition edition;

  QuranSurah({
    required this.summary,
    required this.ayahs,
    required this.edition,
  });

  factory QuranSurah.fromJson(Map<String, dynamic> json) {
    final summary = QuranSurahSummary.fromJson(json);
    final rawAyahs = json['ayahs'] is List ? json['ayahs'] as List : <dynamic>[];
    final ayahs = rawAyahs
        .whereType<Map<String, dynamic>>()
        .map(QuranAyah.fromJson)
        .toList();
    final edition = json['edition'] is Map<String, dynamic>
        ? QuranEdition.fromJson(json['edition'] as Map<String, dynamic>)
        : QuranEdition(
            identifier: '',
            language: '',
            name: '',
            englishName: '',
            format: '',
            type: '',
            direction: 'ltr',
          );

    return QuranSurah(
      summary: summary,
      ayahs: ayahs,
      edition: edition,
    );
  }
}

class SurahDetail {
  final QuranSurahSummary summary;
  final List<QuranAyah> arabicAyahs;
  final List<QuranAyah> transliterationAyahs;
  final List<QuranAyah> translationAyahs;
  final String? warningMessage;

  SurahDetail({
    required this.summary,
    required this.arabicAyahs,
    required this.transliterationAyahs,
    required this.translationAyahs,
    this.warningMessage,
  });
}
