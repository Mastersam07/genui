# Workshop: build Naija Kitchen step by step

Follow along with the talk **Stop Building Screens: Generative UI in Flutter with Gemini and Firebase AI Logic** (DevFest Ado Ekiti 2026).

You start with a plain text chatbot. Step by step, you paste in code until Gemini builds the recipe screens for you. Every step ends at a git tag, so you can always check your work or catch up.

| Tag | You will have |
| --- | --- |
| `step-1` | A text chatbot: Firebase AI Logic + Gemini, streaming |
| `step-2` | Gemini answers with UI from genui's basic catalog |
| `step-3` | Your own `RecipeCard` widget, with a "Start cooking" action |
| `step-4` | `ServingsStepper` + `IngredientChecklist` sharing the data model |
| `step-5` | Guardrails, logging, offline demo mode, DevFest theme |
| `step-6` | Bonus: the same app in idiomatic Dart 3 |

## Before you start

Do the **Setup** section of the [README](README.md) first: Flutter, the Firebase CLI, `flutterfire configure` and a Gemini-enabled Firebase project. If you have no Firebase project, you can still follow along: step 5 adds an offline mode.

Start a branch of your own from the first tag:

```bash
git switch -c my-kitchen step-1
flutter pub get
flutter run -d chrome
```

### How each step works

- **Paste** the code blocks in order. "Replace the file" means select everything in the file and paste over it.
- **Pull** files that aren't the point of the lesson (styling, recorded data) with one `git checkout step-N -- <files>` command. Don't type those by hand.
- **Check** your work against the tag. No output means you match:

  ```bash
  git diff step-N -- lib ':!lib/firebase_options.dart'
  ```

- **Stuck?** Throw away your version of the step and take the tag's. The `':!lib/firebase_options.dart'` part keeps your Firebase config safe:

  ```bash
  git checkout step-N -- lib ':!lib/firebase_options.dart'
  ```

---

## Step 1: Talk to Gemini through Firebase AI Logic

You are already on `step-1`. Nothing to paste: run it and read the code that matters.

`lib/gemini.dart` is the whole Firebase AI Logic setup. There is no API key in the app; Firebase holds it.

```dart
import 'package:firebase_ai/firebase_ai.dart';

/// Stable Flash model on the free Gemini Developer API tier.
/// Hit a quota during the workshop? Switch to 'gemini-3.5-flash-lite'.
const kitchenModel = 'gemini-3.8-flash';

/// Starts a multi-turn chat. The ChatSession keeps the history for us.
ChatSession startKitchenChat({required String systemInstruction}) {
  final model = FirebaseAI.googleAI().generativeModel(
    model: kitchenModel,
    systemInstruction: Content.system(systemInstruction),
  );
  return model.startChat();
}
```

In `lib/kitchen_page.dart`, `_send` streams the answer with `_chat.sendMessageStream(...)` and appends each piece to the last message.

**Try it:** ask for "Party jollof rice for 6". You get a good recipe as a wall of text. You can't tick anything off, and changing the servings means asking again. The rest of the workshop fixes that.

---

## Step 2: Let Gemini answer with UI

Goal: Gemini describes UI as A2UI JSON, genui turns it into real Flutter widgets, and your page only knows how to show a `Surface`.

**2.1 Pull the styling changes** (formatting only):

```bash
git checkout step-2 -- lib/theme.dart lib/widgets/kitchen_chrome.dart
```

**2.2 Create `lib/catalog/kitchen_catalog.dart`.** The catalog is the list of widgets Gemini may use.

```dart
import 'package:genui/genui.dart';

/// The widgets Gemini is allowed to use. Nothing outside this list can
/// ever appear on screen, which is what keeps generated UI on-brand and safe.
Catalog kitchenCatalog() {
  // No-asset catalog: drops Image, Video and AudioPlayer so the model
  // cannot invent image URLs that 404 on stage.
  return BasicCatalogItems.asNoAssetCatalog();
}
```

**2.3 Replace `lib/prompt.dart`.** `PromptBuilder` writes the A2UI rules and every widget's JSON schema into the system prompt for you.

```dart
import 'package:genui/genui.dart';

/// Who the assistant is. Every step reuses this.
const kitchenPersona = '''
You are Naija Kitchen, a warm and practical Nigerian home cook.
You help people cook Nigerian and West African food with ingredients from a
typical Nigerian market. Use local names (tatashe, ata rodo, iru, ugu) and add
a short English hint the first time you use one.
Keep chat text short and friendly.
''';

/// PromptBuilder adds the A2UI protocol rules and the JSON schema of every
/// widget in [catalog]. We only add the parts that are about our app.
String kitchenSystemPrompt(Catalog catalog) {
  return PromptBuilder.chat(catalog: catalog, systemPromptFragments: [kitchenPersona]).systemPromptJoined();
}
```

**2.4 Replace `lib/kitchen_page.dart`.** Paste these blocks one after another, in order.

Imports. genui has its own `TextPart`, so it is imported twice: once without it, once with a prefix.

```dart
import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart' hide TextPart;
import 'package:genui/genui.dart' as genui;

import 'catalog/kitchen_catalog.dart';
import 'gemini.dart';
import 'prompt.dart';
import 'theme.dart';
import 'widgets/kitchen_chrome.dart';

// STEP 2: Gemini now answers with UI. The page no longer knows what a
// recipe screen looks like. It only knows how to show a Surface.
```

The entries the chat list can show (`_SurfaceEntry` holds a generated UI), and the page widget.

```dart
sealed class _Entry {}

class _UserEntry extends _Entry {
  _UserEntry(this.text);
  final String text;
}

class _AiTextEntry extends _Entry {
  _AiTextEntry(this.text);
  String text;
}

class _SurfaceEntry extends _Entry {
  _SurfaceEntry(this.surfaceId);
  final String surfaceId;
}

class _ErrorEntry extends _Entry {
  _ErrorEntry(this.message);
  final String message;
}

class KitchenPage extends StatefulWidget {
  const KitchenPage({super.key});

  @override
  State<KitchenPage> createState() => _KitchenPageState();
}
```

