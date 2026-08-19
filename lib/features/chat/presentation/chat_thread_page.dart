import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/failure.dart';
import '../../../shared/design_system.dart';
import '../../orders/presentation/order_formatting.dart';
import '../domain/entities/message.dart';
import '../providers/chat_providers.dart';

/// A single conversation thread: a realtime message list plus a composer. The
/// sender is resolved server-side; this screen never sets a profile id. The
/// caller's own id (for alignment only) comes from [myProfileIdProvider].
class ChatThreadPage extends ConsumerStatefulWidget {
  const ChatThreadPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends ConsumerState<ChatThreadPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await ref.read(chatRepositoryProvider).markRead(widget.conversationId);
    } catch (_) {
      // Read receipts are best-effort; never surface an error for them.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(conversationId: widget.conversationId, text: text);
      _controller.clear();
    } catch (error) {
      if (mounted) {
        LuxurySnackBars.error(
          context,
          error is Failure ? error.message : 'Could not send your message.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.conversationId));
    final myProfileId = ref.watch(myProfileIdProvider).valueOrNull;

    // Auto-scroll and mark read as new messages stream in while open.
    ref.listen(chatMessagesProvider(widget.conversationId), (_, next) {
      final list = next.valueOrNull;
      if (list != null && list.length != _lastCount) {
        _lastCount = list.length;
        _scrollToBottom();
        _markRead();
      }
    });

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Conversation', showBackButton: true),
      body: Column(
        children: [
          Expanded(
            child: switch (messagesAsync) {
              AsyncData(:final value) when value.isEmpty => ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyStateWidget(
                    title: 'No messages yet',
                    message: 'Send the first message below.',
                    icon: Icons.chat_bubble_outline,
                  ),
                ],
              ),
              AsyncData(:final value) => ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: value.length,
                itemBuilder: (context, index) => _MessageBubble(
                  message: value[index],
                  mine: myProfileId != null &&
                      value[index].senderProfileId == myProfileId,
                ),
              ),
              AsyncError() => ErrorStateWidget(
                message: 'Could not load this conversation.',
                onRetry: () => ref.invalidate(
                  chatMessagesProvider(widget.conversationId),
                ),
              ),
              _ => const Center(child: LoadingIndicator()),
            },
          ),
          _Composer(
            controller: _controller,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = mine ? AppColors.primaryGold : AppColors.porcelain;
    final fg = mine ? AppColors.pureWhite : AppColors.charcoal;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Align(
        alignment: align,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(color: fg),
              ),
              if (message.createdAt != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatOrderDateTime(message.createdAt!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CustomTextField(
                controller: controller,
                hintText: 'Write a message',
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: 4,
                minLines: 1,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
