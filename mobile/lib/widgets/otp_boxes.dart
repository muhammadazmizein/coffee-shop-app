import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hitung mundur "kirim ulang" dalam format m:ss, mis. 30 -> "0:30".
String formatCountdown(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Teks tombol kirim ulang: berisi hitung mundur selama belum boleh diketuk.
String resendLabel(int secondsLeft) => secondsLeft > 0 ? 'Kirim ulang kode (${formatCountdown(secondsLeft)})' : 'Kirim ulang kode';

/// Kolom OTP 6 kotak. Satu TextField transparan menampung ketikan (termasuk tempel kode dan papan angka),
/// sedangkan kotak-kotak hanya menampilkan isinya. [controller] tetap berisi kode utuh.
class OtpBoxes extends StatefulWidget {
  const OtpBoxes({super.key, required this.controller, this.length = 6, this.enabled = true, this.autofocus = true, this.onChanged});
  final TextEditingController controller;
  final int length;
  final bool enabled, autofocus;
  final ValueChanged<String>? onChanged;

  @override
  State<OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<OtpBoxes> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    _focus.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final active = _focus.hasFocus ? text.length.clamp(0, widget.length - 1) : -1;
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? () => _focus.requestFocus() : null,
      child: Stack(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < widget.length; i++)
            Flexible(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 58,
                constraints: const BoxConstraints(maxWidth: 52),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i < text.length ? const Color(0xFFE5F6F3) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: i == active ? theme.colorScheme.primary : const Color(0xFFCFE3E0), width: i == active ? 2.2 : 1.2),
                ),
                child: i < text.length
                    ? Text(text[i], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0B2E2B)))
                    : (i == active ? Container(width: 2, height: 24, color: theme.colorScheme.primary) : null),
              ),
            ),
        ]),
        // Kolom isian sebenarnya: transparan, menutupi kotak agar tempel/seleksi tetap berfungsi.
        Positioned.fill(
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(widget.length)],
              enableInteractiveSelection: false,
              showCursor: false,
              autofillHints: const [AutofillHints.oneTimeCode],
              onChanged: widget.onChanged,
              decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
            ),
          ),
        ),
      ]),
    );
  }
}
