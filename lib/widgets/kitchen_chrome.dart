import 'package:flutter/material.dart';

import '../theme.dart';

class KitchenHeader extends StatelessWidget {
  const KitchenHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const .fromLTRB(KitchenSpace.xl, KitchenSpace.lg, KitchenSpace.xl, KitchenSpace.md),
      child: Row(
        spacing: KitchenSpace.md,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KitchenColors.brand,
              border: .all(color: KitchenColors.border, width: 1.5),
              borderRadius: .circular(KitchenRadius.control),
            ),
            alignment: .center,
            child: const Icon(Icons.soup_kitchen_outlined, color: KitchenColors.ink),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
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
      alignment: .centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const .symmetric(horizontal: KitchenSpace.lg, vertical: KitchenSpace.md),
        decoration: BoxDecoration(color: KitchenColors.accentSoft, borderRadius: .circular(KitchenRadius.card)),
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
      alignment: .centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Text(text.trim(), style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class CookingIndicator extends StatefulWidget {
  const CookingIndicator({super.key});

  @override
  State<CookingIndicator> createState() => _CookingIndicatorState();
}

class _CookingIndicatorState extends State<CookingIndicator> with SingleTickerProviderStateMixin {
  static const _dotColors = [DevFestPalette.googleBlue, DevFestPalette.googleRed, DevFestPalette.googleYellow];

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
        spacing: KitchenSpace.sm,
        children: [
          Row(
            spacing: KitchenSpace.xs,
            children: [
              for (final (i, color) in _dotColors.indexed)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = (_controller.value - i * 0.2) % 1.0;
                    final lift = still ? 0.0 : (t < 0.5 ? t : 1 - t) * 8;
                    return Transform.translate(
                      offset: Offset(0, -lift),
                      child: CircleAvatar(radius: 4, backgroundColor: color),
                    );
                  },
                ),
            ],
          ),
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
        padding: const .all(KitchenSpace.xl),
        child: Column(
          mainAxisSize: .min,
          children: [
            const Icon(Icons.ramen_dining_outlined, size: 56, color: KitchenColors.accent),
            const SizedBox(height: KitchenSpace.lg),
            Text(
              'Ask for any Nigerian dish.\nI will plate up the recipe for you.',
              textAlign: .center,
              style: text.bodyLarge?.copyWith(color: KitchenColors.inkMuted),
            ),
            const SizedBox(height: KitchenSpace.xl),
            Wrap(
              alignment: .center,
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
      padding: const .all(KitchenSpace.lg),
      decoration: BoxDecoration(
        color: DevFestPalette.pastelRed,
        border: .all(color: KitchenColors.error, width: 1.5),
        borderRadius: .circular(KitchenRadius.card),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text('Gemini did not answer that one.', style: text.titleSmall?.copyWith(fontWeight: .w700)),
          const SizedBox(height: KitchenSpace.xs),
          Text(
            message,
            maxLines: 3,
            overflow: .ellipsis,
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
      padding: const .fromLTRB(KitchenSpace.lg, KitchenSpace.sm, KitchenSpace.lg, KitchenSpace.lg),
      child: Row(
        spacing: KitchenSpace.sm,
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              textInputAction: .send,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(hintText: 'e.g. Efo riro with what I have at home'),
            ),
          ),
          IconButton.filled(
            onPressed: widget.enabled ? _submit : null,
            tooltip: 'Send',
            style: IconButton.styleFrom(
              backgroundColor: KitchenColors.action,
              foregroundColor: KitchenColors.onAction,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }
}
