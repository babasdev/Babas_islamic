import 'dart:async';

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../models/quran_model.dart';
import '../services/app_settings_service.dart';
import '../services/quran_audio_service.dart';
import '../services/quran_service.dart';
import '../widgets/mushaf_page_viewer.dart';
import 'tafsir_screen.dart';

class SurahDetailScreen extends StatefulWidget {
  final SurahDetail detail;
  final int? initialAyahNumber;
  final int? initialPageNumber;

  const SurahDetailScreen({
    super.key,
    required this.detail,
    this.initialAyahNumber,
    this.initialPageNumber,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final QuranService _service = QuranService();
  final ScrollController _scrollController = ScrollController();
  final AppSettingsService _settingsService = AppSettingsService.instance;
  final QuranAudioService _audioService = QuranAudioService();
  late final PageController _mushafPageController;
  StreamSubscription<AudioPlaybackStatus>? _playbackStatusSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<int>? _activeAyahSubscription;
  late final List<GlobalKey> _ayahKeys;
  final Map<int, QuranPage> _mushafPageCache = <int, QuranPage>{};
  final List<QuranSurahSummary> _surahs = <QuranSurahSummary>[];
  final Map<int, String> _surahNamesByNumber = <int, String>{};
  bool _isSurahBookmarked = false;
  bool _isPageBookmarked = false;
  bool _isJuzBookmarked = false;
  String? _audioErrorMessage;
  Set<String> _bookmarkedAyahs = <String>{};
  int _currentAyah = 1;
  bool _showMushafMode = true;
  double _mushafZoom = 1.0;
  int _mushafPage = 1;
  bool _isLoadingPage = false;

  @override
  void initState() {
    super.initState();
    _ayahKeys = List.generate(
      widget.detail.arabicAyahs.length,
      (_) => GlobalKey(),
    );
    _settingsService.addListener(_refreshSettings);
    _audioService.onPlaybackStateChanged = _refreshAudioUi;
    _audioService.onPlaybackCompleted = _handlePlaybackCompleted;
    _audioService.onPositionChanged = (position) {
      if (mounted) {
        setState(() => _audioService.position = position);
      }
    };
    _audioService.onDurationChanged = (duration) {
      if (mounted) {
        setState(() => _audioService.duration = duration);
      }
    };
    _audioService.onError = (message) {
      if (mounted) {
        setState(() => _audioErrorMessage = message);
      }
    };
    _playbackStatusSubscription = _audioService.playbackStatusStream.listen(
      (_) => _refreshAudioUi(),
    );
    _positionSubscription = _audioService.positionStream.listen((position) {
      if (mounted) {
        setState(() => _audioService.position = position);
      }
    });
    _durationSubscription = _audioService.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _audioService.duration = duration);
      }
    });
    _activeAyahSubscription = _audioService.activeAyahStream.listen((ayah) {
      if (mounted) {
        setState(() => _currentAyah = ayah);
        _scrollToAyah(ayah);
      }
    });
    _mushafPageController = PageController(
      initialPage: (widget.initialPageNumber ?? 1).clamp(1, 604) - 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPersistedState();
      }
    });
    // Do not auto-load audio on screen open. Apply persisted audio
    // preferences lazily when the user starts playback.
  }

  @override
  void dispose() {
    _settingsService.removeListener(_refreshSettings);
    _playbackStatusSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _activeAyahSubscription?.cancel();
    _audioService.onPlaybackCompleted = null;
    _audioService.onPlaybackStateChanged = null;
    _audioService.onPositionChanged = null;
    _audioService.onDurationChanged = null;
    _audioService.onError = null;
    _service.dispose();
    _audioService.dispose();
    _scrollController.dispose();
    _mushafPageController.dispose();
    super.dispose();
  }

  void _refreshSettings() {
    if (mounted) {
      setState(() {});
    }
  }

  void _refreshAudioUi() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPersistedState() async {
    final isBookmarked = await _service.isSurahBookmarked(
      widget.detail.summary.number,
    );
    final bookmarkedAyahs = await _service.getBookmarkedAyahs();
    final lastRead = await _service.getLastRead();
    final isPageBookmarked = await _service.isPageBookmarked(
      widget.detail.summary.number,
      _mushafPage,
    );
    final isJuzBookmarked = await _service.isJuzBookmarked(
      widget.detail.summary.number,
    );

    final initialAyah = widget.initialAyahNumber ?? 1;
    final currentAyah =
        (lastRead != null &&
            lastRead['surahNumber'] == widget.detail.summary.number)
        ? (lastRead['ayahNumber'] as int? ?? initialAyah)
        : initialAyah;
    final initialPage =
        widget.initialPageNumber ??
        ((lastRead != null &&
                lastRead['surahNumber'] == widget.detail.summary.number)
            ? (lastRead['pageNumber'] as int? ?? 1)
            : await _service.resolvePageForAyah(
                widget.detail.summary.number,
                currentAyah,
              ));

    if (!mounted) {
      return;
    }

    setState(() {
      _isSurahBookmarked = isBookmarked;
      _bookmarkedAyahs = bookmarkedAyahs;
      _currentAyah = currentAyah;
      _isPageBookmarked = isPageBookmarked;
      _isJuzBookmarked = isJuzBookmarked;
      _mushafPage = initialPage.clamp(1, 604);
    });

    if (_mushafPage > 0) {
      await _loadMushafPage(_mushafPage, animate: false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentAyah > 0) {
        _scrollToAyah(_currentAyah);
      }
    });
  }

  Future<void> _toggleSurahBookmark() async {
    await _service.toggleSurahBookmark(widget.detail.summary.number);
    final isBookmarked = await _service.isSurahBookmarked(
      widget.detail.summary.number,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSurahBookmarked = isBookmarked);
  }

  Future<void> _toggleAyahBookmark(int ayahNumber) async {
    await _service.toggleAyahBookmark(widget.detail.summary.number, ayahNumber);
    final bookmarkedAyahs = await _service.getBookmarkedAyahs();
    if (!mounted) {
      return;
    }
    setState(() => _bookmarkedAyahs = bookmarkedAyahs);
  }

  Future<void> _togglePageBookmark() async {
    await _service.togglePageBookmark(
      widget.detail.summary.number,
      _mushafPage,
    );
    final isPageBookmarked = await _service.isPageBookmarked(
      widget.detail.summary.number,
      _mushafPage,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isPageBookmarked = isPageBookmarked);
  }

  Future<void> _toggleJuzBookmark() async {
    await _service.toggleJuzBookmark(widget.detail.summary.number);
    final isJuzBookmarked = await _service.isJuzBookmarked(
      widget.detail.summary.number,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isJuzBookmarked = isJuzBookmarked);
  }

  Future<void> _toggleNightMode() async {
    final currentMode = _settingsService.currentSettings.themeMode;
    final nextMode = currentMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await _settingsService.updateThemeMode(nextMode);
  }

  Future<void> _markLastRead(int ayahNumber, {int? pageNumber}) async {
    await _service.saveLastRead(
      widget.detail.summary.number,
      ayahNumber,
      widget.detail.summary.englishName,
      pageNumber: pageNumber,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _currentAyah = ayahNumber;
      if (pageNumber != null) {
        _mushafPage = pageNumber;
      }
    });
  }

  Future<void> _playAyah(int ayahNumber, {int? pageNumber}) async {
    await _service.markAyahRead(widget.detail.summary.number, ayahNumber);
    // Ensure audio prefs are applied before starting playback (lazy init)
    await _applyPersistedAudioPreferences();
    await _audioService.playAyah(
      surahNumber: widget.detail.summary.number,
      ayahNumber: ayahNumber,
      totalAyahs: widget.detail.summary.numberOfAyahs,
    );
    await _markLastRead(ayahNumber, pageNumber: pageNumber);
    _scrollToAyah(ayahNumber);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkOfflineAvailability() async {
    await _audioService.isCurrentAudioAvailableOffline();
  }

  Future<void> _applyPersistedAudioPreferences() async {
    final settings = _settingsService.currentSettings;
    await _audioService.setQari(settings.qariCode, settings.qariName);
    await _audioService.setPlaybackSpeed(settings.playbackSpeed);
    await _checkOfflineAvailability();
  }

  Future<void> _handlePlaybackCompleted() async {
    if (!mounted) {
      return;
    }

    if (_audioService.repeatSurah) {
      await _audioService.playAyah(
        surahNumber: widget.detail.summary.number,
        ayahNumber: 1,
        totalAyahs: widget.detail.summary.numberOfAyahs,
      );
      return;
    }

    if (!_audioService.autoPlay) {
      await _audioService.stop();
      return;
    }

    if (_audioService.currentAyahNumber < widget.detail.summary.numberOfAyahs) {
      final nextAyah = _audioService.currentAyahNumber + 1;
      final pageNumber = await _service.resolvePageForAyah(
        widget.detail.summary.number,
        nextAyah,
      );
      await _playAyah(nextAyah, pageNumber: pageNumber);
      return;
    }

    final surahs = await _service.fetchSurahs();
    final currentIndex = surahs.indexWhere(
      (surah) => surah.number == widget.detail.summary.number,
    );
    if (currentIndex >= 0 && currentIndex < surahs.length - 1) {
      final nextSurah = surahs[currentIndex + 1];
      final nextDetail = await _service.fetchSurahDetail(nextSurah.number);
      if (!mounted) {
        return;
      }
      await _audioService.playAyah(
        surahNumber: nextSurah.number,
        ayahNumber: 1,
        totalAyahs: nextSurah.numberOfAyahs,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SurahDetailScreen(detail: nextDetail),
          ),
        );
      }
      return;
    }

    await _audioService.stop();
  }

  Future<void> _showAsbabunNuzul(int ayahNumber) async {
    final text = await _service.fetchAsbabunNuzul(
      widget.detail.summary.number,
      ayahNumber,
    );
    if (!mounted) {
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asbabun Nuzul Ayat $ayahNumber',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    text ?? 'Asbabun Nuzul belum tersedia untuk ayat ini.',
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleMushafMode() {
    setState(() {
      _showMushafMode = !_showMushafMode;
      if (_showMushafMode) {
        _mushafPageController.jumpToPage((_mushafPage - 1).clamp(0, 603));
      }
    });
  }

  void _scrollToAyah(int ayahNumber) {
    final index = ayahNumber - 1;
    if (index < 0 || index >= _ayahKeys.length) {
      return;
    }

    final targetContext = _ayahKeys[index].currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
      return;
    }

    _scrollController.animateTo(
      index * 140.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _preloadAdjacentPages(int pageNumber) async {
    if (pageNumber > 1) {
      unawaited(_loadMushafPage(pageNumber - 1, animate: false));
    }
    if (pageNumber < 604) {
      unawaited(_loadMushafPage(pageNumber + 1, animate: false));
    }
  }

  Future<QuranPage> _loadMushafPage(
    int pageNumber, {
    bool animate = true,
  }) async {
    if (_mushafPageCache.containsKey(pageNumber)) {
      final cached = _mushafPageCache[pageNumber]!;
      if (!mounted) {
        return cached;
      }
      setState(() => _mushafPage = pageNumber);
      if (animate) {
        _mushafPageController.jumpToPage(pageNumber - 1);
      }
      return cached;
    }

    setState(() => _isLoadingPage = true);
    final page = await _service.fetchPage(pageNumber);
    _mushafPageCache[pageNumber] = page;
    if (!mounted) {
      return page;
    }
    setState(() {
      _isLoadingPage = false;
      _mushafPage = pageNumber;
    });
    if (animate) {
      _mushafPageController.jumpToPage(pageNumber - 1);
    }
    return page;
  }

  Future<void> _jumpToPage(int pageNumber) async {
    if (pageNumber < 1 || pageNumber > 604) {
      return;
    }
    final page = await _loadMushafPage(pageNumber);
    if (!mounted) {
      return;
    }
    _mushafPageController.animateToPage(
      pageNumber - 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
    if (page.ayahs.isNotEmpty) {
      await _markLastRead(
        page.ayahs.first.numberInSurah,
        pageNumber: pageNumber,
      );
    }
  }

  Future<void> _showPagePicker() async {
    final controller = TextEditingController(text: _mushafPage.toString());
    final selectedPage = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pilih Halaman Mushaf'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Nomor halaman (1-604)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null && value >= 1 && value <= 604) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Buka'),
            ),
          ],
        );
      },
    );

    if (selectedPage != null && selectedPage != _mushafPage) {
      await _jumpToPage(selectedPage);
    }
  }

  Future<void> _showJuzPicker() async {
    final selectedJuz = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pilih Juz'),
          content: SizedBox(
            width: 280,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: 30,
              itemBuilder: (context, index) {
                final juzNumber = index + 1;
                return ListTile(
                  title: Text('Juz $juzNumber'),
                  onTap: () => Navigator.pop(context, juzNumber),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );

    if (selectedJuz != null) {
      final pageNumber = await _service.resolvePageForJuz(selectedJuz);
      await _jumpToPage(pageNumber);
    }
  }

  Future<void> _showSurahPicker() async {
    final surahs = _surahs.isEmpty ? await _service.fetchSurahs() : _surahs;
    if (surahs.isNotEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _surahs
          ..clear()
          ..addAll(surahs);
        _surahNamesByNumber
          ..clear()
          ..addEntries(
            surahs.map((surah) => MapEntry(surah.number, surah.englishName)),
          );
      });
    }
    if (!mounted) {
      return;
    }
    final selectedSurah = await showDialog<QuranSurahSummary>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pilih Surah'),
          content: SizedBox(
            width: 320,
            height: 420,
            child: ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                final surah = surahs[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(surah.number.toString())),
                  title: Text(surah.englishName),
                  subtitle: Text(surah.name),
                  onTap: () => Navigator.pop(context, surah),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );

    if (selectedSurah != null) {
      final detail = await _service.fetchSurahDetail(selectedSurah.number);
      final pageNumber = await _service.resolvePageForAyah(
        selectedSurah.number,
        1,
      );
      if (!mounted) {
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SurahDetailScreen(
            detail: detail,
            initialAyahNumber: 1,
            initialPageNumber: pageNumber,
          ),
        ),
      );
    }
  }

  Widget _buildMushafView(BuildContext context, AppSettings settings) {
    final totalPages = 604;
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: _showPagePicker,
                      child: Text('Hal. $_mushafPage'),
                    ),
                    FilledButton.tonal(
                      onPressed: _showJuzPicker,
                      child: const Text('Pilih Juz'),
                    ),
                    FilledButton.tonal(
                      onPressed: _showSurahPicker,
                      child: const Text('Pilih Surah'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _mushafPage > 1
                    ? () async {
                        await _jumpToPage(_mushafPage - 1);
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: _mushafPage < totalPages
                    ? () async {
                        await _jumpToPage(_mushafPage + 1);
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Halaman $_mushafPage / $totalPages',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 140,
                child: Slider(
                  value: _mushafZoom.clamp(0.9, 1.8),
                  min: 0.9,
                  max: 1.8,
                  divisions: 9,
                  label: '${_mushafZoom.toStringAsFixed(1)}x',
                  onChanged: (value) => setState(() => _mushafZoom = value),
                ),
              ),
              Text('${_mushafZoom.toStringAsFixed(1)}x'),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDarkMode
                        ? const [Color(0xFF1B1713), Color(0xFF2D241E)]
                        : const [Color(0xFFF8EFE4), Color(0xFFF2E2CB)],
                  ),
                ),
              ),
              PageView.builder(
                controller: _mushafPageController,
                itemCount: totalPages,
                physics: const PageScrollPhysics(),
                onPageChanged: (page) async {
                  final pageNumber = page + 1;
                  if (!mounted) {
                    return;
                  }
                  setState(() => _mushafPage = pageNumber);
                  unawaited(_preloadAdjacentPages(pageNumber));
                  final pageData = await _loadMushafPage(
                    pageNumber,
                    animate: false,
                  );
                  if (pageData.ayahs.isNotEmpty) {
                    await _markLastRead(
                      pageData.ayahs.first.numberInSurah,
                      pageNumber: pageNumber,
                    );
                  }
                },
                itemBuilder: (context, pageIndex) {
                  final pageNumber = pageIndex + 1;
                  final pageData = _mushafPageCache[pageNumber];
                  if (pageData == null) {
                    return FutureBuilder<QuranPage>(
                      future: _loadMushafPage(pageNumber, animate: false),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _buildMushafLoadingPlaceholder(context);
                        }
                        final loadedPage = snapshot.data;
                        if (loadedPage == null) {
                          return _buildMushafLoadingPlaceholder(context);
                        }
                        return _buildMushafPageCard(context, settings, loadedPage);
                      },
                    );
                  }
                  return _buildMushafPageCard(context, settings, pageData);
                },
              ),
              if (_isLoadingPage)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Menyiapkan halaman...'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMushafLoadingPlaceholder(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D241E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
            Text(
              'Memuat halaman mushaf',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMushafPageCard(
    BuildContext context,
    AppSettings settings,
    QuranPage page,
  ) {
    final ayahs = page.ayahs;
    final firstAyah = ayahs.isNotEmpty ? ayahs.first : null;
    final firstSurahName = firstAyah != null
        ? (_surahNamesByNumber[firstAyah.surahNumber] ??
              widget.detail.summary.englishName)
        : widget.detail.summary.englishName;

    return MushafPageViewer(
      page: page,
      currentAyah: _currentAyah,
      bookmarkedAyahs: _bookmarkedAyahs,
      onPreviousPage: _mushafPage > 1
          ? () async {
              await _jumpToPage(_mushafPage - 1);
            }
          : null,
      onNextPage: _mushafPage < 604
          ? () async {
              await _jumpToPage(_mushafPage + 1);
            }
          : null,
      onAyahTapped: (ayahNumber) async {
        await _playAyah(ayahNumber, pageNumber: _mushafPage);
      },
      onAyahBookmarkToggled: (ayahNumber) async {
        await _toggleAyahBookmark(ayahNumber);
      },
      zoomLevel: _mushafZoom,
      showTranslation: false,
      onTranslationToggle: () {
        setState(() {});
      },
      surahName: firstSurahName,
      surahNumber: firstAyah?.surahNumber ?? widget.detail.summary.number,
      pageNumber: page.number,
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.detail.summary;
    final settings = _settingsService.currentSettings;
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode =
        settings.themeMode == ThemeMode.dark ||
        (settings.themeMode == ThemeMode.system &&
            brightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: Text(summary.englishName),
        actions: [
          IconButton(
            icon: Icon(
              _isSurahBookmarked ? Icons.bookmark : Icons.bookmark_border,
            ),
            onPressed: _toggleSurahBookmark,
            tooltip: 'Bookmark surah',
          ),
          IconButton(
            icon: Icon(
              _showMushafMode ? Icons.view_list : Icons.chrome_reader_mode,
            ),
            onPressed: _toggleMushafMode,
            tooltip: 'Mode Mushaf',
          ),
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: _toggleNightMode,
            tooltip: 'Mode malam',
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TafsirScreen(
                    surahNumber: summary.number,
                    surahName: summary.englishName,
                  ),
                ),
              );
            },
            tooltip: 'Tafsir',
          ),
        ],
      ),
      body: _showMushafMode
          ? _buildMushafView(context, settings)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.englishName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Arti: ${summary.englishNameTranslation}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jumlah ayat: ${summary.numberOfAyahs}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Makkiyah/Madaniyah: ${summary.revelationType}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TafsirScreen(
                                    surahNumber: summary.number,
                                    surahName: summary.englishName,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.menu_book_outlined),
                            label: const Text('Lihat Tafsir'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _togglePageBookmark,
                            icon: Icon(
                              _isPageBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                            ),
                            label: const Text('Bookmark Halaman'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _toggleJuzBookmark,
                            icon: Icon(
                              _isJuzBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                            ),
                            label: const Text('Bookmark Juz'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Qari: ${_audioService.qariName}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            onPressed: _audioService.togglePlayPause,
                            icon: Icon(
                              _audioService.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                          ),
                          IconButton(
                            onPressed: _audioService.stop,
                            icon: const Icon(Icons.stop),
                          ),
                          IconButton(
                            onPressed: () => _audioService.previousAyah(
                              totalAyahs: widget.detail.summary.numberOfAyahs,
                            ),
                            icon: const Icon(Icons.skip_previous),
                          ),
                          IconButton(
                            onPressed: () => _audioService.nextAyah(
                              totalAyahs: widget.detail.summary.numberOfAyahs,
                            ),
                            icon: const Icon(Icons.skip_next),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_audioService.isLoading)
                        Row(
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                            SizedBox(width: 12),
                            Text('Memuat audio...'),
                          ],
                        ),
                      if (!_audioService.isLoading) ...[
                        Slider(
                          value: _audioService.position.inMilliseconds
                              .toDouble()
                              .clamp(
                                0,
                                (_audioService.duration?.inMilliseconds.toDouble() ?? 1),
                              ),
                          max: (_audioService.duration?.inMilliseconds.toDouble() ?? 1),
                          onChanged: (value) async {
                            await _audioService.seekTo(
                              Duration(milliseconds: value.toInt()),
                            );
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_audioService.position.toString().split('.').first),
                            Text(
                              (_audioService.duration ?? Duration.zero)
                                  .toString()
                                  .split('.')
                                  .first,
                            ),
                          ],
                        ),
                      ],
                      if (_audioErrorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Audio gagal: $_audioErrorMessage',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Auto play'),
                            selected: _audioService.autoPlay,
                            onSelected: (value) async =>
                                _audioService.setAutoPlay(value),
                          ),
                          ChoiceChip(
                            label: const Text('Repeat ayat'),
                            selected: _audioService.repeatAyah,
                            onSelected: (value) async =>
                                _audioService.setRepeatAyah(value),
                          ),
                          ChoiceChip(
                            label: const Text('Repeat surah'),
                            selected: _audioService.repeatSurah,
                            onSelected: (value) async =>
                                _audioService.setRepeatSurah(value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final speed in <double>[0.75, 1.0, 1.25, 1.5, 2.0])
                            ChoiceChip(
                              label: Text(
                                '${speed.toStringAsFixed(2).replaceAll('.00', '')}x',
                              ),
                              selected:
                                  (_audioService.playbackSpeed - speed).abs() < 0.001,
                              onSelected: (_) async =>
                                  _audioService.setPlaybackSpeed(speed),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _audioService.qariCode,
                              decoration: const InputDecoration(
                                labelText: 'Pilih Qari',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'abdullah_basfar',
                                  child: Text('Abdullah Basfar'),
                                ),
                                DropdownMenuItem(
                                  value: 'mishary_alafasy',
                                  child: Text('Mishary Alafasy'),
                                ),
                                DropdownMenuItem(
                                  value: 'sahl_yassin',
                                  child: Text('Sahl Yassin'),
                                ),
                              ],
                              onChanged: (value) async {
                                if (value != null) {
                                  final name = value == 'abdullah_basfar'
                                      ? 'Abdullah Basfar'
                                      : value == 'mishary_alafasy'
                                      ? 'Mishary Alafasy'
                                      : 'Sahl Yassin';
                                  await _audioService.setQari(value, name);
                                  await _settingsService.updateQari(value, name);
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: widget.detail.arabicAyahs.isEmpty
                      ? const Center(
                          child: Text(
                            'Data teks surah belum tersedia untuk surah ini.',
                          ),
                        )
                      : Scrollbar(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: widget.detail.arabicAyahs.length,
                            itemBuilder: (context, index) {
                              final arab = widget.detail.arabicAyahs[index];
                              final translit =
                                  index < widget.detail.transliterationAyahs.length
                                  ? widget.detail.transliterationAyahs[index]
                                  : QuranAyah(
                                      surahNumber: summary.number,
                                      number: index + 1,
                                      numberInSurah: index + 1,
                                      juz: 0,
                                      text: '',
                                    );
                              final translation =
                                  index < widget.detail.translationAyahs.length
                                  ? widget.detail.translationAyahs[index]
                                  : QuranAyah(
                                      surahNumber: summary.number,
                                      number: index + 1,
                                      numberInSurah: index + 1,
                                      juz: 0,
                                      text: '',
                                    );
                              final isAyahBookmarked = _bookmarkedAyahs.contains(
                                '${summary.number}:${arab.numberInSurah}',
                              );
                              final isCurrentPlayingAyah =
                                  _audioService.currentSurahNumber ==
                                      widget.detail.summary.number &&
                                  _audioService.currentAyahNumber ==
                                      arab.numberInSurah;
                              return Container(
                                key: _ayahKeys[index],
                                child: Card(
                                  color: isCurrentPlayingAyah
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : null,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: InkWell(
                                    onTap: () async {
                                      await _markLastRead(arab.numberInSurah);
                                      await _playAyah(arab.numberInSurah);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Ayat ${arab.numberInSurah}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                              TextButton.icon(
                                                onPressed: () => _showAsbabunNuzul(
                                                  arab.numberInSurah,
                                                ),
                                                icon: const Icon(
                                                  Icons.lightbulb_outline,
                                                ),
                                                label: const Text('Asbabun Nuzul'),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  isAyahBookmarked
                                                      ? Icons.bookmark
                                                      : Icons.bookmark_border,
                                                ),
                                                onPressed: () => _toggleAyahBookmark(
                                                  arab.numberInSurah,
                                                ),
                                                tooltip: 'Bookmark ayat',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            arab.text,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: settings.fontSizeArabic,
                                              height: 1.6,
                                              fontFamily: settings.arabicFontFamily,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            translit.text,
                                            style: TextStyle(
                                              fontSize: settings.fontSizeLatin,
                                              color: Colors.black87,
                                              fontFamily: settings.appFontFamily,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            translation.text,
                                            style: TextStyle(
                                              fontSize: settings.fontSizeTranslation,
                                              color: Colors.black54,
                                              fontFamily: settings.appFontFamily,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
