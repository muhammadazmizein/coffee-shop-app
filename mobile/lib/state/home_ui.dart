import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Penghitung "minta fokus kolom cari": beranda menaikkan angkanya, tab Menu memfokuskan kolom cari.
class MenuSearchFocus extends Notifier<int> {
  @override
  int build() => 0;
  void request() => state++;
}

final menuSearchFocusProvider = NotifierProvider<MenuSearchFocus, int>(MenuSearchFocus.new);
