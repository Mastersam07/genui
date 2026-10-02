import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:logging/logging.dart';
import 'package:naija_kitchen/catalog/ingredient_checklist.dart';
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

const recipeReply = '''
```json
{"version": "v0.9", "createSurface": {"surfaceId": "jollof", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json", "sendDataModel": true}}
```
```json
{"version": "v0.9", "updateComponents": {"surfaceId": "jollof", "components": [
  {"id": "root", "component": "Column", "children": ["card"]},
  {"id": "card", "component": "RecipeCard", "title": "Party Jollof Rice", "region": "Nationwide",
   "description": "Smoky, tomato-rich rice.", "minutes": 75, "spiceLevel": 2,
   "action": {"event": {"name": "start_cooking", "context": {"dish": "Party Jollof Rice"}}}}
]}}
```
''';

const fullReply = '''
Jollof coming up!
```json
{"version": "v0.9", "createSurface": {"surfaceId": "jollof", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json", "sendDataModel": true}}
```
```json
{"version": "v0.9", "updateComponents": {"surfaceId": "jollof", "components": [
  {"id": "root", "component": "Column", "children": ["card", "servings", "list"]},
  {"id": "card", "component": "RecipeCard", "title": "Party Jollof Rice", "description": "Smoky rice.", "minutes": 75,
   "action": {"event": {"name": "start_cooking", "context": {"dish": "Party Jollof Rice", "servings": {"path": "/servings"}}}}},
  {"id": "servings", "component": "ServingsStepper", "value": {"path": "/servings"}, "initial": 4},
  {"id": "list", "component": "IngredientChecklist", "servings": {"path": "/servings"}, "baseServings": 4,
   "ingredients": [{"name": "Long-grain rice", "quantity": 4, "unit": "cups"}, {"name": "Tatashe", "quantity": 2, "unit": "pieces"}]}
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

  testWidgets('RecipeCard renders and sends start_cooking back to the model', (tester) async {
    final controller = await pumpReply(tester, recipeReply);
    final submitted = <ChatMessage>[];
    final sub = controller.onSubmit.listen(submitted.add);
    addTearDown(sub.cancel);

    expect(find.text('Party Jollof Rice'), findsOneWidget);
    expect(find.text('75 min'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Start cooking'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    expect(submitted, hasLength(1));
    final interaction = submitted.single.parts.uiInteractionParts.single.interaction;
    expect(interaction, contains('start_cooking'));
    expect(interaction, contains('Party Jollof Rice'));
  });

  testWidgets('ServingsStepper rescales IngredientChecklist through the data model', (tester) async {
    final controller = await pumpReply(tester, fullReply);
    await tester.pumpAndSettle();
    expect(find.text('4 cups'), findsOneWidget);

    // 4 -> 6 servings: no Gemini call, Flutter rescales 4 cups to 6.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('More people'));
      // genui's data model notifies through signals; let them settle.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }
    expect(find.text('6'), findsOneWidget);
    expect(find.text('6 cups'), findsOneWidget);
    expect(find.text('3 pieces'), findsOneWidget);

    // The chosen servings ride along when the user taps Start cooking.
    final submitted = <ChatMessage>[];
    final sub = controller.onSubmit.listen(submitted.add);
    addTearDown(sub.cancel);
    await tester.runAsync(() async {
      await tester.tap(find.text('Start cooking'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    expect(submitted.single.parts.uiInteractionParts.single.interaction, contains('"servings":6'));
  });

  test('formatQuantity', () {
    expect(formatQuantity(1.5), '1½');
    expect(formatQuantity(2), '2');
    expect(formatQuantity(0.34), '⅓');
    expect(formatQuantity(37.4), '37');
  });
}
