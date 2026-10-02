import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart' hide TextPart;
import 'package:genui/genui.dart' as genui;

import 'catalog/kitchen_catalog.dart';
import 'gemini.dart';
import 'prompt.dart';
import 'theme.dart';
import 'widgets/kitchen_chrome.dart';

sealed class _Entry {}

final class _UserEntry extends _Entry {
  _UserEntry(this.text);
  final String text;
}

final class _AiTextEntry extends _Entry {
  _AiTextEntry(this.text);
  String text;
}

final class _SurfaceEntry extends _Entry {
  _SurfaceEntry(this.surfaceId);
  final String surfaceId;
}

final class _ErrorEntry extends _Entry {
  _ErrorEntry(this.message);
  final String message;
}

class KitchenPage extends StatefulWidget {
  const KitchenPage({super.key});

  @override
  State<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends State<KitchenPage> {
  final Catalog _catalog = kitchenCatalog();

  late final SurfaceController _controller = SurfaceController(catalogs: [_catalog]);

  late final A2uiTransportAdapter _transport = A2uiTransportAdapter(onSend: _sendToGemini);

  late final Conversation _conversation = Conversation(controller: _controller, transport: _transport);

  late final KitchenChef _chef = KitchenChef(systemInstruction: kitchenSystemPrompt(_catalog));

  late final StreamSubscription<ConversationEvent> _events;
  final _entries = <_Entry>[];
  final _scroll = ScrollController();
  final _surfaceKeys = <String, GlobalKey>{};
  String? _newestSurfaceId;
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

  /// Called for typed prompts and for taps inside generated UI.
  Future<void> _sendToGemini(ChatMessage message) async {
    final prompt = [
      for (final part in message.parts)
        if (part.asUiInteractionPart case final ui?)
          ui.interaction
        else if (part case genui.TextPart(:final text))
          text,
    ].join();
    if (prompt.isEmpty) return;

    await for (final text in _chef.reply(prompt)) {
      if (text.isNotEmpty) _transport.addChunk(text);
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
          if (_entries.lastOrNull case final _AiTextEntry last) {
            last.text += text;
          } else if (text.trim().isNotEmpty) {
            _entries.add(_AiTextEntry(text));
          }
        case ConversationError(:final error):
          _entries.add(_ErrorEntry('$error'));
        // No default, so a new event type in genui is a compile error.
        case ConversationWaiting() || ConversationComponentsUpdated():
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
    if (_lastPrompt case final prompt?) {
      setState(() => _entries.removeWhere((e) => e is _ErrorEntry));
      _conversation.sendRequest(ChatMessage.user(prompt));
    }
  }

  /// Shows the top of this turn's generated UI (the recipe title), or the
  /// end of the list when there is no new surface yet.
  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (_surfaceKeys[_newestSurfaceId]?.currentContext case final surfaceContext?) {
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
        alignment: .centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
        child: ValueListenableBuilder(
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
                          padding: const .all(KitchenSpace.xl),
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
