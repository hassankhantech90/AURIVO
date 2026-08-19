import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/failure.dart';
import '../../../../shared/design_system.dart';
import '../../../authentication/providers/session_provider.dart';
import '../../providers/chat_providers.dart';

/// Reusable entry point to start (or reuse) a conversation with a seller and
/// open its thread. The counterpart is derived server-side from the supplied
/// business context — this widget never sends a profile id beyond the seller
/// store it is placed against. Hidden for signed-out users.
class MessageSellerButton extends ConsumerStatefulWidget {
  const MessageSellerButton({
    super.key,
    required this.sellerProfileId,
    this.orderId,
    this.rfqId,
    this.label = 'Message seller',
  });

  /// The seller store id (`seller_profiles.id`).
  final String sellerProfileId;

  /// Optional order context (`orders.id`) — the server validates the seller has
  /// items in this order.
  final String? orderId;

  /// Optional RFQ context (`rfqs.id`) — the server validates the RFQ is directed
  /// to this seller.
  final String? rfqId;

  final String label;

  @override
  ConsumerState<MessageSellerButton> createState() =>
      _MessageSellerButtonState();
}

class _MessageSellerButtonState extends ConsumerState<MessageSellerButton> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await ref.read(chatRepositoryProvider).startConversation(
            sellerProfileId: widget.sellerProfileId,
            orderId: widget.orderId,
            rfqId: widget.rfqId,
          );
      if (!mounted) return;
      context.push(AppRoutes.messageThreadPath(id));
    } catch (error) {
      if (mounted) {
        LuxurySnackBars.error(
          context,
          error is Failure ? error.message : 'Could not open the conversation.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(
      sessionProvider.select((s) => s.isAuthenticated),
    );
    if (!isAuthenticated) return const SizedBox.shrink();
    return LuxuryOutlinedButton(
      label: widget.label,
      icon: Icons.chat_bubble_outline,
      isLoading: _busy,
      onPressed: _busy ? null : _open,
    );
  }
}
