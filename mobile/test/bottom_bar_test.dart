import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopi_app/core/theme.dart';
import 'package:kopi_app/widgets/bottom_bar.dart';

void main() {
  for (final i in [0, 2, 4]) {
    testWidgets('bar bawah tab $i tampil tanpa overflow', (t) async {
      t.view.physicalSize = const Size(1080, 360);
      t.view.devicePixelRatio = 2.625;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      var tapped = -1;
      await t.pumpWidget(MaterialApp(
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFEAF5F3),
          body: RepaintBoundary(key: key, child: Align(alignment: Alignment.bottomCenter, child: AppBottomBar(index: i, onTap: (v) => tapped = v))),
        ),
      ));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
      await t.tap(find.text('Merch'));
      expect(tapped, 3);

      final dir = Platform.environment['SNAP_DIR'];
      if (dir != null) {
        await t.runAsync(() async {
          final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await b.toImage(pixelRatio: 2.0);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/bar-$i.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
    });
  }
}
