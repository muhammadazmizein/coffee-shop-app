import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Transisi "fade-through + geser kecil": halaman baru memudar masuk sambil bergeser sedikit dari kanan,
/// halaman di bawahnya memudar dan bergeser sedikit ke kiri. Tanpa paket tambahan. Hero tetap berfungsi.
CustomTransitionPage<T> fadeThroughPage<T>({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
      final slideIn = Tween<Offset>(begin: const Offset(0.07, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      final fadeIn = CurvedAnimation(parent: animation, curve: const Interval(0.2, 1.0, curve: Curves.easeOut));
      final slideOut = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.04, 0)).animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut));
      final fadeOut = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: secondaryAnimation, curve: const Interval(0.0, 0.55, curve: Curves.easeIn)));
      return FadeTransition(
        opacity: fadeOut,
        child: SlideTransition(
          position: slideOut,
          child: FadeTransition(opacity: fadeIn, child: SlideTransition(position: slideIn, child: child)),
        ),
      );
    },
  );
}

/// Fade sederhana untuk perpindahan besar (splash → welcome → login → beranda).
CustomTransitionPage<T> fadePage<T>({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
      return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
    },
  );
}
