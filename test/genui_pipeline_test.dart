import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:logging/logging.dart';
import 'package:naija_kitchen/catalog/kitchen_catalog.dart';

/// Feeds a canned Gemini reply through the real genui pipeline (no network)
/// and checks that the surface renders.
Future<SurfaceController> pumpReply(WidgetTester tester, String reply) async {
  late SurfaceController controller;
  final surfaceIds = <String>[];

  // Run the pipeline in the real async zone so its streams deliver events.
  await tester.runAsync(() async {
    controller = SurfaceController(catalogs: [kitchenCatalog()]);
    final transport = A2uiTransportAdapter(onSend: (_) async {});
    final conversation = Conversation(controller: controller, transport: transport);
    conversation.events.listen((e) {
      if (e is ConversationSurfaceAdded) surfaceIds.add(e.surfaceId);
    });
    addTearDown(() {
      conversation.dispose();
      transport.dispose();
      controller.dispose();
    });

    // Simulate streaming: split the reply into small chunks.
    for (var i = 0; i < reply.length; i += 37) {
      transport.addChunk(reply.substring(i, (i + 37).clamp(0, reply.length)));
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });

  expect(surfaceIds, isNotEmpty, reason: 'no surface was created');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [for (final id in surfaceIds) Surface(surfaceContext: controller.contextFor(id))]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

const basicReply = '''
Here is a simple one.
```json
{"version": "v0.9", "createSurface": {"surfaceId": "s1", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json", "sendDataModel": true}}
```
```json
{"version": "v0.9", "updateComponents": {"surfaceId": "s1", "components": [
  {"id": "root", "component": "Card", "child": "col"},
  {"id": "col", "component": "Column", "children": ["title", "go"]},
  {"id": "title", "component": "Text", "text": "Party Jollof Rice", "variant": "h2"},
  {"id": "go", "component": "Button", "child": "goText", "action": {"event": {"name": "start_cooking"}}},
  {"id": "goText", "component": "Text", "text": "Start cooking"}
]}}
```
''';

void main() {
  configureLogging(level: Level.ALL, logCallback: (l, m) => debugPrint("GENUI $l $m"));
  testWidgets('basic catalog surface renders from streamed text', (tester) async {
    await pumpReply(tester, basicReply);
    expect(find.text('Party Jollof Rice'), findsOneWidget);
    expect(find.text('Start cooking'), findsOneWidget);
  });
}
