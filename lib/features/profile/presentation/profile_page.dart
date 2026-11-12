import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/offline/offline_queue_listener.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../../core/presentation/a11y.dart';
import '../../../core/presentation/failure_text.dart';
import '../../../core/presentation/format.dart';
import '../../../core/presentation/state_views.dart';
import '../../../core/presentation/text_tones.dart';
import '../application/profile_controller.dart';
import 'widgets/language_section.dart';
import 'widgets/offline_queue_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final customer = ref.watch(currentCustomerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle, style: AppTheme.rootTabTitle),
      ),
      body: OfflineQueueListener(
        child: !session.isAccount
            ? ListView(
                padding: const EdgeInsets.all(PicPacSpacing.lg),
                children: <Widget>[
                  const SizedBox(height: PicPacSpacing.xxl),
                  Text(
                    l10n.profileGuestTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: PicPacSpacing.lg),
                  Center(
                    child: MinTapTarget(
                      child: FilledButton(
                        onPressed: () =>
                            context.push(AppRoutes.loginFor(AppRoutes.profile)),
                        child: Text(l10n.actionLogin),
                      ),
                    ),
                  ),
                  const SizedBox(height: PicPacSpacing.lg),
                  const LanguageSection(),
                ],
              )
            : switch (customer) {
                AsyncData<Customer?>(:final value) =>
                  value == null
                      ? const CardListSkeleton()
                      : _ProfileBody(customer: value, session: session),
                AsyncError<Customer?>(:final error) => FailureView(
                  failure: failureOr(error),
                  onRetry: () => ref.invalidate(currentCustomerProvider),
                  onLogin: () =>
                      context.push(AppRoutes.loginFor(AppRoutes.profile)),
                ),
                _ => const CardListSkeleton(),
              },
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.customer, required this.session});

  final Customer customer;
  final SessionView session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final supportMode = session.isSupportAgent;
    final actions = ref.watch(accountActionsProvider);
    final createdAt = fmt.date(customer.createdAt);
    return ListView(
      padding: const EdgeInsets.all(PicPacSpacing.lg),
      children: <Widget>[
        _ProfileHeader(customer: customer),
        const SizedBox(height: PicPacSpacing.lg),
        if (supportMode) ...<Widget>[
          SectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.shield_outlined, size: 20),
                const SizedBox(width: PicPacSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.profileSupportOnlyHint,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PicPacSpacing.lg),
        ],
        const LanguageSection(),
        const SizedBox(height: PicPacSpacing.lg),
        const OfflineQueueCard(),
        const SizedBox(height: PicPacSpacing.lg),
        MinTapTarget(
          child: OutlinedButton.icon(
            key: const Key('profile-support'),
            onPressed: () => context.push(AppRoutes.support),
            icon: const Icon(Icons.support_agent_outlined),
            label: Text(l10n.navSupport),
          ),
        ),
        const SizedBox(height: PicPacSpacing.lg),
        SectionCard(
          title: l10n.profileDataTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (customer.phoneMasked != null)
                _InfoRow(
                  label: l10n.profilePhoneLabel,
                  value: customer.phoneMasked!,
                  hint: l10n.profilePhoneHint,
                ),
              _InfoRow(label: l10n.profileCustomerSinceLabel, value: createdAt),
            ],
          ),
        ),
        if (!supportMode) ...<Widget>[
          const SizedBox(height: PicPacSpacing.lg),
          SectionCard(
            title: l10n.profileTestData,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.profileTestDataHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FunnelText.secondary,
                  ),
                ),
                const SizedBox(height: PicPacSpacing.md),
                MinTapTarget(
                  child: OutlinedButton.icon(
                    onPressed: actions.busy
                        ? null
                        : () => _deleteTestData(context, ref),
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: Text(l10n.profileDeleteTestData),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PicPacSpacing.lg),
          SectionCard(
            title: l10n.profileDangerTitle,
            child: MinTapTarget(
              child: OutlinedButton.icon(
                onPressed: actions.busy
                    ? null
                    : () => _deleteAccount(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PicPacColors.accentText,
                  side: const BorderSide(color: PicPacColors.accentSoft),
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(l10n.profileDeleteAccount),
              ),
            ),
          ),
        ],
        const SizedBox(height: PicPacSpacing.lg),
        MinTapTarget(
          child: OutlinedButton.icon(
            onPressed: actions.busy ? null : () => _signOut(context, ref),
            icon: const Icon(Icons.logout),
            label: Text(l10n.actionLogout),
          ),
        ),
        const SizedBox(height: PicPacSpacing.xxl),
      ],
    );
  }

  Future<void> _deleteTestData(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context,
      title: l10n.profileDeleteTestDataTitle,
      body: l10n.profileDeleteTestDataBody,
      confirmLabel: l10n.actionRemove,
    );
    if (!confirmed) return;
    final count = await ref
        .read(accountActionsProvider.notifier)
        .deleteTestData();
    if (count == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.profileDeleteTestDataDone(count))),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final first = await _confirm(
      context,
      title: l10n.profileDeleteAccountStep1Title,
      body: l10n.profileDeleteAccountStep1Body,
      confirmLabel: l10n.actionContinue,
    );
    if (!first || !context.mounted) return;
    final second = await _confirm(
      context,
      title: l10n.profileDeleteAccountStep2Title,
      body: l10n.profileDeleteAccountStep2Body(
        customer.email ?? l10n.profileDeletedEmail,
      ),
      confirmLabel: l10n.profileDeleteAccountConfirm,
    );
    if (!second) return;
    final result = await ref
        .read(accountActionsProvider.notifier)
        .deleteAccount();
    switch (result) {
      case Ok<void>():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileDeleteAccountDone)),
        );
        _leaveProfile(router);
      case Err<void>(:final error):
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              error.code == ApiErrorCode.unauthorized
                  ? l10n.profileDeleteAccountFailed
                  : failureText(l10n, error),
            ),
          ),
        );
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final confirmed = await _confirm(
      context,
      title: l10n.logoutTitle,
      body: l10n.logoutBody,
      confirmLabel: l10n.logoutConfirm,
    );
    if (!confirmed) return;
    await ref.read(accountActionsProvider.notifier).signOut();
    messenger.showSnackBar(SnackBar(content: Text(l10n.logoutDone)));
    _leaveProfile(router);
  }

  static void _leaveProfile(GoRouter router) => router.go(AppRoutes.catalog);

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = customer.name?.trim() ?? '';
    final email = customer.email ?? '';
    final initial =
        (name.isNotEmpty
                ? name
                : email.isNotEmpty
                ? email
                : 'P')
            .characters
            .first
            .toUpperCase();
    return Row(
      children: <Widget>[
        ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: PicPacColors.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: theme.textTheme.titleMedium?.copyWith(
                color: PicPacColors.surface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: PicPacSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name.isNotEmpty ? name : (email.isNotEmpty ? email : 'PicPac'),
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (name.isNotEmpty && email.isNotEmpty)
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FunnelText.secondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: PicPacSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FunnelText.secondary,
                  ),
                ),
              ),
              const SizedBox(width: PicPacSpacing.md),
              Flexible(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          if (hint != null)
            Text(
              hint!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: FunnelText.secondary,
              ),
            ),
        ],
      ),
    );
  }
}
