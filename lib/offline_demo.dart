// Recorded Gemini replies for OFFLINE_DEMO mode. They go through the exact
// same genui parser and catalog as live replies; only the network is fake.

const _catalogId = 'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

Stream<String> replayRecordedReply(String message) async* {
  final reply = message.contains('start_cooking') ? _cookingSteps : _jollofRecipe;
  await Future<void>.delayed(const Duration(milliseconds: 700));
  for (var i = 0; i < reply.length; i += 48) {
    yield reply.substring(i, (i + 48).clamp(0, reply.length));
    await Future<void>.delayed(const Duration(milliseconds: 12));
  }
}

int _surfaceCount = 0;
String _nextSurfaceId() => 'offline-${_surfaceCount++}';

String get _jollofRecipe {
  final id = _nextSurfaceId();
  return '''
Party jollof coming up! Adjust the servings and the list follows.
```json
{"version": "v0.9", "createSurface": {"surfaceId": "$id", "catalogId": "$_catalogId", "sendDataModel": true}}
```
```json
{"version": "v0.9", "updateComponents": {"surfaceId": "$id", "components": [
  {"id": "root", "component": "Column", "children": ["card", "servings", "list"]},
  {"id": "card", "component": "RecipeCard", "title": "Party Jollof Rice", "region": "Nationwide",
   "description": "Smoky, tomato-rich rice with that bottom-pot flavour everyone fights over.",
   "minutes": 75, "spiceLevel": 2,
   "action": {"event": {"name": "start_cooking", "context": {"dish": "Party Jollof Rice", "servings": {"path": "/servings"}}}}},
  {"id": "servings", "component": "ServingsStepper", "value": {"path": "/servings"}, "initial": 4},
  {"id": "list", "component": "IngredientChecklist", "servings": {"path": "/servings"}, "baseServings": 4, "ingredients": [
    {"name": "Long-grain parboiled rice", "quantity": 4, "unit": "cups"},
    {"name": "Tatashe (red bell pepper)", "quantity": 3, "unit": "pieces"},
    {"name": "Fresh tomatoes", "quantity": 5, "unit": "pieces"},
    {"name": "Ata rodo (scotch bonnet)", "quantity": 2, "unit": "pieces"},
    {"name": "Onions", "quantity": 2, "unit": "pieces"},
    {"name": "Tomato paste", "quantity": 3, "unit": "tbsp"},
    {"name": "Chicken stock", "quantity": 4, "unit": "cups"},
    {"name": "Vegetable oil", "quantity": 0.5, "unit": "cup"},
    {"name": "Bay leaves", "quantity": 3, "unit": ""},
    {"name": "Curry and thyme", "quantity": 1, "unit": "tsp each"}
  ]}
]}}
```
''';
}

String get _cookingSteps {
  final id = _nextSurfaceId();
  return '''
Oya, let us cook!
```json
{"version": "v0.9", "createSurface": {"surfaceId": "$id", "catalogId": "$_catalogId", "sendDataModel": true}}
```
```json
{"version": "v0.9", "updateComponents": {"surfaceId": "$id", "components": [
  {"id": "root", "component": "Card", "child": "steps"},
  {"id": "steps", "component": "Column", "children": ["h", "s1", "s2", "s3", "s4", "s5"]},
  {"id": "h", "component": "Text", "variant": "h3", "text": "Cooking Party Jollof Rice"},
  {"id": "s1", "component": "Text", "text": "1. Blend tatashe, tomatoes, ata rodo and one onion until smooth."},
  {"id": "s2", "component": "Text", "text": "2. Fry the other onion in oil, then the tomato paste, until it darkens and smells sweet."},
  {"id": "s3", "component": "Text", "text": "3. Add the blend and cook for 25 minutes, until the oil floats on top."},
  {"id": "s4", "component": "Text", "text": "4. Season, add stock and washed rice. Cover with foil, then the lid."},
  {"id": "s5", "component": "Text", "text": "5. Cook on low for 30 minutes. Let the bottom catch a little for the party flavour."}
]}}
```
''';
}
