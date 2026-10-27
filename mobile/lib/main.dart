import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  runApp(const ProviderScope(child: KopiApp()));
}

class KopiApp extends ConsumerWidget {
  const KopiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Kopi App',
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      // Font HP yang diperbesar sangat jauh merusak tata letak; batasi sampai 1,15x.
      builder: (context, child) => MediaQuery.withClampedTextScaling(minScaleFactor: 0.9, maxScaleFactor: 1.15, child: child!),
    );
  }
}