The four genui objects: catalog, `SurfaceController`, `A2uiTransportAdapter`, `Conversation`.

```dart
class _KitchenPageState extends State<KitchenPage> {
  // 1. The vocabulary: which widgets Gemini may use.
  final Catalog _catalog = kitchenCatalog();

  // 2. Holds every generated surface and its data model.
  late final SurfaceController _controller = SurfaceController(catalogs: [_catalog]);

  // 3. Turns Gemini's streamed text into A2UI messages.
  late final A2uiTransportAdapter _transport = A2uiTransportAdapter(onSend: _sendToGemini);

  // 4. Runs the loop: prompt -> Gemini -> surfaces -> user taps -> Gemini.
  late final Conversation _conversation = Conversation(controller: _controller, transport: _transport);

  late final ChatSession _chat = startKitchenChat(systemInstruction: kitchenSystemPrompt(_catalog));

  late final StreamSubscription<ConversationEvent> _events;
  final _entries = <_Entry>[];
  final _scroll = ScrollController();
  String? _lastPrompt;
```

Listen to the conversation, and clean everything up.

```dart
  @override
  void initState() {
    super.initState();
    _events = _conversation.events.listen(_onConversationEvent);
  }

  @override
  void dispose() {
    _events.cancel();
    _conversation.dispose();
    _transport.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }
```

The bridge to Gemini. genui calls this for typed prompts **and** for taps inside generated UI.

```dart
  /// genui calls this for every turn: typed prompts AND button taps inside
  /// generated UI. We forward it to Gemini and pipe the reply back.
  Future<void> _sendToGemini(ChatMessage message) async {
    final buffer = StringBuffer();
    for (final part in message.parts) {
      if (part.isUiInteractionPart) {
        buffer.write(part.asUiInteractionPart!.interaction);
      } else if (part is genui.TextPart) {
        buffer.write(part.text);
      }
    }
    if (buffer.isEmpty) return;

    final stream = _chat.sendMessageStream(Content.text(buffer.toString()));
    await for (final chunk in stream) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) _transport.addChunk(text);
    }
  }
```

React to conversation events: a new surface, streamed text, or an error.

```dart
  void _onConversationEvent(ConversationEvent event) {
    setState(() {
      switch (event) {
        case ConversationSurfaceAdded(:final surfaceId):
          _entries.add(_SurfaceEntry(surfaceId));
        case ConversationSurfaceRemoved(:final surfaceId):
          _entries.removeWhere((e) => e is _SurfaceEntry && e.surfaceId == surfaceId);
        case ConversationContentReceived(:final text):
          final last = _entries.lastOrNull;
          if (last is _AiTextEntry) {
            last.text += text;
          } else if (text.trim().isNotEmpty) {
            _entries.add(_AiTextEntry(text));
          }
        case ConversationError(:final error):
          _entries.add(_ErrorEntry('$error'));
        default:
          break;
      }
    });
    _scrollToEnd();
  }
```

Send, retry and scroll.

```dart
  void _send(String text) {
    final prompt = text.trim();
    if (prompt.isEmpty || _conversation.state.value.isWaiting) return;
    setState(() => _entries.add(_UserEntry(prompt)));
    _lastPrompt = prompt;
    _scrollToEnd();
    _conversation.sendRequest(ChatMessage.user(prompt));
  }

  void _retry() {
    final prompt = _lastPrompt;
    if (prompt == null) return;
    setState(() => _entries.removeWhere((e) => e is _ErrorEntry));
    _conversation.sendRequest(ChatMessage.user(prompt));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: KitchenMotion.standard, curve: KitchenMotion.curve);
    });
  }
```

Build the page. `Surface(...)` is the only "screen" in the app.

```dart
  Widget _buildEntry(_Entry entry) {
    return switch (entry) {
      _UserEntry(:final text) => UserMessage(text),
      _AiTextEntry(:final text) => AssistantMessage(text),
      _SurfaceEntry(:final surfaceId) => Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          // 5. The only "screen" we build: whatever Gemini composed.
          child: Surface(surfaceContext: _controller.contextFor(surfaceId)),
        ),
      ),
      _ErrorEntry(:final message) => ErrorNote(message: message, onRetry: _retry),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<ConversationState>(
          valueListenable: _conversation.state,
          builder: (context, state, _) {
            final waiting = state.isWaiting;
            return Column(
              children: [
                const KitchenHeader(),
                const Divider(height: 1),
                Expanded(
                  child: _entries.isEmpty && !waiting
                      ? EmptyKitchen(onSuggestion: _send)
                      : ListView.separated(
                          controller: _scroll,
                          padding: const EdgeInsets.all(KitchenSpace.xl),
                          itemCount: _entries.length + (waiting ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: KitchenSpace.lg),
                          itemBuilder: (context, index) =>
                              index == _entries.length ? const CookingIndicator() : _buildEntry(_entries[index]),
                        ),
                ),
                Composer(enabled: !waiting, onSend: _send),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

**Check:** `git diff step-2 -- lib ':!lib/firebase_options.dart'`

**Try it:** ask for jollof again. This time you get Cards, Text and Buttons that Gemini chose. It is real UI, but generic.

---

## Step 3: Build your own catalog widget

Goal: a `RecipeCard` that Gemini can use, with a button that sends the tap back to Gemini.

**3.1 Create `lib/catalog/recipe_card.dart`.** Paste these blocks in order.

The schema. Gemini reads the descriptions, so write them as instructions.

```dart
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../theme.dart';

// A custom catalog item has three parts:
//   1. a schema    -> what Gemini is allowed to send (it reads this!)
//   2. a builder   -> turns that JSON into a Flutter widget
//   3. a widget    -> plain Flutter, designed by you

