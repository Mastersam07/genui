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
  final _surfaceKeys = <String, GlobalKey>{};
  String? _newestSurfaceId; // the surface from the current turn, if any
  String? _lastPrompt;

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

  void _onConversationEvent(ConversationEvent event) {
    setState(() {
      switch (event) {
        case ConversationSurfaceAdded(:final surfaceId):
          _entries.add(_SurfaceEntry(surfaceId));
          _surfaceKeys[surfaceId] = GlobalKey();
          _newestSurfaceId = surfaceId;
        case ConversationSurfaceRemoved(:final surfaceId):
          _entries.removeWhere((e) => e is _SurfaceEntry && e.surfaceId == surfaceId);
          _surfaceKeys.remove(surfaceId);
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
    _scrollToLatest();
  }

  void _send(String text) {
    final prompt = text.trim();
    if (prompt.isEmpty || _conversation.state.value.isWaiting) return;
    setState(() => _entries.add(_UserEntry(prompt)));
    _lastPrompt = prompt;
    _newestSurfaceId = null;
    _scrollToLatest();
    _conversation.sendRequest(ChatMessage.user(prompt));
  }

  void _retry() {
    final prompt = _lastPrompt;
    if (prompt == null) return;
    setState(() => _entries.removeWhere((e) => e is _ErrorEntry));
    _conversation.sendRequest(ChatMessage.user(prompt));
  }

  /// Shows the top of this turn's generated UI (the recipe title), or the
  /// end of the list when there is no new surface yet.
  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final surfaceContext = _surfaceKeys[_newestSurfaceId]?.currentContext;
      if (surfaceContext != null) {
        Scrollable.ensureVisible(surfaceContext, duration: KitchenMotion.standard, curve: KitchenMotion.curve);
        return;
      }
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: KitchenMotion.standard, curve: KitchenMotion.curve);
    });
  }

  Widget _buildEntry(_Entry entry) {
    return switch (entry) {
      _UserEntry(:final text) => UserMessage(text),
      _AiTextEntry(:final text) => AssistantMessage(text),
      _SurfaceEntry(:final surfaceId) => Align(
        key: _surfaceKeys[surfaceId],
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
