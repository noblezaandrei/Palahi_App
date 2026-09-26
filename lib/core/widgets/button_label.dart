import 'package:flutter/material.dart';

/// A button label that always stays on one line. On narrow phones, or with
/// large system text, it shrinks to fit instead of breaking mid-word
/// ("Acce / pt").
class ButtonLabel extends StatelessWidget {
  final String text;

  const ButtonLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}

/// Side padding for buttons that share a row — the theme's default 24px on
/// each side left too little room for their labels.
const compactButtonPadding = EdgeInsets.symmetric(horizontal: 8);
