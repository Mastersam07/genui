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