// 1. The schema. Descriptions are prompts: Gemini reads them to decide
//    when and how to use this widget.
final _recipeCardSchema = S.object(
  description:
      'A summary card for one dish. Use it as the first component whenever '
      'you suggest a recipe.',
  properties: {
    'title': S.string(description: 'Dish name, e.g. "Party Jollof Rice".'),
    'region': S.string(description: 'Where the dish is from, e.g. "Yoruba, South-West".'),
    'description': S.string(description: 'One or two sentences that make the dish sound good.'),
    'minutes': S.integer(description: 'Total cooking time in minutes.'),
    'spiceLevel': S.integer(description: '0 = mild, 3 = very hot.', minimum: 0, maximum: 3),
    'action': A2uiSchemas.action(description: 'Sent when the user taps "Start cooking".'),
  },
  required: ['title', 'description', 'minutes', 'action'],
);
```

The catalog item and the action. `dispatchEvent` sends the tap to Gemini as the next turn.

```dart
// 2. The catalog item: a name, the schema, and a builder.
final recipeCard = CatalogItem(
  name: 'RecipeCard',
  dataSchema: _recipeCardSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    return RecipeCard(
      title: data['title'] as String? ?? '',
      region: data['region'] as String?,
      description: data['description'] as String? ?? '',
      minutes: (data['minutes'] as num?)?.toInt() ?? 0,
      spiceLevel: (data['spiceLevel'] as num?)?.toInt() ?? 0,
      onStartCooking: () => _sendAction(itemContext, data['action'] as JsonMap?),
    );
  },
);

/// Tells genui the user tapped. genui sends this event back to Gemini as
/// the next turn of the conversation, so no extra wiring is needed.
Future<void> _sendAction(CatalogItemContext itemContext, JsonMap? action) async {
  final event = action?['event'] as JsonMap?;
  if (event == null) return;
  final context = await resolveContext(itemContext.dataContext, event['context'] as JsonMap?);
  itemContext.dispatchEvent(
    UserActionEvent(name: event['name'] as String, sourceComponentId: itemContext.id, context: context),
  );
}
```

The widget itself: plain Flutter, nothing genui-specific.

```dart
// 3. The widget. Nothing genui-specific here: a normal Flutter widget.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.title,
    required this.description,
    required this.minutes,
    required this.spiceLevel,
    required this.onStartCooking,
    this.region,
  });

  final String title;
  final String? region;
  final String description;
  final int minutes;
  final int spiceLevel;
  final VoidCallback onStartCooking;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The palm-oil band: the one bold mark that says "a recipe".
            Container(width: 6, color: KitchenColors.accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(KitchenSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (region != null)
                      Text(region!.toUpperCase(), style: text.labelSmall?.copyWith(color: KitchenColors.accent)),
                    const SizedBox(height: KitchenSpace.xs),
                    Text(title, style: text.headlineSmall),
                    const SizedBox(height: KitchenSpace.sm),
                    Text(description, style: text.bodyMedium?.copyWith(color: KitchenColors.inkMuted)),
                    const SizedBox(height: KitchenSpace.lg),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 18, color: KitchenColors.inkMuted),
                        const SizedBox(width: KitchenSpace.xs),
                        Text('$minutes min', style: text.bodyMedium),
                        const SizedBox(width: KitchenSpace.lg),
                        _SpiceMeter(level: spiceLevel),
                      ],
                    ),
                    const SizedBox(height: KitchenSpace.lg),
                    FilledButton.icon(
                      onPressed: onStartCooking,
                      icon: const Icon(Icons.local_fire_department_outlined),
                      label: const Text('Start cooking'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpiceMeter extends StatelessWidget {
  const _SpiceMeter({required this.level});

  final int level;

  static const _labels = ['Mild', 'A little heat', 'Hot', 'Very hot'];

  @override
  Widget build(BuildContext context) {
    final clamped = level.clamp(0, 3);
    return Semantics(
      label: 'Spice: ${_labels[clamped]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 1; i <= 3; i++)
            Icon(Icons.whatshot, size: 18, color: i <= clamped ? KitchenColors.accent : KitchenColors.border),
        ],
      ),
    );
  }
}
```

**3.2 Register it.** Replace `lib/catalog/kitchen_catalog.dart`:

```dart
import 'package:genui/genui.dart';

import 'recipe_card.dart';

/// The widgets Gemini is allowed to use. Nothing outside this list can
/// ever appear on screen, which is what keeps generated UI on-brand and safe.
Catalog kitchenCatalog() {
  // No-asset catalog: drops Image, Video and AudioPlayer so the model
  // cannot invent image URLs that 404 on stage.
  return BasicCatalogItems.asNoAssetCatalog().copyWith(newItems: [recipeCard]);
}
```

**3.3 Tell Gemini when to use it.** Replace `lib/prompt.dart`. The schema says *what* the widget is; these rules say *when* to use it.

```dart
import 'package:genui/genui.dart';

/// Who the assistant is. Every step reuses this.
const kitchenPersona = '''
You are Naija Kitchen, a warm and practical Nigerian home cook.
You help people cook Nigerian and West African food with ingredients from a
typical Nigerian market. Use local names (tatashe, ata rodo, iru, ugu) and add
a short English hint the first time you use one.
Keep chat text short and friendly.
''';

/// How to use our own widgets. Schemas say WHAT a widget is;
/// this says WHEN to use it.
const kitchenUiRules = '''
- When you suggest a dish, create a surface whose root is a Column that
  starts with a RecipeCard. Give its action the event name "start_cooking"
  and put the dish title in the event context.
- When the user starts cooking, create a NEW surface: a Card with a Column of
  numbered steps, using Text components. Each step is one or two sentences
  with a sensory cue, e.g. "until the oil stops foaming".
''';

/// PromptBuilder adds the A2UI protocol rules and the JSON schema of every
/// widget in [catalog]. We only add the parts that are about our app.
String kitchenSystemPrompt(Catalog catalog) {
  return PromptBuilder.chat(
    catalog: catalog,
    systemPromptFragments: [kitchenPersona, kitchenUiRules],
  ).systemPromptJoined();
}
```

**Check:** `git diff step-3 -- lib ':!lib/firebase_options.dart'`

**Try it:** ask for a dish, then tap **Start cooking**. Gemini receives the `start_cooking` event and replies with a new surface of cooking steps.

---

## Step 4: Widgets that talk through the data model

Goal: changing the servings rescales every quantity instantly, with no call to Gemini.

**4.1 Pull the scrolling and styling fixes:**

```bash
git checkout step-4 -- lib/kitchen_page.dart lib/theme.dart
```

**4.2 Create `lib/catalog/servings_stepper.dart`.** It writes a number to a data-model path.

Schema and catalog item. `BoundNumber` rebuilds when the value at the path changes.

```dart
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../theme.dart';

