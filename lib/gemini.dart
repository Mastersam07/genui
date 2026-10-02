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
