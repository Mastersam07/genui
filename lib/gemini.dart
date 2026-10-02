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
