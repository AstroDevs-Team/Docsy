import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
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

class CodeBlock extends StatefulWidget {
  final CodeBlockNode node;
  const CodeBlock({super.key, required this.node});

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _showingCopiedMessage = false;
  void _triggerCopiedMessage() {
    setState(() => _showingCopiedMessage = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showingCopiedMessage = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.node.inlines.map((s) => s.text).join();

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 200,
          maxWidth: 600,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),

          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 2,
                left: 15,
                child: Text(
                  widget.node.language?.toUpperCase() ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                child: HighlightView(
                  code,
                  language: widget.node.language ?? 'unknown',
                  theme: a11yDarkTheme,
                  padding: const EdgeInsets.all(8),
                  textStyle:
                      const TextStyle(fontFamily: 'FiraMono', fontSize: 14),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showingCopiedMessage ? 1 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.lightBlueAccent.withAlpha(100),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "Copied To Clipboard",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 100),
                      opacity: !_showingCopiedMessage ? 1 : 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.lightBlueAccent.withAlpha(100),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: IconButton(
                            padding: const EdgeInsets.all(1),
                            icon: const Icon(
                              Icons.copy,
                              color: Colors.white70,
                              size: 18,
                            ),
                            splashRadius: 20,
                            tooltip: "Copy",
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              _triggerCopiedMessage();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          //   IntrinsicWidth(
          //     child: Column(
          //       children: [
          //         HighlightView(
          //           code,
          //           padding: const EdgeInsets.all(8),
          //           language: widget.node.language ?? 'plaintext',
          //           theme: atomOneDarkTheme,
          //           textStyle: const TextStyle(
          //             fontFamily: 'monospace',
          //             fontSize: 14,
          //           ),
          //         ),
          //         Align(
          //           alignment: Alignment.centerRight,
          //           child: IconButton(
          //             tooltip: 'Copy',
          //             icon:
          //                 const Icon(Icons.copy, size: 16, color: Colors.white70),
          //             onPressed: () {
          //               Clipboard.setData(ClipboardData(text: code));
          //               ScaffoldMessenger.of(context).showSnackBar(
          //                 const SnackBar(content: Text('Code copied')),
          //               );
          //             },
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
        ),
      ),
    );
  }
}
