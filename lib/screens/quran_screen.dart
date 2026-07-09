// ignore_for_file: use_build_context_synchronously, unnecessary_null_comparison, deprecated_member_use, unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';

import '../models/quran_model.dart';
import '../services/quran_service.dart';
import 'surah_detail_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> with SingleTickerProviderStateMixin {
  final QuranService _service = QuranService();
  late Future<List<QuranSurahSummary>> _surahsFuture;
  late Future<List<QuranJuz>> _juzsFuture;
  bool _juzsLoaded = false;
  final TextEditingController _customTargetController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;
  String _searchQuery = '';
  Set<int> _bookmarkedSurahs = <int>{};
  Set<int> _bookmarkedJuzs = <int>{};
  Map<String, dynamic>? _lastRead;
  Map<String, dynamic> _khatamProgress = <String, dynamic>{
    'days': 30,
    'completedAyahs': 0,
    'percentage': 0.0,
    'dailyProgress': 0,
    'dailyTarget': 208,
    'remainingAyahs': 6236,
  };
  int _selectedTargetDays = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _surahsFuture = _service.fetchSurahs();
    _juzsFuture = Future.value(const <QuranJuz>[]);
    _tabController.addListener(_handleTabChanged);
    _refreshPersistedState();
  }

  @override
  void dispose() {
    _service.dispose();
    _customTargetController.dispose();
    _searchController.dispose();
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.index == 1 && !_juzsLoaded) {
      _loadJuzs();
    }
  }

  Future<void> _loadJuzs() async {
    if (_juzsLoaded) {
      return;
    }
    setState(() {
      _juzsLoaded = true;
      _juzsFuture = _service.fetchJuzs();
    });
  }

  Future<void> _refreshPersistedState() async {
    final bookmarkedSurahs = await _service.getBookmarkedSurahs();
    final bookmarkedJuzs = await _service.getBookmarkedJuzs();
    final lastRead = await _service.getLastRead();
    final target = await _service.getTargetKhatam();
    final progress = await _service.getKhatamProgress();
    if (!mounted) {
      return;
    }
    setState(() {
      _bookmarkedSurahs = bookmarkedSurahs;
      _bookmarkedJuzs = bookmarkedJuzs;
      _lastRead = lastRead;
      _khatamProgress = progress;
      _selectedTargetDays = (target['days'] as int?) ?? 30;
    });
  }

  Future<void> _toggleSurahBookmark(int surahNumber) async {
    await _service.toggleSurahBookmark(surahNumber);
    await _refreshPersistedState();
  }

  Future<void> _toggleJuzBookmark(int juzNumber) async {
    await _service.toggleJuzBookmark(juzNumber);
    await _refreshPersistedState();
  }

  Future<void> _setTargetDays(int days) async {
    await _service.saveTargetKhatam(days: days, startedAt: DateTime.now());
    await _refreshPersistedState();
  }

  Future<void> _openSurahDetail(int surahNumber, {int? initialAyahNumber, int? initialPageNumber}) async {
    // Show loading dialog while fetching detail
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    SurahDetail? detail;
    try {
      detail = await _service.fetchSurahDetail(surahNumber).timeout(const Duration(seconds: 10));
    } catch (error) {
      // Dismiss loading
      if (mounted) Navigator.pop(context);
      // Show retry dialog
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Gagal memuat'),
            content: const Text('Tidak dapat memuat detail surah. Periksa koneksi atau coba lagi.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Coba Lagi')),
            ],
          );
        },
      );

      if (retry == true) {
        return _openSurahDetail(surahNumber, initialAyahNumber: initialAyahNumber, initialPageNumber: initialPageNumber);
      }
      return;
    }

    // Dismiss loading
    if (mounted) Navigator.pop(context);

    if (!mounted || detail == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(
          detail: detail!,
          initialAyahNumber: initialAyahNumber,
          initialPageNumber: initialPageNumber,
        ),
      ),
    );
    await _refreshPersistedState();
  }

  Future<void> _openLastRead() async {
    final surahNumber = _lastRead?['surahNumber'] as int?;
    if (surahNumber == null) {
      return;
    }
    final ayahNumber = _lastRead?['ayahNumber'] as int? ?? 1;
    final pageNumber = _lastRead?['pageNumber'] as int? ?? await _service.resolvePageForAyah(surahNumber, ayahNumber);
    await _openSurahDetail(surahNumber, initialAyahNumber: ayahNumber, initialPageNumber: pageNumber);
  }

  Widget _buildSurahTab(List<QuranSurahSummary> surahs) {
    final filtered = _searchQuery.isEmpty
        ? surahs
        : surahs.where((surah) {
            final query = _searchQuery.toLowerCase();
            return surah.name.toLowerCase().contains(query) ||
                surah.englishName.toLowerCase().contains(query) ||
                surah.englishNameTranslation.toLowerCase().contains(query) ||
                surah.revelationType.toLowerCase().contains(query) ||
                surah.number.toString().contains(query);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Cari surah',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchQuery = ''; _searchController.clear(); })),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Tidak ada surah yang cocok dengan pencarian.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final surah = filtered[index];
                    final isBookmarked = _bookmarkedSurahs.contains(surah.number);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(surah.number.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        title: Text(surah.englishName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${surah.name} • ${surah.numberOfAyahs} ayat'),
                        trailing: IconButton(
                          icon: Icon(isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: isBookmarked ? Colors.amber : null),
                          onPressed: () => _toggleSurahBookmark(surah.number),
                        ),
                        onTap: () => _openSurahDetail(surah.number),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildJuzTab(List<QuranJuz> juzs) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: juzs.length,
      itemBuilder: (context, index) {
        final juz = juzs[index];
        final isBookmarked = _bookmarkedJuzs.contains(juz.number);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(juz.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Mulai di Surah ${juz.startSurahNumber}, ayat ${juz.startAyahNumber}'),
            trailing: IconButton(
              icon: Icon(isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: isBookmarked ? Colors.amber : null),
              onPressed: () => _toggleJuzBookmark(juz.number),
            ),
            onTap: () async {
              final surahs = await _service.fetchSurahs();
              final targetSurah = surahs.firstWhere((s) => s.number == juz.startSurahNumber, orElse: () => surahs.first);
              final initialPageNumber = await _service.resolvePageForAyah(targetSurah.number, juz.startAyahNumber);
              await _openSurahDetail(targetSurah.number, initialAyahNumber: juz.startAyahNumber, initialPageNumber: initialPageNumber);
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_lastRead != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.history_rounded, color: Colors.green),
              title: Text('Lanjutkan ${_lastRead!['surahName']}'),
              subtitle: Text('Ayat ${_lastRead!['ayahNumber']}'),
              trailing: FilledButton.tonal(onPressed: _openLastRead, child: const Text('Buka')),
            ),
          )
        else
          const Card(child: ListTile(title: Text('Belum ada riwayat baca'))),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.track_changes_rounded, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Target Khatam ${_selectedTargetDays} hari', style: const TextStyle(fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: ((_khatamProgress['percentage'] as double?) ?? 0.0) / 100),
                const SizedBox(height: 8),
                Text('${_khatamProgress['completedAyahs']} ayat selesai • ${((_khatamProgress['percentage'] as double?) ?? 0.0).toStringAsFixed(1)}%'),
                Text('Hari ini: ${_khatamProgress['dailyProgress']} ayat • Target harian: ${_khatamProgress['dailyTarget']}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [7, 15, 30].map((days) {
                    final selected = _selectedTargetDays == days;
                    return ChoiceChip(label: Text('$days hari'), selected: selected, onSelected: (_) => _setTargetDays(days));
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customTargetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Custom hari', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final value = int.tryParse(_customTargetController.text);
                        if (value != null && value > 0) {
                          _setTargetDays(value);
                        }
                      },
                      child: const Text('Simpan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Al-Qur\'an'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_surahsFuture, _juzsFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat data Al-Qur\'an. ${snapshot.error}'));
          }

          final surahs = (snapshot.data?[0] as List<QuranSurahSummary>?) ?? <QuranSurahSummary>[];
          final juzs = (snapshot.data?[1] as List<QuranJuz>?) ?? <QuranJuz>[];

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Baca, pahami, dan dengarkan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    const Text('Mushaf Digital Babas', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('Bookmark • Last Read • Target Khatam', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12))),
                        Icon(Icons.menu_book_rounded, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
              if (_lastRead != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_fill_rounded, color: Colors.green),
                      title: Text('Lanjutkan Membaca ${_lastRead!['surahName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('Ayat ${_lastRead!['ayahNumber']} • Halaman ${_lastRead!['pageNumber'] ?? 1}'),
                      trailing: FilledButton.tonal(onPressed: _openLastRead, child: const Text('Buka')),
                      onTap: _openLastRead,
                    ),
                  ),
                ),
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(text: 'Surah'),
                  Tab(text: 'Juz'),
                  Tab(text: 'Riwayat'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSurahTab(surahs),
                    _buildJuzTab(juzs),
                    _buildHistoryTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
