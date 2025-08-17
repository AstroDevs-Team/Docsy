# Docsy HTML

The **Docsy HTML** package provides export functionality for the [Docsy editor](https://pub.dev/packages/docsy).  
It allows you to serialize Docsy documents into **HTML** for rendering in browsers or embedding into websites.

## ✨ Features

- Export any Docsy `Document` into valid HTML5.
- Supports paragraphs, headings, quotes, dividers, code blocks, inline marks (bold, italic, underline, code, links).
- Lightweight, dependency-free output.

## 🚀 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  docsy_html: ^0.0.1
```

## 📖 Usage

```dart
import 'package:docsy/docsy.dart';
import 'package:docsy_html/docsy_html.dart';

void main() {
  final doc = Document([
    ParagraphNode(inlines: [
      TextSpanNode("Hello ", marks: TextMarks()),
      TextSpanNode("world", marks: TextMarks(bold: true)),
    ]),
  ]);

  final html = DocsyHtmlCodec().encode(doc);
  print(html); // <p>Hello <strong>world</strong></p>
}
```

## 📷 Example

```html
<p>Hello <strong>world</strong></p>
```

## 📜 License

MIT License. See [LICENSE](../LICENSE).
