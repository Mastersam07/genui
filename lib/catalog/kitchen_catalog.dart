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
