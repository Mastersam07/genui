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
