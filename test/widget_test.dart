import 'dart:convert';

import 'package:esign_doc_pro/models/document_record.dart';
import 'package:esign_doc_pro/services/document_store.dart';
import 'package:esign_doc_pro/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('document changes update the visible cache and persisted list',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = DocumentStore();
    expect(await store.loadDocuments(), isEmpty);

    final now = DateTime.utc(2026, 10, 1);
    final draft = DocumentRecord(
      id: 'document-1',
      name: 'Unsigned',
      sourcePath: '/document.pdf',
      pageCount: 2,
      createdAt: now,
      updatedAt: now,
      status: DocumentStatus.draft,
    );
    var notifications = 0;
    void onChange() => notifications++;
    DocumentStore.changes.addListener(onChange);
    addTearDown(() => DocumentStore.changes.removeListener(onChange));

    await store.saveDocument(draft);
    expect(DocumentStore.currentDocuments.single.name, 'Unsigned');
    expect(notifications, 1);

    await store.saveDocument(draft.copyWith(
      name: 'Signed',
      status: DocumentStatus.completed,
      exportedPath: '/signed.pdf',
    ));
    expect(DocumentStore.currentDocuments, hasLength(1));
    expect(
        DocumentStore.currentDocuments.single.status, DocumentStatus.completed);
    expect(notifications, 2);

    final preferences = await SharedPreferences.getInstance();
    final persisted = jsonDecode(
      preferences.getString('esign_doc_pro_documents')!,
    ) as List<dynamic>;
    expect(persisted.single['name'], 'Signed');

    await store.deleteDocument(draft.id);
    expect(DocumentStore.currentDocuments, isEmpty);
    expect(notifications, 3);
    expect(await store.loadDocuments(), isEmpty);
  });

  testWidgets('onboarding fits a small phone and completes without a purchase',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var completed = false;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onDone: () => completed = true),
    ));
    expect(find.text('From paper to\nready to sign.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    expect(find.text('Start creating'), findsOneWidget);

    await tester.tap(find.text('Start creating'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(completed, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(onboardingCompleteKey), isTrue);
  });
}
