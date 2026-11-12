import 'package:api_contract/api_contract.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/presentation/state_views.dart';

String ticketStatusLabel(AppLocalizations l10n, TicketStatus status) =>
    switch (status) {
      TicketStatus.open => l10n.supportStatusOpen,
      TicketStatus.pending => l10n.supportStatusPending,
      TicketStatus.resolved => l10n.supportStatusResolved,
      TicketStatus.closed => l10n.supportStatusClosed,
      TicketStatus.unknown => l10n.supportStatusUnknown,
    };

ChipTone ticketStatusTone(TicketStatus status) => switch (status) {
  TicketStatus.open => ChipTone.progress,
  TicketStatus.pending => ChipTone.warning,
  TicketStatus.resolved => ChipTone.success,
  TicketStatus.closed || TicketStatus.unknown => ChipTone.neutral,
};

String ticketTypeLabel(AppLocalizations l10n, TicketType type) =>
    switch (type) {
      TicketType.question => l10n.supportTypeQuestion,
      TicketType.defect => l10n.supportTypeDefect,
      TicketType.refund => l10n.supportTypeRefund,
      TicketType.delivery => l10n.supportTypeDelivery,
      TicketType.other => l10n.supportTypeOther,
      TicketType.unknown => l10n.supportTypeUnknown,
    };
