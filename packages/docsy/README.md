# ✨ Docsy

[![pub package](https://img.shields.io/pub/v/docsy.svg)](https://pub.dev/packages/docsy)
[![likes](https://img.shields.io/pub/likes/docsy)](https://pub.dev/packages/docsy/score)
[![popularity](https://img.shields.io/pub/popularity/docsy)](https://pub.dev/packages/docsy/score)
[![points](https://img.shields.io/pub/points/docsy)](https://pub.dev/packages/docsy/score)

A modern **WYSIWYG Rich Text Editor** for Flutter.  
Write, edit, and render rich text with the same look as the final output —  
**What You See Is What You Get (WYSIWYG).**

---

## 🚀 Features

- ✍️ Full WYSIWYG editing experience  
- **Inline formatting**: bold, italic, underline, code, links  
- **Block formatting**: paragraphs, headings, quotes, dividers  
- 📋 Undo/redo with history stack  
- 🔗 Link insertion & removal  
- 🌐 JSON import/export (canonical format)  
- 📄 Markdown & HTML conversion (planned)  
- 🖥️ Works on **mobile, web, and desktop**  

---

## 📸 Screenshots

| Editing Mode | Readonly Mode |
|--------------|---------------|
| ![Docsy editing](screenshots/editing.png) | ![Docsy readonly](screenshots/readonly.png) |

---

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  docsy: ^0.1.0
```

Then run:

```bash
flutter pub get
```

---

## 🛠️ Usage

A minimal example:

```dart
import 'package:flutter/material.dart';
import 'package:docsy/docsy.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = EditorController();

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Docsy Demo')),
        body: RichTextEditor(controller: controller),
        floatingActionButton: FloatingActionButton(
          onPressed: controller.insertParagraphAtEnd,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

---

## 📖 Example

For a complete demo with toolbar, editing/preview toggle, and persistence,  
see the [example](example/) folder.

---

## 🗺️ Roadmap

- [ ] Markdown export/import  
- [ ] HTML export/import  
- [ ] Code block syntax highlighting  
- [ ] Collaborative editing support  
- [ ] Custom embeds (images, media, widgets)  

---

## ❤️ Contributing

Contributions are welcome!  
Open an issue or submit a PR to help improve Docsy.  

---

## 📜 License

Licensed under the MIT License.  
See [LICENSE](LICENSE) for details.
