import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

import 'gemini.dart';
import 'prompt.dart';
import 'theme.dart';
import 'widgets/kitchen_chrome.dart';

// STEP 1: a plain text chatbot. Gemini answers with words, nothing more.

sealed class _Entry {}

class _UserEntry extends _Entry {
  _UserEntry(this.text);
  final String text;
}

class _AiTextEntry extends _Entry {
  _AiTextEntry(this.text);
  String text;
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
  final ChatSession _chat = startKitchenChat(systemInstruction: kitchenPersona);
  final _entries = <_Entry>[];
  final _scroll = ScrollController();
  bool _waiting = false;
  String? _lastPrompt;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _waiting) return;
    setState(() {
      _entries.add(_UserEntry(prompt));
      _waiting = true;
    });
    _lastPrompt = prompt;
    _scrollToEnd();

    try {
      // Stream the answer so words appear as Gemini writes them.
      await for (final chunk in _chat.sendMessageStream(Content.text(prompt))) {
        final piece = chunk.text;
        if (piece == null || piece.isEmpty) continue;
        setState(() {
          final last = _entries.lastOrNull;
          if (last is _AiTextEntry) {
            last.text += piece;
          } else {
            _entries.add(_AiTextEntry(piece));
          }
        });
        _scrollToEnd();
      }
    } catch (error) {
      setState(() => _entries.add(_ErrorEntry('$error')));
    } finally {
      setState(() => _waiting = false);
    }
  }

  void _retry() {
    final prompt = _lastPrompt;
    if (prompt == null) return;
    setState(() => _entries.removeWhere((e) => e is _ErrorEntry));
    _send(prompt);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: KitchenMotion.standard,
        curve: KitchenMotion.curve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const KitchenHeader(),
            const Divider(height: 1),
            Expanded(
              child: _entries.isEmpty
                  ? EmptyKitchen(onSuggestion: _send)
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.all(KitchenSpace.xl),
                      itemCount: _entries.length + (_waiting ? 1 : 0),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: KitchenSpace.lg),
                      itemBuilder: (context, index) {
                        if (index == _entries.length) {
                          return const CookingIndicator();
                        }
                        return switch (_entries[index]) {
                          _UserEntry(:final text) => UserMessage(text),
                          _AiTextEntry(:final text) => AssistantMessage(text),
                          _ErrorEntry(:final message) => ErrorNote(
                            message: message,
                            onRetry: _retry,
                          ),
                        };
                      },
                    ),
            ),
            Composer(enabled: !_waiting, onSend: _send),
          ],
        ),
      ),
    );
  }
}
