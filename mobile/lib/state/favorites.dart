import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storageKey = 'favorite_products';

/// Serialisasi daftar favorit ke JSON (urut agar hasilnya stabil).
String encodeFavorites(Set<String> ids) => jsonEncode((ids.toList()..sort()));

/// Membaca daftar favorit. Data kosong atau rusak menghasilkan himpunan kosong, bukan error.
Set<String> decodeFavorites(String? raw) {
  if (raw == null || raw.isEmpty) return <String>{};
  try {
    final d = jsonDecode(raw);
    if (d is List) return d.whereType<String>().toSet();
  } catch (_) {}
  return <String>{};
}

/// Penyimpanan favorit di perangkat. Dipisah supaya bisa diganti di test.
class FavoritesStore {
  const FavoritesStore();
  static const _storage = FlutterSecureStorage();

  Future<String?> read() async {
    try {
      return await _storage.read(key: _storageKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String value) async {
    try {
      await _storage.write(key: _storageKey, value: value);
    } catch (_) {}
  }
}

final favoritesStoreProvider = Provider<FavoritesStore>((ref) => const FavoritesStore());

/// Menu favorit pelanggan, disimpan lokal per perangkat (belum disinkronkan ke server).
class Favorites extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _load();
    return <String>{};
  }

  Future<void> _load() async {
    final loaded = decodeFavorites(await ref.read(favoritesStoreProvider).read());
    // Gabungkan: toggle yang terjadi selama pemuatan tidak boleh hilang.
    if (loaded.isNotEmpty) state = {...loaded, ...state};
  }

  bool isFavorite(String id) => state.contains(id);

  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
    ref.read(favoritesStoreProvider).write(encodeFavorites(next));
  }
}

final favoritesProvider = NotifierProvider<Favorites, Set<String>>(Favorites.new);
