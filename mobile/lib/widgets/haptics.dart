import 'package:flutter/services.dart';

/// Getaran ringan untuk umpan balik aksi. Gagal diam-diam di perangkat/emulator yang tidak mendukung.
void tapHaptic() => HapticFeedback.selectionClick();
void successHaptic() => HapticFeedback.mediumImpact();
