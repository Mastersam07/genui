import 'package:flutter/material.dart';

import '../theme.dart';

/// The app's fixed UI around the conversation: header, message rows,
/// composer, and the empty / waiting / error states. None of this is
/// generated. It stays the same through every workshop step.

class KitchenHeader extends StatelessWidget {
  const KitchenHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitchenSpace.xl, KitchenSpace.lg, KitchenSpace.xl, KitchenSpace.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KitchenColors.accent,
              borderRadius: BorderRadius.circular(KitchenRadius.control),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.soup_kitchen_outlined, color: Colors.white),
          ),
          const SizedBox(width: KitchenSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Naija Kitchen', style: text.titleLarge),
                Text('Tell me what is in your pot.', style: text.bodySmall?.copyWith(color: KitchenColors.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UserMessage extends StatelessWidget {
  const UserMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: KitchenSpace.lg, vertical: KitchenSpace.md),
        decoration: BoxDecoration(
          color: KitchenColors.accentSoft,
          borderRadius: BorderRadius.circular(KitchenRadius.card),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class AssistantMessage extends StatelessWidget {
  const AssistantMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Text(text.trim(), style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

/// Shown while Gemini is working. Three dots that rise in turn.
class CookingIndicator extends StatefulWidget {
  const CookingIndicator({super.key});

  @override
  State<CookingIndicator> createState() => _CookingIndicatorState();
}

class _CookingIndicatorState extends State<CookingIndicator> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Gemini is cooking up a reply',
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = (_controller.value - i * 0.2) % 1.0;
                final lift = still ? 0.0 : (t < 0.5 ? t : 1 - t) * 8;
                return Padding(
                  padding: const EdgeInsets.only(right: KitchenSpace.xs),
                  child: Transform.translate(
                    offset: Offset(0, -lift),
                    child: const CircleAvatar(radius: 4, backgroundColor: KitchenColors.accent),
                  ),
                );
              },
            ),
          const SizedBox(width: KitchenSpace.sm),
          Text(
            'Stirring the pot…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: KitchenColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class EmptyKitchen extends StatelessWidget {
  const EmptyKitchen({super.key, required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  static const suggestions = [
    'Party jollof rice for 6',
    'What can I cook with yam and eggs?',
    'A quick egusi soup for a weeknight',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KitchenSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ramen_dining_outlined, size: 56, color: KitchenColors.border),
            const SizedBox(height: KitchenSpace.lg),
            Text(
              'Ask for any Nigerian dish.\nI will plate up the recipe for you.',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: KitchenColors.inkMuted),
            ),
            const SizedBox(height: KitchenSpace.xl),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: KitchenSpace.sm,
              runSpacing: KitchenSpace.sm,
              children: [for (final s in suggestions) ActionChip(label: Text(s), onPressed: () => onSuggestion(s))],
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorNote extends StatelessWidget {
  const ErrorNote({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(KitchenSpace.lg),
      decoration: BoxDecoration(
        border: Border.all(color: KitchenColors.border),
        borderRadius: BorderRadius.circular(KitchenRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gemini did not answer that one.', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: KitchenSpace.xs),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: KitchenColors.inkMuted),
          ),
          const SizedBox(height: KitchenSpace.md),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
        ],
      ),
    );
  }
}

class Composer extends StatefulWidget {
  const Composer({super.key, required this.enabled, required this.onSend});

  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.enabled || _text.text.trim().isEmpty) return;
    widget.onSend(_text.text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitchenSpace.lg, KitchenSpace.sm, KitchenSpace.lg, KitchenSpace.lg),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(hintText: 'e.g. Efo riro with what I have at home'),
            ),
          ),
          const SizedBox(width: KitchenSpace.sm),
          IconButton.filled(
            onPressed: widget.enabled ? _submit : null,
            tooltip: 'Send',
            style: IconButton.styleFrom(backgroundColor: KitchenColors.accent, minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }
}
