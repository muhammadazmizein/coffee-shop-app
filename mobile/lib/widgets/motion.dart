import 'package:flutter/widgets.dart';

/// true bila pengguna meminta "kurangi animasi" (pengaturan aksesibilitas HP). Semua animasi di app
/// melewati gerakan dan menampilkan hasil akhir langsung bila ini true.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Durasi yang menjadi nol saat "kurangi animasi" aktif.
Duration motionDuration(BuildContext context, Duration d) => reduceMotion(context) ? Duration.zero : d;
