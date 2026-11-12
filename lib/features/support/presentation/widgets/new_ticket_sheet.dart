import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/presentation/failure_text.dart';
import '../../../../core/presentation/format.dart';
import '../../application/support_controllers.dart';
import '../support_labels.dart';
import '../../../../core/presentation/a11y.dart';

class NewTicketSheet extends ConsumerStatefulWidget {
  const NewTicketSheet({this.orderId, super.key});

  final String? orderId;

  @override
  ConsumerState<NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends ConsumerState<NewTicketSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _body = TextEditingController();
  TicketType _type = TicketType.question;
  String? _orderId;

  @override
  void initState() {
    super.initState();
    _orderId = widget.orderId;
  }

  String? _knownOrder(List<Order> orders) {
    final current = _orderId;
    if (current == null) return null;
    for (final order in orders) {
      if (order.id == current) return current;
    }
    return null;
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ticket = await ref
        .read(ticketComposerProvider.notifier)
        .create(
          type: _type,
          subject: _subject.text,
          body: _body.text,
          orderId: _orderId,
        );
    if (!mounted) return;
    final state = ref.read(ticketComposerProvider);
    if (ticket != null) {
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.supportTicketCreated)),
      );
      return;
    }
    if (state.queued) {
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.supportQueued)));
      return;
    }
    final failure = state.failure;
    if (failure != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureText(l10n, failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final composer = ref.watch(ticketComposerProvider);
    final orders = ref.watch(ticketOrderChoicesProvider).value;
    final fmt = Fmt.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: PicPacSpacing.xl,
        right: PicPacSpacing.xl,
        top: PicPacSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + PicPacSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.supportNewTicket,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.actionClose,
                    onPressed: composer.busy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: PicPacSpacing.md),
              Text(l10n.supportTypeLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: PicPacSpacing.sm),
              Wrap(
                spacing: PicPacSpacing.sm,
                runSpacing: PicPacSpacing.sm,
                children: <Widget>[
                  for (final type in const <TicketType>[
                    TicketType.question,
                    TicketType.defect,
                    TicketType.refund,
                    TicketType.delivery,
                    TicketType.other,
                  ])
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: kMinTouchTarget,
                      ),
                      child: ChoiceChip(
                        label: Text(ticketTypeLabel(l10n, type)),
                        selected: _type == type,
                        onSelected: (_) => setState(() => _type = type),
                      ),
                    ),
                ],
              ),
              if (orders != null && orders.isNotEmpty) ...<Widget>[
                const SizedBox(height: PicPacSpacing.lg),
                DropdownButtonFormField<String?>(
                  key: const Key('ticket-order'),
                  initialValue: _knownOrder(orders),
                  decoration: InputDecoration(
                    labelText: l10n.supportOrderLabel,
                  ),
                  items: <DropdownMenuItem<String?>>[
                    DropdownMenuItem<String?>(
                      child: Text(l10n.supportOrderNone),
                    ),
                    for (final order in orders)
                      DropdownMenuItem<String?>(
                        value: order.id,
                        child: Text(
                          '${order.number} · ${fmt.date(order.createdAt)}',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _orderId = value),
                ),
              ],
              const SizedBox(height: PicPacSpacing.md),
              TextFormField(
                key: const Key('ticket-subject'),
                controller: _subject,
                textInputAction: TextInputAction.next,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: l10n.supportSubjectLabel,
                  hintText: l10n.supportSubjectHint,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.supportSubjectRequired
                    : null,
              ),
              const SizedBox(height: PicPacSpacing.sm),
              TextFormField(
                key: const Key('ticket-body'),
                controller: _body,
                minLines: 4,
                maxLines: 8,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.supportMessageLabel,
                  hintText: l10n.supportMessageHint,
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.supportMessageRequired
                    : null,
              ),
              const SizedBox(height: PicPacSpacing.md),
              MinTapTarget(
                child: FilledButton(
                  onPressed: composer.busy ? null : _submit,
                  child: composer.busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.supportCreate),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
