// ignore_for_file: deprecated_member_use, unnecessary_brace_in_string_interps

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../widgets/modern_menu_card.dart';
import 'doa_screen.dart';
import 'quran_screen.dart';
import 'settings_screen.dart';
import 'sholat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F7A4D), Color(0xFF2F8A5B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _IslamicOrnamentPainter(color: Colors.white.withOpacity(0.12)),
                        ),
                      ),
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFF72B88A), Color(0xFF1F7A4D)],
                            center: Alignment(-0.2, -0.2),
                            radius: 0.85,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFF3E1A5), width: 2.5),
                        ),
                        child: Center(
                          child: Container(
                            width: 156,
                            height: 156,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.14),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Image.asset(
                                'assets/images/babas_logo.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    "Cahaya Al-Qur'an Dalam Genggaman",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Babas App hadir sebagai sahabat digital dalam membaca dan memahami Al-Qur\'an.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ModernMenuCard(
              icon: Icons.menu_book_rounded,
              title: '📖 Al-Qur\'an',
              subtitle: 'Mushaf, bookmark, last read, audio',
              color: const Color(0xFF1F7A4D),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranScreen())),
            ),
            ModernMenuCard(
              icon: Icons.access_time_rounded,
              title: '🕌 Jadwal Sholat',
              subtitle: 'Jadwal harian yang praktis',
              color: const Color(0xFFE7B84B),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SholatScreen())),
            ),
            ModernMenuCard(
              icon: Icons.self_improvement_rounded,
              title: '🤲 Doa & Dzikir',
              subtitle: 'Doa dan dzikir harian',
              color: const Color(0xFF1F7A4D),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoaScreen())),
            ),
            ModernMenuCard(
              icon: Icons.auto_stories_rounded,
              title: '📚 Cara Cepat Baca Al-Qur\'an Versi Babas',
              subtitle: 'Panduan praktis membaca Al-Qur\'an',
              color: const Color(0xFFE7B84B),
              onTap: () {},
            ),
            ModernMenuCard(
              icon: Icons.calendar_month_rounded,
              title: '📅 Kalender Islami',
              subtitle: 'Hijriyah dan agenda penting',
              color: const Color(0xFF1F7A4D),
              onTap: () {},
            ),
            ModernMenuCard(
              icon: Icons.cloud_rounded,
              title: '🌤 Cuaca',
              subtitle: 'Prakiraan cuaca',
              color: const Color(0xFF1F7A4D),
              onTap: () {},
            ),
            ModernMenuCard(
              icon: Icons.book_rounded,
              title: '📚 Kitab Maulid',
              subtitle: 'Konten maulid dan sejarah',
              color: const Color(0xFFE7B84B),
              onTap: () {},
            ),
            ModernMenuCard(
              icon: Icons.star_rounded,
              title: '⭐ Premium',
              subtitle: 'Akses fitur eksklusif',
              color: const Color(0xFFE7B84B),
              onTap: () {},
            ),
            ModernMenuCard(
              icon: Icons.settings_rounded,
              title: '⚙ Pengaturan',
              subtitle: 'Tema, font, dan preferensi',
              color: const Color(0xFF1F7A4D),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text('Version 1.0.0 • © Babas App', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

class _IslamicOrnamentPainter extends CustomPainter {
  final Color color;

  _IslamicOrnamentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;
    final path = Path();
    const segments = 8;

    for (var i = 0; i < segments; i++) {
      final angle = (math.pi * 2 / segments) * i;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);

    final innerPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final innerRadius = radius * 0.72;
    final innerPath = Path();

    for (var i = 0; i < segments; i++) {
      final angle = (math.pi * 2 / segments) * i + math.pi / segments;
      final x = center.dx + innerRadius * math.cos(angle);
      final y = center.dy + innerRadius * math.sin(angle);
      if (i == 0) {
        innerPath.moveTo(x, y);
      } else {
        innerPath.lineTo(x, y);
      }
    }

    innerPath.close();
    canvas.drawPath(innerPath, innerPaint);

    final dotPaint = Paint()..color = color.withOpacity(0.2);
    for (var i = 0; i < segments; i++) {
      final angle = (math.pi * 2 / segments) * i;
      final x = center.dx + (radius * 0.56) * math.cos(angle);
      final y = center.dy + (radius * 0.56) * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
