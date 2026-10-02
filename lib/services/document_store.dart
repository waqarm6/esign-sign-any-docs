import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_record.dart';

class DocumentStore {
  static const _key = 'esign_doc_pro_documents';
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static List<DocumentRecord>? _cachedDocuments;
  static Future<List<DocumentRecord>>? _initialLoad;
  static Future<void> _pendingWrite = Future<void>.value();

  static List<DocumentRecord> get currentDocuments =>
      List<DocumentRecord>.unmodifiable(_cachedDocuments ?? const []);

  Future<List<DocumentRecord>> loadDocuments() async {
    if (_cachedDocuments != null) return currentDocuments;
    final loading = _initialLoad ??= _readDocuments();
    try {
      _cachedDocuments ??= await loading;
      return currentDocuments;
    } finally {
      _initialLoad = null;
    }
  }

  Future<List<DocumentRecord>> _readDocuments() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => DocumentRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveDocument(DocumentRecord document) async {
    await loadDocuments();
    final documents = List<DocumentRecord>.of(currentDocuments);
    final index = documents.indexWhere((item) => item.id == document.id);
    if (index == -1) {
      documents.insert(0, document);
    } else {
      documents[index] = document;
    }
    await _write(documents);
  }

  Future<void> deleteDocument(String id) async {
    await loadDocuments();
    final documents = List<DocumentRecord>.of(currentDocuments);
    documents.removeWhere((item) => item.id == id);
    await _write(documents);
  }

  Future<void> _write(List<DocumentRecord> documents) async {
    final previous = _cachedDocuments;
    _cachedDocuments = documents;
    changes.value++;
    final serialized =
        jsonEncode(documents.map((item) => item.toJson()).toList());
    final write = _pendingWrite.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(_key, serialized);
      if (!saved) throw StateError('Could not save documents on this device.');
    });
    _pendingWrite = write.catchError((Object _) {});
    try {
      await write;
    } catch (_) {
      if (identical(_cachedDocuments, documents)) {
        _cachedDocuments = previous;
        changes.value++;
      }
      rethrow;
    }
  }
}
