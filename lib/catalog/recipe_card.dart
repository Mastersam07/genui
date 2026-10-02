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
