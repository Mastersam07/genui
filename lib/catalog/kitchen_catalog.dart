import 'package:genui/genui.dart';

import 'ingredient_checklist.dart';
import 'recipe_card.dart';
import 'servings_stepper.dart';

Catalog kitchenCatalog() {
  // No-asset catalog: drops Image, Video and AudioPlayer so the model
  // cannot invent image URLs that 404 on stage.
  return BasicCatalogItems.asNoAssetCatalog().copyWith(newItems: [recipeCard, servingsStepper, ingredientChecklist]);
}
