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
