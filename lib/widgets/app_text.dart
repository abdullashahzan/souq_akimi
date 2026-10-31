import 'package:flutter/widgets.dart' hide Text;
import 'package:flutter/material.dart' as m;

import '../core/l10n.dart';

/// A drop-in replacement for Flutter's `Text` that translates the copy while
/// keeping every call site unchanged.
///
/// English strings are the lookup keys (see `core/l10n.dart`). Values that are
/// not in the dictionary — product names, usernames, user-written descriptions —
/// pass through untouched, so this never mangles data.
///
/// `Text.rich` is supported by translating each literal span's text.
class Text extends StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.args,
  }) : textSpan = null;

  const Text.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.args,
  }) : data = null;

  final String? data;
  final m.InlineSpan? textSpan;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;
  final Map<String, String>? args;

  @override
  Widget build(BuildContext context) {
    // Reading the ambient locale makes every copy widget depend on the
    // Localizations scope. Without this, only the widgets that happen to
    // rebuild on a language switch would translate; the rest (chips, cards
    // already on screen) would keep the previous language until recreated.
    Localizations.maybeLocaleOf(context);
    final label = semanticsLabel == null ? null : translate(semanticsLabel!);
    if (data != null) {
      return m.Text(
        translate(data!, args: args),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: label,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }

    return m.Text.rich(
      _translateSpan(textSpan ?? const m.TextSpan(text: '')),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: label,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }

  m.InlineSpan _translateSpan(m.InlineSpan span) {
    if (span is! m.TextSpan) return span;
    return m.TextSpan(
      text: span.text == null ? null : translate(span.text!),
      children: span.children?.map(_translateSpan).toList(growable: false),
      style: span.style,
      recognizer: span.recognizer,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      mouseCursor: span.mouseCursor,
    );
  }
}
