import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import 'file_system.dart';

enum AudioPlaybackStatus { idle, loading, playing, paused, completed, error }

class QuranAudioService {
  QuranAudioService._() {
    _initAudioSession();
    _attachPlayerListeners();
  }

  static final QuranAudioService _instance = QuranAudioService._();
  factory QuranAudioService() => _instance;

  AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  final StreamController<AudioPlaybackStatus> _playbackStatusController =
      StreamController.broadcast();
  final StreamController<Duration> _positionController =
      StreamController.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController.broadcast();
  final StreamController<int> _activeAyahController =
      StreamController.broadcast();

  Stream<AudioPlaybackStatus> get playbackStatusStream =>
      _playbackStatusController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<int> get activeAyahStream => _activeAyahController.stream;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Duration position = Duration.zero;
  Duration? duration;

  String? _lastError;
  String? get lastError => _lastError;

  void Function(String)? onError;

  int _currentSurahNumber = 1;
  int get currentSurahNumber => _currentSurahNumber;

  int _currentAyahNumber = 1;
  int get currentAyahNumber => _currentAyahNumber;

  int _activeTotalAyahs = 1;

  String _qariCode = 'abdullah_basfar';
  String _qariName = 'Abdullah Basfar';
  String get qariCode => _qariCode;
  String get qariName => _qariName;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  bool _autoPlay = true;
  bool get autoPlay => _autoPlay;

  bool _repeatAyah = false;
  bool get repeatAyah => _repeatAyah;

  bool _repeatSurah = false;
  bool get repeatSurah => _repeatSurah;

  bool _shuffle = false;
  bool get shuffle => _shuffle;

  void Function()? onPlaybackCompleted;
  void Function(Duration)? onPositionChanged;
  void Function(Duration?)? onDurationChanged;
  void Function()? onPlaybackStateChanged;

