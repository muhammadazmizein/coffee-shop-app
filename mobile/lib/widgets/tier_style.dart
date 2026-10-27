import 'package:flutter/material.dart';

/// Tampilan visual sebuah level. Dipilih dari urutan level (bukan nama), karena nama level bisa diubah admin.
class TierStyle {
  const TierStyle(this.gradient, this.accent);
  final List<Color> gradient;
  final Color accent;
}

const _styles = [
  TierStyle([Color(0xFF14A398), Color(0xFF063B38)], Color(0xFF14A398)), // level dasar
  TierStyle([Color(0xFFA7B8C6), Color(0xFF4F5F6E)], Color(0xFF7C8FA0)), // Silver
  TierStyle([Color(0xFFF3C657), Color(0xFF946405)], Color(0xFFD9A21B)), // Gold
  TierStyle([Color(0xFF7078DB), Color(0xFF1E2354)], Color(0xFF5B63C9)), // Platinum
];

TierStyle tierStyle(int index) => _styles[index % _styles.length];