// Writes a number into the surface's data model. Any widget bound to the
// same path (like IngredientChecklist) rebuilds when it changes, with no
// round trip to Gemini.

final _servingsStepperSchema = S.object(
  description: 'Lets the user choose how many people they are cooking for.',
  properties: {
    'value': A2uiSchemas.numberReference(description: 'Always bind to a path, e.g. {"path": "/servings"}.'),
    'initial': S.integer(description: 'Starting number of servings.', minimum: 1, maximum: 20),
  },
  required: ['value', 'initial'],
);

final servingsStepper = CatalogItem(
  name: 'ServingsStepper',
  dataSchema: _servingsStepperSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final ref = data['value'];
    final path = ref is Map && ref['path'] is String ? ref['path'] as String : '/servings';
    final initial = (data['initial'] as num?)?.toInt() ?? 4;

    return BoundNumber(
      dataContext: itemContext.dataContext,
      value: {'path': path},
      builder: (context, value) {
        if (value == null) {
          // Seed the data model once so bound widgets agree from the start.
          WidgetsBinding.instance.addPostFrameCallback((_) => itemContext.dataContext.update(DataPath(path), initial));
        }
        return ServingsStepper(
          servings: value?.toInt() ?? initial,
          onChanged: (n) => itemContext.dataContext.update(DataPath(path), n),
        );
      },
    );
  },
);
```

The widget.

```dart
class ServingsStepper extends StatelessWidget {
  const ServingsStepper({super.key, required this.servings, required this.onChanged});