  Future<void> setQari(String code, String name) async {
    final shouldReload = _qariCode != code || _qariName != name;
    _qariCode = code;
    _qariName = name;
    if (shouldReload && (_isPlaying || _isLoading) && _currentSurahNumber > 0) {
      await playAyah(
        surahNumber: _currentSurahNumber,
        ayahNumber: _currentAyahNumber,
        totalAyahs: _activeTotalAyahs,
      );
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _player.setSpeed(speed);
  }

  Future<void> setAutoPlay(bool value) async {
    _autoPlay = value;
  }

  Future<void> setRepeatAyah(bool value) async {
    _repeatAyah = value;
    await _applyLoopMode();
  }

  Future<void> setRepeatSurah(bool value) async {
    _repeatSurah = value;
    await _applyLoopMode();
  }

  Future<void> setShuffle(bool value) async {
    _shuffle = value;
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (_) {}
  }

  void _attachPlayerListeners() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.playing) {
        _isPlaying = true;
        _isLoading = false;
        _emitPlaybackStatus(AudioPlaybackStatus.playing);
      } else if (state.processingState == ProcessingState.loading) {
        _isLoading = true;
        _emitPlaybackStatus(AudioPlaybackStatus.loading);
      } else if (!state.playing &&
          state.processingState == ProcessingState.ready) {
        _isPlaying = false;
        _emitPlaybackStatus(AudioPlaybackStatus.paused);
      } else if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _emitPlaybackStatus(AudioPlaybackStatus.completed);
        onPlaybackCompleted?.call();
      } else if (state.processingState == ProcessingState.idle) {
        _isPlaying = false;
        _emitPlaybackStatus(AudioPlaybackStatus.idle);
      }
    });

    _positionSubscription = _player.positionStream.listen((newPosition) {
      position = newPosition;
      _positionController.add(newPosition);
      onPositionChanged?.call(newPosition);
    });

    _durationSubscription = _player.durationStream.listen((newDuration) {
      duration = newDuration;
      _durationController.add(newDuration);
      onDurationChanged?.call(newDuration);
    });
  }

  Future<void> _applyLoopMode() async {
    if (_repeatAyah) {
      await _player.setLoopMode(LoopMode.one);
    } else {
      await _player.setLoopMode(LoopMode.off);
    }
  }

  void _emitPlaybackStatus(AudioPlaybackStatus status) {
    _playbackStatusController.add(status);
    onPlaybackStateChanged?.call();
  }

  void _emitActiveAyah() {
    _activeAyahController.add(_currentAyahNumber);
  }

  Future<void> playAyah({
    required int surahNumber,
    required int ayahNumber,
    required int totalAyahs,
  }) async {
    if (_currentSurahNumber == surahNumber &&
        _currentAyahNumber == ayahNumber &&
        (_isPlaying || _isLoading)) {
      _emitActiveAyah();
      return;
    }

    _activeTotalAyahs = totalAyahs;
    _currentSurahNumber = surahNumber;
    _currentAyahNumber = ayahNumber;
    _lastError = null;
    _isLoading = true;
    _emitPlaybackStatus(AudioPlaybackStatus.loading);
    _emitActiveAyah();

    final localPath = await _buildLocalAudioPath(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
    );
    final hasLocalFile = localPath.isNotEmpty && await fileExists(localPath);

    try {
      await _player.stop();
      if (hasLocalFile) {
        await _player.setAudioSource(AudioSource.uri(Uri.file(localPath)));
      } else {
        final audioUrl = await resolveAudioUrl(
          surahNumber: surahNumber,
          ayahNumber: ayahNumber,
        );
        if (audioUrl == null || audioUrl.isEmpty) {
          throw Exception('Tidak dapat menemukan URL audio untuk ayat ini.');
        }
        await _player.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));
      }
      await _player.setSpeed(_playbackSpeed);
      await _applyLoopMode();
      await _player.play();
      _isPlaying = true;
      _isLoading = false;
      _emitPlaybackStatus(AudioPlaybackStatus.playing);
      _emitActiveAyah();
    } catch (error) {
      _lastError = error.toString();
      _isPlaying = false;
      _isLoading = false;
      position = Duration.zero;
      _emitPlaybackStatus(AudioPlaybackStatus.error);
      onError?.call(_lastError ?? 'Terjadi kesalahan pemutaran audio.');
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    _emitPlaybackStatus(AudioPlaybackStatus.paused);
  }

  Future<void> resume() async {
    final currentState = _player.processingState;
    if (currentState == ProcessingState.idle ||
        currentState == ProcessingState.completed) {
      await playAyah(
        surahNumber: _currentSurahNumber,
        ayahNumber: _currentAyahNumber,
        totalAyahs: _activeTotalAyahs,
      );
      return;
    }

    if (!_isPlaying) {
      await _player.play();
      _isPlaying = true;
      _emitPlaybackStatus(AudioPlaybackStatus.playing);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    _isLoading = false;
    position = Duration.zero;
    _emitPlaybackStatus(AudioPlaybackStatus.idle);
  }

  Future<void> seekTo(Duration newPosition) async {
    await _player.seek(newPosition);
    position = newPosition;
    _positionController.add(newPosition);
  }

  Future<void> nextAyah({required int totalAyahs}) async {
    if (_currentAyahNumber < totalAyahs) {
      await playAyah(
        surahNumber: _currentSurahNumber,
        ayahNumber: _currentAyahNumber + 1,
        totalAyahs: totalAyahs,
      );
    }
  }

  Future<void> previousAyah({required int totalAyahs}) async {
    if (_currentAyahNumber > 1) {
      await playAyah(
        surahNumber: _currentSurahNumber,
        ayahNumber: _currentAyahNumber - 1,
        totalAyahs: totalAyahs,
      );
    }
  }

  Future<void> downloadCurrentAudio() async {
    final localPath = await _buildLocalAudioPath(
      surahNumber: _currentSurahNumber,
      ayahNumber: _currentAyahNumber,
    );
    final remoteUrl = await resolveAudioUrl(
      surahNumber: _currentSurahNumber,
      ayahNumber: _currentAyahNumber,
    );
    if (remoteUrl == null || remoteUrl.isEmpty || localPath.isEmpty) {
      return;
    }
    try {
      final response = await http.get(Uri.parse(remoteUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        await writeFile(localPath, response.bodyBytes);
      }
    } catch (_) {}
  }

  Future<void> deleteCurrentAudio() async {
    final localPath = await _buildLocalAudioPath(
      surahNumber: _currentSurahNumber,
      ayahNumber: _currentAyahNumber,
    );
    if (localPath.isEmpty) {
      return;
    }
    await deleteFile(localPath);
  }

  Future<bool> isCurrentAudioAvailableOffline() async {
    final localPath = await _buildLocalAudioPath(
      surahNumber: _currentSurahNumber,
      ayahNumber: _currentAyahNumber,
    );
    if (localPath.isEmpty) {
      return false;
    }
    return await fileExists(localPath);
  }

  Future<void> dispose() async {
    await _player.stop();
    await _player.dispose();
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    _player = AudioPlayer();
    _attachPlayerListeners();
  }

  Future<String> _buildLocalAudioPath({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    final dirPath = await getApplicationDocumentsDirectoryPath();
    if (dirPath.isEmpty) {
      return '';
    }
    return '$dirPath/quran_${_qariCode}_${surahNumber.toString().padLeft(3, '0')}_${ayahNumber.toString().padLeft(3, '0')}.mp3';
  }

  Future<String?> resolveAudioUrl({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    final editionCandidates = _editionCandidatesForQari();
    for (final edition in editionCandidates) {
      try {
        final url =
            'https://api.alquran.cloud/v1/ayah/$surahNumber:$ayahNumber/$edition';
        final response = await http
            .get(Uri.parse(url), headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final data = decoded['data'];
            final audioUrl = data is Map<String, dynamic>
                ? data['audio']?.toString()
                : null;
            if (audioUrl != null && audioUrl.isNotEmpty) {
              return audioUrl;
            }
          }
        }
      } catch (_) {}
    }

    try {
      final verseNumber = await _readVerseNumberFromAsset(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
      );
      if (verseNumber > 0) {
        final edition = editionCandidates.firstWhere(
          (candidate) => candidate.isNotEmpty,
          orElse: () => 'ar.alafasy',
        );
        final fallbackCandidates = <String>{
          'https://cdn.islamic.network/quran/audio/128/$edition/$verseNumber.mp3',
          'https://cdn.islamic.network/quran/audio/32/$edition/$verseNumber.mp3',
        }.toList();
        return fallbackCandidates.firstWhere(
          (candidate) => candidate.isNotEmpty,
          orElse: () =>
              'https://cdn.islamic.network/quran/audio/128/$edition/$verseNumber.mp3',
        );
      }
    } catch (_) {}

    return null;
  }

  Future<int> _readVerseNumberFromAsset({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    try {
      final raw = await rootBundle.loadString('assets/data/quran_complete.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return 0;
      }

      final data = decoded['data'];
      if (data is! List) {
        return 0;
      }

      for (final entry in data.whereType<Map<String, dynamic>>()) {
        final number = int.tryParse(entry['number']?.toString() ?? '') ?? 0;
        if (number == surahNumber) {
          final ayahs = entry['ayahs'];
          if (ayahs is List) {
            for (final ayah in ayahs.whereType<Map<String, dynamic>>()) {
              final currentAyahNumber =
                  int.tryParse(ayah['numberInSurah']?.toString() ?? '') ?? 0;
              if (currentAyahNumber == ayahNumber) {
                return int.tryParse(ayah['number']?.toString() ?? '') ?? 0;
              }
            }
          }
          break;
        }
      }
    } catch (_) {
      return 0;
    }
    return 0;
  }

  List<String> _editionCandidatesForQari() {
    switch (_qariCode.toLowerCase()) {
      case 'abdullah_basfar':
      case 'abdullahbasfar':
        return <String>['ar.abdullahbasfar', 'ar.alafasy'];
      case 'mishary_alafasy':
      case 'alafasy':
        return <String>['ar.alafasy', 'ar.abdullahbasfar'];
      case 'sahl_yassin':
      case 'sahl':
      case 'sahlyassine':
        return <String>['ar.sahlyassine', 'ar.alafasy'];
      default:
        return <String>['ar.alafasy', 'ar.abdullahbasfar'];
    }
  }
}
