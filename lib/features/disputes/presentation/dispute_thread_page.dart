import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/money.dart';
import '../../../shared/design_system.dart';
import '../../admin/providers/admin_providers.dart';
import '../domain/entities/dispute.dart';
import '../providers/dispute_providers.dart';

/// One dispute: summary, the participants' conversation (with evidence
/// images), and the actions the viewer may take — the opener can withdraw,
/// an admin can add internal notes and resolve with a refund decision.
class DisputeThreadPage extends ConsumerStatefulWidget {
  const DisputeThreadPage({super.key, required this.disputeId});

  final String disputeId;

  @override
  ConsumerState<DisputeThreadPage> createState() => _DisputeThreadPageState();
}

class _DisputeThreadPageState extends ConsumerState<DisputeThreadPage> {
  final _message = TextEditingController();
  final _picker = ImagePicker();
  final List<(Uint8List, String)> _images = [];
  bool _internal = false;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  DisputeThreadNotifier get _notifier =>
      ref.read(disputeThreadProvider(widget.disputeId).notifier);

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    if (mounted) setState(() => _images.add((bytes, ext)));
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await _notifier.send(
      body,
      internal: _internal,
      images: List.of(_images),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      LuxurySnackBars.error(context, error);
    } else {
      _message.clear();
      setState(() {
        _images.clear();
        _internal = false;
      });
    }
  }

  Future<void> _withdraw() async {
    final ok = await LuxuryDialogs.showConfirmation(
      context: context,
      title: 'Withdraw dispute?',
      message: 'This closes the dispute without a decision.',
      confirmLabel: 'Withdraw',
      cancelLabel: 'Keep open',
    );
    if (ok != true) return;
    final error = await _notifier.withdraw();
    if (!mounted) return;
    error != null
        ? LuxurySnackBars.error(context, error)
        : LuxurySnackBars.success(context, 'Dispute withdrawn.');
  }

  Future<void> _resolve() async {
    final input = await _ResolveDialog.show(context);
    if (input == null) return;
    final error = await _notifier.resolve(
      resolution: input.$1,
      refundAmount: input.$2,
      note: input.$3,
    );
    if (!mounted) return;
    error != null
        ? LuxurySnackBars.error(context, error)
        : LuxurySnackBars.success(context, 'Dispute resolved.');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(disputeThreadProvider(widget.disputeId));
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: const LuxuryAppBar(title: 'Dispute', showBackButton: true),
      body: async.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: _notifier.load,
        ),
        data: (thread) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _notifier.load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _Summary(dispute: thread.dispute),
                    if (thread.dispute.isOpen &&
                        (thread.openedByMe || isAdmin)) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          if (thread.openedByMe)
                            Expanded(
                              child: LuxuryOutlinedButton(
                                label: 'Withdraw',
                                onPressed: _withdraw,
                              ),
                            ),
                          if (thread.openedByMe && isAdmin)
                            const SizedBox(width: AppSpacing.md),
                          if (isAdmin)
                            Expanded(
                              child: PrimaryButton(
                                label: 'Resolve',
                                onPressed: _resolve,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    for (final m in thread.messages)
                      _MessageBubble(message: m, mine: thread.isMine(m)),
                  ],
                ),
              ),
            ),
            if (thread.dispute.isOpen) _composer(isAdmin),
          ],
        ),
      ),
    );
  }

  Widget _composer(bool isAdmin) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_images.isNotEmpty)
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.memory(
                          _images[i].$1,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: const Icon(Icons.cancel, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (isAdmin)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _internal,
                onChanged: (v) => setState(() => _internal = v ?? false),
                title: const Text('Internal note (admins only)'),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Attach evidence',
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: _sending ? null : _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _message,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Write a message…',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Send',
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _sending ? null : _send,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.dispute});

  final Dispute dispute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(dispute.reasonLabel, style: theme.textTheme.titleMedium),
              ),
              LuxuryBadge(label: dispute.isOpen ? 'Open' : 'Closed'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(dispute.statusLabel, style: theme.textTheme.bodyMedium),
          if (dispute.refundAmount != null)
            Text(
              'Refund: ${formatMoney(dispute.refundAmount!)}',
              style: theme.textTheme.bodyMedium,
            ),
          if (dispute.resolutionNote != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(dispute.resolutionNote!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message, required this.mine});

  final DisputeMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = message.isInternal
        ? AppColors.warning.withValues(alpha: 0.15)
        : mine
        ? AppColors.primaryGold.withValues(alpha: 0.15)
        : theme.colorScheme.surfaceContainerHighest;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isInternal)
              Text(
                'Internal note',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(message.body, style: theme.textTheme.bodyMedium),
            for (final path in message.attachments) ...[
              const SizedBox(height: AppSpacing.sm),
              _Evidence(path: path),
            ],
          ],
        ),
      ),
    );
  }
}

/// Private evidence image loaded through a short-lived signed URL.
class _Evidence extends ConsumerWidget {
  const _Evidence({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(disputeRepositoryProvider).evidenceUrl(path),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(child: Icon(Icons.image_outlined)),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Image.network(
            snap.data!,
            height: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          ),
        );
      },
    );
  }
}

/// Admin resolution: (resolution, refundAmount?, note) or null.
class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog();

  static Future<(String, double?, String)?> show(BuildContext context) =>
      showDialog<(String, double?, String)>(
        context: context,
        builder: (_) => const _ResolveDialog(),
      );

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  String _resolution = 'no_refund';
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partial = _resolution == 'refund_partial';
    final amount = double.tryParse(_amount.text.trim());
    final valid =
        _note.text.trim().isNotEmpty && (!partial || (amount != null && amount > 0));
    return AlertDialog(
      title: const Text('Resolve dispute'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final e in Dispute.resolutions.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _resolution == e.key,
                    onSelected: (_) => setState(() => _resolution = e.key),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (partial)
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Refund amount (PKR)'),
                onChanged: (_) => setState(() {}),
              ),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Resolution note (shown to both parties)',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !valid
              ? null
              : () => Navigator.of(
                  context,
                ).pop((_resolution, partial ? amount : null, _note.text.trim())),
          child: const Text('Resolve'),
        ),
      ],
    );
  }
}
