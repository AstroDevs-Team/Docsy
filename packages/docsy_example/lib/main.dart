import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:docsy/docsy.dart';
import 'package:docsy_toolbar/docsy_toolbar.dart';

void main() => runApp(const DocsyDemo());

class DocsyDemo extends StatefulWidget {
  const DocsyDemo({super.key});
  @override
  State<DocsyDemo> createState() => _DocsyDemoState();
}

class _DocsyDemoState extends State<DocsyDemo> {
  late final EditorController controller;
  bool _isEditing = true; // ← toggle state

  @override
  void initState() {
    super.initState();
    controller = EditorController();
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/example_document.json');
    final jsonMap = json.decode(raw) as Map<String, dynamic>;
    controller.transact((tx) {
      tx.add((_) => DocsyJson.decode(jsonMap));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Docsy — Example'),
          actions: [
            // Edit / Preview toggle
            IconButton(
              tooltip: _isEditing ? 'Switch to Preview' : 'Switch to Edit',
              icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
              onPressed: () => setState(() => _isEditing = !_isEditing),
            ),

            // Quick actions (mainly useful in edit mode)
            IconButton(
              icon: const Icon(Icons.title),
              onPressed: () => controller.insertHeading(level: 2),
            ),
            IconButton(
              icon: const Icon(Icons.format_bold),
              onPressed: () => controller.toggleBold(0),
            ),
            IconButton(
              icon: const Icon(Icons.horizontal_rule),
              onPressed: controller.insertDivider,
            ),
            IconButton(icon: const Icon(Icons.undo), onPressed: controller.undo),
            IconButton(icon: const Icon(Icons.redo), onPressed: controller.redo),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DocsyToolbar(controller: controller),
            ),
            const Divider(height: 0),
            Expanded(
              child: RichTextEditor(
                controller: controller,
                isEditing: _isEditing, // ← pass toggle to editor
              ),
            ),
          ],
        ),
        floatingActionButton: _isEditing
            ? FloatingActionButton(
                onPressed: controller.insertParagraphAtEnd,
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}