  final int servings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KitchenSpace.lg, vertical: KitchenSpace.sm),
        child: Row(
          children: [
            const Icon(Icons.groups_outlined, color: KitchenColors.inkMuted),
            const SizedBox(width: KitchenSpace.md),
            Expanded(child: Text('Cooking for', style: text.bodyLarge)),
            IconButton.outlined(
              tooltip: 'Fewer people',
              onPressed: servings > 1 ? () => onChanged(servings - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '$servings',
                textAlign: TextAlign.center,
                semanticsLabel: '$servings people',
                style: text.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            IconButton.outlined(
              tooltip: 'More people',
              onPressed: servings < 20 ? () => onChanged(servings + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
```

**4.3 Create `lib/catalog/ingredient_checklist.dart`.** It reads the same path and rescales.

Schema and catalog item. `scale` is the chosen servings divided by the servings the recipe was written for.

```dart
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../theme.dart';

// Reads the servings number from the data model and rescales every
// quantity live. Gemini writes the list once; Flutter does the maths.

final _ingredientChecklistSchema = S.object(
  description: 'A tickable shopping/prep list of ingredients with quantities.',
  properties: {
    'servings': A2uiSchemas.numberReference(
      description: 'Bind to the same path as the ServingsStepper, e.g. {"path": "/servings"}.',
    ),
    'baseServings': S.integer(description: 'How many people the quantities below feed.', minimum: 1),
    'ingredients': S.list(
      items: S.object(
        properties: {
          'name': S.string(description: 'Ingredient, e.g. "Tatashe (red bell pepper)".'),
          'quantity': S.number(description: 'Amount for baseServings people.'),
          'unit': S.string(description: 'e.g. "cups", "g", "pieces". Omit if none.'),
        },
        required: ['name', 'quantity'],
      ),
    ),
  },
  required: ['baseServings', 'ingredients'],
);

final ingredientChecklist = CatalogItem(
  name: 'IngredientChecklist',
  dataSchema: _ingredientChecklistSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final base = (data['baseServings'] as num?)?.toDouble() ?? 1;
    final ingredients = [
      for (final item in (data['ingredients'] as List? ?? const []).cast<JsonMap>())
        Ingredient(
          name: item['name'] as String? ?? '',
          quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
          unit: item['unit'] as String? ?? '',
        ),
    ];

    return BoundNumber(
      dataContext: itemContext.dataContext,
      value: data['servings'],
      builder: (context, servings) =>
          IngredientChecklist(ingredients: ingredients, scale: (servings?.toDouble() ?? base) / base),
    );
  },
);
```

The data class, the checklist, and its ticked state.

```dart
class Ingredient {
  const Ingredient({required this.name, required this.quantity, required this.unit});

  final String name;
  final double quantity;
  final String unit;
}

class IngredientChecklist extends StatefulWidget {
  const IngredientChecklist({super.key, required this.ingredients, required this.scale});

  final List<Ingredient> ingredients;
  final double scale;

  @override
  State<IngredientChecklist> createState() => _IngredientChecklistState();
}

class _IngredientChecklistState extends State<IngredientChecklist> {
  final _ready = <int>{};

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = widget.ingredients;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KitchenSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(KitchenSpace.lg, 0, KitchenSpace.lg, KitchenSpace.sm),
              child: Row(
                children: [
                  Expanded(child: Text('Ingredients', style: text.titleLarge)),
                  Text(
                    '${_ready.length} of ${items.length} ready',
                    style: text.bodySmall?.copyWith(color: KitchenColors.inkMuted),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < items.length; i++)
              _IngredientRow(
                ingredient: items[i],
                scale: widget.scale,
                ready: _ready.contains(i),
                onToggle: () => setState(() => _ready.contains(i) ? _ready.remove(i) : _ready.add(i)),
              ),
          ],
        ),
      ),
    );
  }
}
```

One row, and the helper that prints ½ and ¾ instead of 0.5 and 0.75.

```dart
class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient, required this.scale, required this.ready, required this.onToggle});

  final Ingredient ingredient;
  final double scale;
  final bool ready;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final amount = [formatQuantity(ingredient.quantity * scale), ingredient.unit].join(' ').trim();
    return InkWell(
      onTap: onToggle,
      child: Semantics(
        checked: ready,
        label: '${ingredient.name}, $amount',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KitchenSpace.lg, vertical: KitchenSpace.md),
          child: Row(
            children: [
              AnimatedContainer(
                duration: KitchenMotion.quick,
                curve: KitchenMotion.curve,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ready ? KitchenColors.done : Colors.transparent,
                  border: Border.all(color: ready ? KitchenColors.done : KitchenColors.border, width: 2),
                ),
                child: ready ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: KitchenSpace.md),
              Expanded(
                child: Text(
                  ingredient.name,
                  style: text.bodyLarge?.copyWith(
                    color: ready ? KitchenColors.inkMuted : KitchenColors.ink,
                    decoration: ready ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: KitchenSpace.md),
              Text(
                amount,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1.5 -> "1½", 2.0 -> "2", 0.333 -> "⅓", 37.4 -> "37".
String formatQuantity(double value) {
  if (value >= 10) return value.round().toString();
  const fractions = [(0.25, '¼'), (0.33, '⅓'), (0.5, '½'), (0.67, '⅔'), (0.75, '¾')];
  final whole = value.floor();
  final rest = value - whole;
  if (rest < 0.13) return '$whole';
  if (rest > 0.87) return '${whole + 1}';
  final nearest = fractions.reduce((a, b) => (rest - a.$1).abs() < (rest - b.$1).abs() ? a : b);
  return '${whole == 0 ? '' : whole}${nearest.$2}';
}
```

**4.4 Register both.** Replace `lib/catalog/kitchen_catalog.dart`:

```dart
import 'package:genui/genui.dart';

import 'ingredient_checklist.dart';
import 'recipe_card.dart';
import 'servings_stepper.dart';

/// The widgets Gemini is allowed to use. Nothing outside this list can
/// ever appear on screen, which is what keeps generated UI on-brand and safe.
Catalog kitchenCatalog() {
  // No-asset catalog: drops Image, Video and AudioPlayer so the model
  // cannot invent image URLs that 404 on stage.
  return BasicCatalogItems.asNoAssetCatalog().copyWith(newItems: [recipeCard, servingsStepper, ingredientChecklist]);
}
```

**4.5 Tell Gemini to bind them to the same path.** Replace `lib/prompt.dart`:

```dart
import 'package:genui/genui.dart';

/// Who the assistant is. Every step reuses this.
const kitchenPersona = '''
You are Naija Kitchen, a warm and practical Nigerian home cook.
You help people cook Nigerian and West African food with ingredients from a
typical Nigerian market. Use local names (tatashe, ata rodo, iru, ugu) and add
a short English hint the first time you use one.
Keep chat text short and friendly.
''';

/// How to use our own widgets. Schemas say WHAT a widget is;
/// this says WHEN to use it.
const kitchenUiRules = '''
- When you suggest a dish, create a surface whose root is a Column that
  starts with a RecipeCard. Give its action the event name "start_cooking"
  and put the dish title in the event context.
- Under the RecipeCard, add a ServingsStepper bound to {"path": "/servings"}
  and an IngredientChecklist whose servings is bound to the SAME path.
  Write quantities for baseServings people; the app rescales them.
  Add {"servings": {"path": "/servings"}} to the start_cooking context.
- When the user starts cooking, create a NEW surface: a Card with a Column of
  numbered steps, using Text components. Each step is one or two sentences
  with a sensory cue, e.g. "until the oil stops foaming". Scale any
  amounts you mention to the servings in the event context.
''';

/// PromptBuilder adds the A2UI protocol rules and the JSON schema of every
/// widget in [catalog]. We only add the parts that are about our app.
String kitchenSystemPrompt(Catalog catalog) {
  return PromptBuilder.chat(
    catalog: catalog,
    systemPromptFragments: [kitchenPersona, kitchenUiRules],
  ).systemPromptJoined();
}
```

**Check:** `git diff step-4 -- lib ':!lib/firebase_options.dart'`

**Try it:** ask for jollof, tap **+** twice and watch 4 cups become 6. Tick a few ingredients, then tap **Start cooking**: the steps are scaled to your servings.

---

## Step 5: Guardrails, logging and an offline mode

Goal: keep the assistant on topic, see what Gemini sends, and keep working without Wi-Fi.

**5.1 Pull the DevFest theme and the recorded offline replies:**

```bash
git checkout step-5 -- lib/theme.dart lib/widgets/kitchen_chrome.dart lib/offline_demo.dart lib/catalog/recipe_card.dart lib/catalog/ingredient_checklist.dart
```

**5.2 Replace `lib/gemini.dart`.** `KitchenChef` is the one place that talks to the model, live or recorded.

```dart
import 'package:firebase_ai/firebase_ai.dart';

import 'offline_demo.dart';

/// Stable Flash model on the free Gemini Developer API tier.
/// Hit a quota during the workshop? Switch to 'gemini-3.5-flash-lite'.
const kitchenModel = 'gemini-3.8-flash';

/// `flutter run --dart-define=OFFLINE_DEMO=true` replays a recorded
/// conversation instead of calling Gemini. Use it when the Wi-Fi gives up.
const offlineDemo = bool.fromEnvironment('OFFLINE_DEMO');

/// Starts a multi-turn chat. The ChatSession keeps the history for us.
ChatSession startKitchenChat({required String systemInstruction}) {
  final model = FirebaseAI.googleAI().generativeModel(
    model: kitchenModel,
    systemInstruction: Content.system(systemInstruction),
  );
  return model.startChat();
}

/// One place that talks to the model, live or recorded.
class KitchenChef {
  KitchenChef({required this.systemInstruction});

  final String systemInstruction;

  // Created on first use, so offline mode never touches Firebase.
  late final ChatSession _chat = startKitchenChat(systemInstruction: systemInstruction);

  Stream<String> reply(String message) {
    if (offlineDemo) return replayRecordedReply(message);
    return _chat.sendMessageStream(Content.text(message)).map((r) => r.text ?? '');
  }
}
```

**5.3 Replace `lib/main.dart`.** It turns on genui logging and skips Firebase in offline mode.

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'firebase_options.dart';
import 'gemini.dart';
import 'kitchen_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    // Print every A2UI message genui receives. Great for "what did Gemini send?"
    configureLogging(logCallback: (level, message) => debugPrint('genui $level: $message'));
  }
  if (!offlineDemo) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(const NaijaKitchenApp());
}

class NaijaKitchenApp extends StatelessWidget {
  const NaijaKitchenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naija Kitchen',
      debugShowCheckedModeBanner: false,
      theme: buildKitchenTheme(),
      home: const KitchenPage(),
    );
  }
}
```

**5.4 Use the chef in `lib/kitchen_page.dart`.** Make three edits.

Delete this import:

```dart
import 'package:firebase_ai/firebase_ai.dart';
```

Replace the `_chat` field with:

```dart
  // Live Gemini, or a recorded reply when run with OFFLINE_DEMO=true.
  late final KitchenChef _chef = KitchenChef(systemInstruction: kitchenSystemPrompt(_catalog));
```

At the end of `_sendToGemini`, replace these lines:

```dart
    final stream = _chat.sendMessageStream(Content.text(buffer.toString()));
    await for (final chunk in stream) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) _transport.addChunk(text);
    }
```

with:

```dart
    await for (final text in _chef.reply(buffer.toString())) {
      if (text.isNotEmpty) _transport.addChunk(text);
    }
```

**5.5 Add guardrails.** Replace `lib/prompt.dart`:

```dart
import 'package:genui/genui.dart';

/// Who the assistant is. Every step reuses this.
const kitchenPersona = '''
You are Naija Kitchen, a warm and practical Nigerian home cook.
You help people cook Nigerian and West African food with ingredients from a
typical Nigerian market. Use local names (tatashe, ata rodo, iru, ugu) and add
a short English hint the first time you use one.
Keep chat text short and friendly.
''';

/// How to use our own widgets. Schemas say WHAT a widget is;
/// this says WHEN to use it.
const kitchenUiRules = '''
- When you suggest a dish, create a surface whose root is a Column that
  starts with a RecipeCard. Give its action the event name "start_cooking"
  and put the dish title in the event context.
- Under the RecipeCard, add a ServingsStepper bound to {"path": "/servings"}
  and an IngredientChecklist whose servings is bound to the SAME path.
  Write quantities for baseServings people; the app rescales them.
  Add {"servings": {"path": "/servings"}} to the start_cooking context.
- When the user starts cooking, create a NEW surface: a Card with a Column of
  numbered steps, using Text components. Each step is one or two sentences
  with a sensory cue, e.g. "until the oil stops foaming". Scale any
  amounts you mention to the servings in the event context.
''';

/// Keeps the assistant on topic and honest.
const kitchenGuardrails = '''
- Only help with food, cooking and meal planning. For anything else, say in
  one friendly sentence that you only talk food, and suggest a dish.
- Never make medical or nutrition claims. Mention common allergens (groundnut,
  crayfish, egusi) in the description when a dish contains them.
- If the request is vague ("something with yam"), offer two or three dishes
  as Buttons and let the user pick, instead of asking in plain text.
''';

/// PromptBuilder adds the A2UI protocol rules and the JSON schema of every
/// widget in [catalog]. We only add the parts that are about our app.
String kitchenSystemPrompt(Catalog catalog) {
  return PromptBuilder.chat(
    catalog: catalog,
    systemPromptFragments: [kitchenPersona, kitchenUiRules, kitchenGuardrails],
  ).systemPromptJoined();
}
```

**Check:** `git diff step-5 -- lib ':!lib/firebase_options.dart'` (the only difference left should be the `// STEP` comment at the top of `kitchen_page.dart`).

**Try it:**

- Ask "Who will win the election?" The model should decline politely.
- Ask "Something with yam". You should get dish options as buttons.
- Watch your console: every A2UI message is logged.
- Run without Gemini: `flutter run -d chrome --dart-define=OFFLINE_DEMO=true`

---

## Step 6 (bonus): Idiomatic Dart 3

Same behaviour, tighter code. Gemini's JSON is untrusted input, so the catalog widgets read it with extension types and patterns instead of casts.

**6.1 Replace the three catalog widgets** with these versions.

`lib/catalog/recipe_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../theme.dart';

// Gemini reads these descriptions to decide when and how to use the widget.
final _recipeCardSchema = S.object(
  description:
      'A summary card for one dish. Use it as the first component whenever '
      'you suggest a recipe.',
  properties: {
    'title': S.string(description: 'Dish name, e.g. "Party Jollof Rice".'),
    'region': S.string(description: 'Where the dish is from, e.g. "Yoruba, South-West".'),
    'description': S.string(description: 'One or two sentences that make the dish sound good.'),
    'minutes': S.integer(description: 'Total cooking time in minutes.'),
    'spiceLevel': S.integer(description: '0 = mild, 3 = very hot.', minimum: 0, maximum: 3),
    'action': A2uiSchemas.action(description: 'Sent when the user taps "Start cooking".'),
  },
  required: ['title', 'description', 'minutes', 'action'],
);

extension type _RecipeCardData(JsonMap json) {
  String get title => switch (json['title']) {
    final String title => title,
    _ => '',
  };
  String? get region => switch (json['region']) {
    final String region => region,
    _ => null,
  };
  String get description => switch (json['description']) {
    final String text => text,
    _ => '',
  };
  int get minutes => switch (json['minutes']) {
    final num minutes => minutes.toInt(),
    _ => 0,
  };
  int get spiceLevel => switch (json['spiceLevel']) {
    final num level => level.toInt(),
    _ => 0,
  };
  JsonMap? get action => switch (json['action']) {
    final JsonMap action => action,
    _ => null,
  };
}

final recipeCard = CatalogItem(
  name: 'RecipeCard',
  dataSchema: _recipeCardSchema,
  widgetBuilder: (itemContext) {
    final data = _RecipeCardData(itemContext.data as JsonMap);
    return RecipeCard(
      title: data.title,
      region: data.region,
      description: data.description,
      minutes: data.minutes,
      spiceLevel: data.spiceLevel,
      onStartCooking: () => _sendAction(itemContext, data.action),
    );
  },
);

/// genui sends this event to Gemini as the next conversation turn.
Future<void> _sendAction(CatalogItemContext itemContext, JsonMap? action) async {
  if (action?['event'] case {'name': final String name} && final JsonMap event) {
    final context = await resolveContext(itemContext.dataContext, event['context'] as JsonMap?);
    itemContext.dispatchEvent(UserActionEvent(name: name, sourceComponentId: itemContext.id, context: context));
  }
}

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.title,
    required this.description,
    required this.minutes,
    required this.spiceLevel,
    required this.onStartCooking,
    this.region,
  });

  final String title;
  final String? region;
  final String description;
  final int minutes;
  final int spiceLevel;
  final VoidCallback onStartCooking;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: .antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: .stretch,
          children: [
            Container(width: 6, color: KitchenColors.accent),
            Expanded(
              child: Padding(
                padding: const .all(KitchenSpace.xl),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    if (region case final region?)
                      Container(
                        padding: const .symmetric(horizontal: KitchenSpace.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: KitchenColors.tag,
                          border: .all(color: KitchenColors.border),
                          borderRadius: .circular(KitchenRadius.control),
                        ),
                        child: Text(region.toUpperCase(), style: text.labelSmall),
                      ),
                    const SizedBox(height: KitchenSpace.xs),
                    Text(title, style: text.headlineSmall),
                    const SizedBox(height: KitchenSpace.sm),
                    Text(description, style: text.bodyMedium?.copyWith(color: KitchenColors.inkMuted)),
                    const SizedBox(height: KitchenSpace.lg),
                    Row(
                      spacing: KitchenSpace.lg,
                      children: [
                        Row(
                          spacing: KitchenSpace.xs,
                          children: [
                            const Icon(Icons.schedule, size: 18, color: KitchenColors.inkMuted),
                            Text('$minutes min', style: text.bodyMedium),
                          ],
                        ),
                        _SpiceMeter(level: spiceLevel),
                      ],
                    ),
                    const SizedBox(height: KitchenSpace.lg),
                    FilledButton.icon(
                      onPressed: onStartCooking,
                      icon: const Icon(Icons.local_fire_department_outlined),
                      label: const Text('Start cooking'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpiceMeter extends StatelessWidget {
  const _SpiceMeter({required this.level});

  final int level;

  static const _labels = ['Mild', 'A little heat', 'Hot', 'Very hot'];

  @override
  Widget build(BuildContext context) {
    final clamped = level.clamp(0, 3);
    return Semantics(
      label: 'Spice: ${_labels[clamped]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (final chili in [1, 2, 3])
            Icon(Icons.whatshot, size: 18, color: chili <= clamped ? KitchenColors.spice : KitchenColors.spiceOff),
        ],
      ),
    );
  }
}
```

`lib/catalog/servings_stepper.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../theme.dart';

final _servingsStepperSchema = S.object(
  description: 'Lets the user choose how many people they are cooking for.',
  properties: {
    'value': A2uiSchemas.numberReference(description: 'Always bind to a path, e.g. {"path": "/servings"}.'),
    'initial': S.integer(description: 'Starting number of servings.', minimum: 1, maximum: 20),
  },
  required: ['value', 'initial'],
);

extension type _ServingsStepperData(JsonMap json) {
  String get path => switch (json['value']) {
    {'path': final String path} => path,
    _ => '/servings',
  };

  int get initial => switch (json['initial']) {
    final num initial => initial.toInt(),
    _ => 4,
  };
}

final servingsStepper = CatalogItem(
  name: 'ServingsStepper',
  dataSchema: _servingsStepperSchema,
  widgetBuilder: (itemContext) {
    final _ServingsStepperData(:path, :initial) = _ServingsStepperData(itemContext.data as JsonMap);

    return BoundNumber(
      dataContext: itemContext.dataContext,
      value: {'path': path},
      builder: (context, value) {
        if (value == null) {
          // Seed the data model once so bound widgets agree from the start.
          WidgetsBinding.instance.addPostFrameCallback((_) => itemContext.dataContext.update(DataPath(path), initial));
        }
        return ServingsStepper(
          servings: value?.toInt() ?? initial,
          onChanged: (n) => itemContext.dataContext.update(DataPath(path), n),
        );
      },
    );
  },
);

class ServingsStepper extends StatelessWidget {
  const ServingsStepper({super.key, required this.servings, required this.onChanged});

  final int servings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const .symmetric(horizontal: KitchenSpace.lg, vertical: KitchenSpace.sm),
        child: Row(
          spacing: KitchenSpace.md,
          children: [
            const Icon(Icons.groups_outlined, color: KitchenColors.inkMuted),
            Expanded(child: Text('Cooking for', style: text.bodyLarge)),
            IconButton.outlined(
              tooltip: 'Fewer people',
              onPressed: servings > 1 ? () => onChanged(servings - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 32, // fixed, so the buttons don't shift between 9 and 10
              child: Text(
                '$servings',
                textAlign: .center,
                semanticsLabel: '$servings people',
                style: text.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            IconButton.outlined(
              tooltip: 'More people',
              onPressed: servings < 20 ? () => onChanged(servings + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
```

`lib/catalog/ingredient_checklist.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../theme.dart';

final _ingredientChecklistSchema = S.object(
  description: 'A tickable shopping/prep list of ingredients with quantities.',
  properties: {
    'servings': A2uiSchemas.numberReference(
      description: 'Bind to the same path as the ServingsStepper, e.g. {"path": "/servings"}.',
    ),
    'baseServings': S.integer(description: 'How many people the quantities below feed.', minimum: 1),
    'ingredients': S.list(
      items: S.object(
        properties: {
          'name': S.string(description: 'Ingredient, e.g. "Tatashe (red bell pepper)".'),
          'quantity': S.number(description: 'Amount for baseServings people.'),
          'unit': S.string(description: 'e.g. "cups", "g", "pieces". Omit if none.'),
        },
        required: ['name', 'quantity'],
      ),
    ),
  },
  required: ['baseServings', 'ingredients'],
);

extension type _ChecklistData(JsonMap json) {
  /// A literal number or a {"path": ...} binding; BoundNumber resolves both.
  Object? get servings => json['servings'];

  double get baseServings => switch (json['baseServings']) {
    final num base when base > 0 => base.toDouble(),
    _ => 1,
  };

  List<Ingredient> get ingredients => switch (json['ingredients']) {
    final List<Object?> items => [for (final item in items) ?Ingredient.tryParse(item)],
    _ => const [],
  };
}

final ingredientChecklist = CatalogItem(
  name: 'IngredientChecklist',
  dataSchema: _ingredientChecklistSchema,
  widgetBuilder: (itemContext) {
    final data = _ChecklistData(itemContext.data as JsonMap);
    final ingredients = data.ingredients;
    final base = data.baseServings;

    return BoundNumber(
      dataContext: itemContext.dataContext,
      value: data.servings,
      builder: (context, servings) =>
          IngredientChecklist(ingredients: ingredients, scale: (servings?.toDouble() ?? base) / base),
    );
  },
);

final class Ingredient {
  const Ingredient({required this.name, required this.quantity, this.unit = ''});

  static Ingredient? tryParse(Object? json) => switch (json) {
    {'name': final String name, 'quantity': final num quantity, 'unit': final String unit} => Ingredient(
      name: name,
      quantity: quantity.toDouble(),
      unit: unit,
    ),
    {'name': final String name, 'quantity': final num quantity} => Ingredient(
      name: name,
      quantity: quantity.toDouble(),
    ),
    _ => null,
  };

  final String name;
  final double quantity;
  final String unit;
}

class IngredientChecklist extends StatefulWidget {
  const IngredientChecklist({super.key, required this.ingredients, required this.scale});

  final List<Ingredient> ingredients;
  final double scale;

  @override
  State<IngredientChecklist> createState() => _IngredientChecklistState();
}

class _IngredientChecklistState extends State<IngredientChecklist> {
  final _ready = <int>{};

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = widget.ingredients;
    return Card(
      child: Padding(
        padding: const .symmetric(vertical: KitchenSpace.md),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const .fromLTRB(KitchenSpace.lg, 0, KitchenSpace.lg, KitchenSpace.sm),
              child: Row(
                children: [
                  Expanded(child: Text('Ingredients', style: text.titleLarge)),
                  Text(
                    '${_ready.length} of ${items.length} ready',
                    style: text.bodySmall?.copyWith(color: KitchenColors.inkMuted),
                  ),
                ],
              ),
            ),
            for (final (i, ingredient) in items.indexed)
              _IngredientRow(
                ingredient: ingredient,
                scale: widget.scale,
                ready: _ready.contains(i),
                onToggle: () => setState(() {
                  if (!_ready.remove(i)) _ready.add(i);
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient, required this.scale, required this.ready, required this.onToggle});

  final Ingredient ingredient;
  final double scale;
  final bool ready;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scaled = ingredient.quantity * scale;
    // Nobody buys half a tomato: whole items round up.
    final countable = ingredient.unit.isEmpty || ingredient.unit.startsWith('piece');
    final amount = [formatQuantity(countable ? scaled.ceilToDouble() : scaled), ingredient.unit].join(' ').trim();
    return InkWell(
      onTap: onToggle,
      child: Semantics(
        checked: ready,
        label: '${ingredient.name}, $amount',
        excludeSemantics: true,
        child: Padding(
          padding: const .symmetric(horizontal: KitchenSpace.lg, vertical: KitchenSpace.md),
          child: Row(
            spacing: KitchenSpace.md,
            children: [
              AnimatedContainer(
                duration: KitchenMotion.quick,
                curve: KitchenMotion.curve,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: .circle,
                  color: ready ? KitchenColors.done : KitchenColors.surface,
                  border: .all(color: ready ? KitchenColors.done : KitchenColors.border, width: 2),
                ),
                child: ready ? const Icon(Icons.check, size: 16, color: KitchenColors.ink) : null,
              ),
              Expanded(
                child: Text(
                  ingredient.name,
                  style: text.bodyLarge?.copyWith(
                    color: ready ? KitchenColors.inkMuted : KitchenColors.ink,
                    decoration: ready ? .lineThrough : null,
                  ),
                ),
              ),
              Text(
                amount,
                style: text.bodyMedium?.copyWith(fontWeight: .w600, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1.5 -> "1½", 2.0 -> "2", 0.333 -> "⅓", 37.4 -> "37".
String formatQuantity(double value) {
  if (value >= 10) return value.round().toString();
  const fractions = [(0.25, '¼'), (0.33, '⅓'), (0.5, '½'), (0.67, '⅔'), (0.75, '¾')];
  final whole = value.floor();
  final rest = value - whole;
  if (rest < 0.13) return '$whole';
  if (rest > 0.87) return '${whole + 1}';
  final nearest = fractions.reduce((a, b) => (rest - a.$1).abs() < (rest - b.$1).abs() ? a : b);
  return '${whole == 0 ? '' : whole}${nearest.$2}';
}
```

**6.2 Pull the rest of the refactor** (dot shorthands, the exhaustive event switch, comment cleanup):

```bash
git checkout step-6 -- lib ':!lib/firebase_options.dart' test pubspec.yaml
flutter pub get
```

Then read what changed in the page:

```bash
git diff step-5 step-6 -- lib/kitchen_page.dart
```

**Try it:** run `flutter test`. The four tests stream recorded Gemini replies through the real genui pipeline, and they pass on both `step-5` and `step-6`.

---

## You're done

You built an app with no recipe screens: Gemini picks the widgets, and Flutter draws them with your design. To go further, see "Going further" in the codelab, or add a `CookingTimer` widget of your own.
