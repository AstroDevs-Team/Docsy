import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import '../document/nodes.dart';

TextStyle _applyMarks(TextStyle base, TextMarks m) {
  var s = base;
  if (m.bold) s = s.copyWith(fontWeight: FontWeight.w600);
  if (m.italic) s = s.copyWith(fontStyle: FontStyle.italic);
  if (m.underline) {
    s = s.copyWith(
      decoration: TextDecoration.combine([
        s.decoration ?? TextDecoration.none,
        TextDecoration.underline,
      ]),
    );
  }
  if (m.code) {
    s = s.copyWith(fontFamily: 'monospace', backgroundColor: Colors.black12);
  }
  // Style links (blue + underline)
  if (m.link != null) {
    s = s.copyWith(
      color: Colors.blue,
      decoration: TextDecoration.combine([
        s.decoration ?? TextDecoration.none,
        TextDecoration.underline,
      ]),
    );
  }
  return s;
}

InlineSpan _inlineSpanFrom(TextStyle base, TextSpanNode span) {
  final style = _applyMarks(base, span.marks);

  // Clickable link
  final href = span.marks.link;
  if (href != null && href.isNotEmpty) {
    return TextSpan(
      text: span.text,
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          final uri = Uri.tryParse(href);
          if (uri != null) {
            // On web this opens a new tab; on mobile it launches the browser.
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
    );
  }

  // Normal text
  return TextSpan(text: span.text, style: style);
}

class ParagraphBlock extends StatelessWidget {
  final ParagraphNode node;
  const ParagraphBlock({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.copyWith(fontSize: 16);
    return Text.rich(
      TextSpan(
        children: [for (final s in node.inlines) _inlineSpanFrom(style, s)],
      ),
    );
  }
}

class HeadingBlock extends StatelessWidget {
  final HeadingNode node;
  const HeadingBlock({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final sizes = {1: 28.0, 2: 24.0, 3: 20.0, 4: 18.0, 5: 16.0, 6: 14.0};
    final style = DefaultTextStyle.of(context).style.copyWith(
          fontSize: sizes[node.level]!,
          fontWeight: FontWeight.w700,
        );
    return Text.rich(
      TextSpan(
        children: [for (final s in node.inlines) _inlineSpanFrom(style, s)],
      ),
    );
  }
}

class QuoteBlock extends StatelessWidget {
  final QuoteNode node;
  const QuoteBlock({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context)
        .style
        .copyWith(fontStyle: FontStyle.italic);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 24,
          color: Colors.grey.shade400,
          margin: const EdgeInsets.only(right: 8),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                for (final s in node.inlines) _inlineSpanFrom(base, s)
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DividerBlock extends StatelessWidget {
  const DividerBlock({super.key});
  @override
  Widget build(BuildContext context) => const Divider(height: 24);
}
