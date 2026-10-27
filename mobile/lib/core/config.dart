import 'package:flutter/foundation.dart';

/// Alamat backend. Override saat build: --dart-define=API_URL=https://api.contoh.com
/// Emulator Android memakai 10.0.2.2 untuk mengakses localhost mesin host.
String get apiUrl {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
}

/// Nama merek yang tampil di app. Ganti sesuai brand kafe.
const appName = 'Kopi App';
