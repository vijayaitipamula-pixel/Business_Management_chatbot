import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';

class ChatMessageCard extends StatefulWidget {
  const ChatMessageCard({super.key, required this.message, this.onRegenerate});
  final ChatMessage message;
  final VoidCallback? onRegenerate;

  @override
  State<ChatMessageCard> createState() => _ChatMessageCardState();
}

class _ChatMessageCardState extends State<ChatMessageCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _openLink(String text, String? href, String title) async {
    final uri = Uri.tryParse(href ?? '');
    if (uri == null || !['https', 'http'].contains(uri.scheme)) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Keep the response available even when no browser is installed.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final message = widget.message;
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: Align(
        alignment: message.isUser
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          margin: EdgeInsets.only(
            top: 10,
            bottom: 10,
            left: message.isUser ? 32 : 0,
            right: message.isUser ? 0 : 12,
          ),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: message.isUser ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: message.isUser
                ? null
                : Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.6),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!message.isUser) ...[
                Text(
                  message.isAi ? 'CUBEFORE AI' : 'CUBEFORE ASSISTANT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (message.isUser)
                SelectableText(
                  message.text,
                  style: TextStyle(color: colors.onPrimary, height: 1.5),
                )
              else if (!message.isAi &&
                  BusinessSummaryCard.canDisplay(message.text))
                BusinessSummaryCard(text: message.text)
              else
                MarkdownBody(
                  data: message.text,
                  selectable: true,
                  onTapLink: _openLink,
                  softLineBreak: true,
                  imageBuilder: (uri, title, alt) => Text(alt ?? 'Image'),
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.6),
                        tableColumnWidth: const FixedColumnWidth(150),
                        codeblockDecoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                ),
              if (!message.isUser && widget.onRegenerate != null) ...[
                const SizedBox(height: 8),
                IconButton(
                  tooltip: 'Regenerate response',
                  onPressed: widget.onRegenerate,
                  iconSize: 18,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Presents only exact summary fields returned by the existing local service.
/// No inferred trends, fabricated categories, or generated numbers.
class BusinessSummaryCard extends StatelessWidget {
  const BusinessSummaryCard({super.key, required this.text});
  final String text;
  static bool canDisplay(String text) =>
      (text.trim().startsWith('Today Summary:') ||
          text.trim().startsWith('This Month Summary:')) &&
      _fields(text).length == 4;

  static List<RegExpMatch> _fields(String text) => RegExp(
    r'^(Income|Expense|Purchase|Profit): (.+)$',
    multiLine: true,
  ).allMatches(text).toList();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.trim().split('\n').first.replaceAll(':', ''),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Sample data • this session only',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        for (final field in _fields(text))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: field.group(1) == 'Profit'
                  ? colors.primaryContainer
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 24,
              runSpacing: 4,
              children: [
                Text(field.group(1)!),
                Text(
                  field.group(2)!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
