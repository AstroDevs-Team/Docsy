# Docsy Markdown

The **Docsy Markdown** package provides export functionality for the [Docsy editor](https://pub.dev/packages/docsy).  
It allows you to serialize Docsy documents into **Markdown** for developer-friendly formats, notes, or content storage.

[![Try it Live](https://img.shields.io/badge/Try%20it%20Live-Docsy-blue?style=for-the-badge&logo=flutter)](https://astrodevs-team.github.io/Docsy/)


## ✨ Features

- Export any Docsy `Document` into Markdown.
- Supports paragraphs, headings, quotes, lists, dividers, inline formatting (bold, italic, underline, code, links).
- Clean and Git-friendly output.

## 🚀 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  docsy_markdown: ^0.0.1
```

## 📖 Usage

```dart
import 'package:docsy/docsy.dart';
import 'package:docsy_markdown/docsy_markdown.dart';

void main() {
  final doc = Document([
    ParagraphNode(inlines: [
      TextSpanNode("Hello ", marks: TextMarks()),
      TextSpanNode("world", marks: TextMarks(bold: true)),
    ]),
  ]);

  final md = DocsyMarkdownCodec().encode(doc);
  print(md); // Hello **world**
}
```

## 📷 Example

```markdown
Hello **world**
```

## 📜 License

MIT License. See [LICENSE](../LICENSE).
