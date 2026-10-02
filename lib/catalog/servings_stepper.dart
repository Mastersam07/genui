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
