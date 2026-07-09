import 'package:flutter/material.dart';
import '../models/quran_model.dart';
import '../services/app_settings_service.dart';

class MushafPageViewer extends StatefulWidget {
  final QuranPage page;
  final int currentAyah;
  final Set<String> bookmarkedAyahs;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int>? onAyahTapped;
  final ValueChanged<int>? onAyahBookmarkToggled;
  final double zoomLevel;
  final bool showTranslation;
  final VoidCallback? onTranslationToggle;
  final String surahName;
  final int surahNumber;
  final int pageNumber;

  const MushafPageViewer({
    super.key,
    required this.page,
    required this.currentAyah,
    required this.bookmarkedAyahs,
    this.onPreviousPage,
    this.onNextPage,
    this.onAyahTapped,
    this.onAyahBookmarkToggled,
    this.zoomLevel = 1.0,
    this.showTranslation = false,
    this.onTranslationToggle,
    required this.surahName,
    required this.surahNumber,
    required this.pageNumber,
  });

  @override
  State<MushafPageViewer> createState() => _MushafPageViewerState();
}

class _MushafPageViewerState extends State<MushafPageViewer> {
  late AppSettingsService _settingsService;
  int? _selectedAyah;

  @override
  void initState() {
    super.initState();
    _settingsService = AppSettingsService.instance;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final settings = _settingsService.currentSettings;

    return Column(
      children: [
        _buildMushafHeader(context, isDarkMode),
        Expanded(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDarkMode
                        ? [const Color(0xFF1A1410), const Color(0xFF2A1F18)]
                        : [const Color(0xFFFBF9F4), const Color(0xFFF3EBE0)],
                  ),
                ),
              ),
              SingleChildScrollView(
                child: _buildMushafPageContent(context, isDarkMode, settings),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMushafHeader(BuildContext context, bool isDarkMode) {
    final theme = Theme.of(context);
    final juzNumber = ((widget.pageNumber - 1) * 30 / 604).floor() + 1;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withAlpha(77)
            : Colors.white.withAlpha(102),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withAlpha(51),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.surahName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Juz ${juzNumber.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withAlpha(179),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60).withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Hal. ${widget.pageNumber.toString().padLeft(3, '0')}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF27AE60),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMushafPageContent(
    BuildContext context,
    bool isDarkMode,
    AppSettings settings,
  ) {
    final ayahs = widget.page.ayahs;

    if (ayahs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Halaman tidak tersedia',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final baseFontSize = (settings.fontSizeArabic * widget.zoomLevel).clamp(18.0, 42.0);
    final lineHeight = 2.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1915) : const Color(0xFFFAF6EF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withAlpha(26)
                : Colors.brown.withAlpha(38),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(38),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mushaf title
                  if (ayahs.first.numberInSurah == 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'سورة ${widget.surahName}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Noto Naskh Arabic',
                                fontSize: baseFontSize * 0.9,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              height: 2,
                              width: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFF27AE60).withAlpha(128),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Ayahs
                  ...List.generate(
                    ayahs.length,
                    (index) => _buildAyahWidget(
                      context,
                      ayahs[index],
                      baseFontSize,
                      lineHeight,
                      isDarkMode,
                      settings,
                    ),
                  ),
                  // Decoration at bottom
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF27AE60).withAlpha(179),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 1,
                            color: const Color(0xFF27AE60).withAlpha(128),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF27AE60).withAlpha(179),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAyahWidget(
    BuildContext context,
    QuranAyah ayah,
    double fontSize,
    double lineHeight,
    bool isDarkMode,
    AppSettings settings,
  ) {
    final isCurrentAyah = ayah.numberInSurah == widget.currentAyah;
    final isBookmarked =
        widget.bookmarkedAyahs.contains('${ayah.surahNumber}:${ayah.numberInSurah}');
    final isSelected = _selectedAyah == ayah.numberInSurah;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        setState(() => _selectedAyah = ayah.numberInSurah);
        widget.onAyahTapped?.call(ayah.numberInSurah);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                  ? Colors.amber.withAlpha(38)
                  : Colors.amber.withAlpha(26))
              : isCurrentAyah
                  ? (isDarkMode
                      ? Colors.green.withAlpha(26)
                      : Colors.green.withAlpha(13))
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: RichText(
                textAlign: TextAlign.right,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: ayah.text,
                      style: TextStyle(
                        fontFamily: settings.arabicFontFamily,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyLarge?.color,
                        height: lineHeight,
                      ),
                    ),
                    TextSpan(
                      text: ' ﴿${ayah.numberInSurah}﴾',
                      style: TextStyle(
                        fontFamily: settings.arabicFontFamily,
                        fontSize: fontSize * 0.75,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF27AE60),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                    color: const Color(0xFF27AE60),
                  ),
                  onPressed: () {
                    widget.onAyahBookmarkToggled?.call(ayah.numberInSurah);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
