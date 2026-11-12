import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/env.dart';
import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/presentation/failure_text.dart';
import '../../../core/presentation/text_tones.dart';
import '../application/login_controller.dart';
import '../../../core/presentation/a11y.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({this.next, super.key});

  final String? next;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final outcome = await ref
        .read(loginControllerProvider.notifier)
        .register(
          name: email.split('@').first,
          email: email,
          password: _password.text,
        );
    if (!mounted) return;
    final session = outcome.session;
    if (session == null) {
      final failure = ref.read(loginControllerProvider).failure;
      if (failure != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(failureText(l10n, failure))));
      }
      return;
    }
    context.go(AppRoutes.safeNext(widget.next) ?? AppRoutes.catalog);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final outcome = await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text, code: _code.text);
    if (!mounted) return;
    final session = outcome.session;
    if (session == null) {
      return;
    }
    final target = session.isSupportAgent
        ? AppRoutes.support
        : AppRoutes.safeNext(widget.next) ?? AppRoutes.catalog;
    if (session.isSupportAgent) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.loginSupportWelcome)));
    }
    context.go(target);
  }

  void _fillDemo({required bool support}) {
    setState(() {
      _email.text = support ? 'support@picpac.test' : 'customer@picpac.test';
      _password.text = 'Test1234';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(loginControllerProvider);
    final isDev = ref.watch(envProvider).flavor != AppFlavor.prod;
    final codeMode = state.mode == LoginMode.code;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(PicPacSpacing.xl),
              children: <Widget>[
                Center(
                  child: Semantics(
                    label: l10n.appTitle,
                    image: true,
                    child: Image.asset(
                      'assets/brand/logo-coral-alpha.png',
                      height: 56,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                const SizedBox(height: PicPacSpacing.lg),
                Text(
                  l10n.loginPromise,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge,
                ),
                const SizedBox(height: PicPacSpacing.sm),
                const SizedBox(height: PicPacSpacing.xl),
                SegmentedButton<LoginMode>(
                  segments: <ButtonSegment<LoginMode>>[
                    ButtonSegment<LoginMode>(
                      value: LoginMode.password,
                      label: Text(l10n.loginPasswordMode),
                      icon: const Icon(Icons.password),
                    ),
                    ButtonSegment<LoginMode>(
                      value: LoginMode.code,
                      label: Text(l10n.loginCodeMode),
                      icon: const Icon(Icons.mark_email_read_outlined),
                    ),
                  ],
                  selected: <LoginMode>{state.mode},
                  onSelectionChanged: (selection) => ref
                      .read(loginControllerProvider.notifier)
                      .setMode(selection.first),
                ),
                const SizedBox(height: PicPacSpacing.xl),
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextFormField(
                        key: const Key('login-email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const <String>[AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.loginEmailLabel,
                          hintText: l10n.loginEmailHint,
                        ),
                        validator: (value) =>
                            _validEmail(value) ? null : l10n.loginEmailInvalid,
                      ),
                      const SizedBox(height: PicPacSpacing.md),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: state.busy ? null : _register,
                      child: Text(l10n.loginRegisterAction),
                    ),
                  ),

                      if (!codeMode)
                        TextFormField(
                          key: const Key('login-password'),
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const <String>[AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: l10n.loginPasswordLabel,
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? l10n.loginPasswordHidden
                                  : l10n.loginPasswordShown,
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? l10n.loginPasswordRequired
                              : null,
                        )
                      else if (state.codeRequested)
                        TextFormField(
                          key: const Key('login-code'),
                          controller: _code,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          autofillHints: const <String>[
                            AutofillHints.oneTimeCode,
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.loginCodeLabel,
                            hintText: l10n.loginCodeHint,
                            counterText: '',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? l10n.loginCodeInvalid
                              : null,
                        ),
                    ],
                  ),
                ),
                if (codeMode && !state.codeRequested) ...<Widget>[
                  const SizedBox(height: PicPacSpacing.md),
                  OutlinedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        ref
                            .read(loginControllerProvider.notifier)
                            .requestCode();
                      }
                    },
                    child: Text(l10n.loginSendCode),
                  ),
                ],
                if (codeMode && state.codeRequested) ...<Widget>[
                  const SizedBox(height: PicPacSpacing.md),
                  _InfoNote(
                    text: l10n.loginCodeSent(
                      _email.text.trim().isEmpty
                          ? 'customer@picpac.test'
                          : _email.text.trim(),
                    ),
                    icon: Icons.mark_email_read_outlined,
                  ),
                  const SizedBox(height: PicPacSpacing.sm),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.loginCodeDemo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: FunnelText.secondary,
                      ),
                    ),
                  ),
                ],
                if (state.failure != null) ...<Widget>[
                  const SizedBox(height: PicPacSpacing.lg),
                  _LoginError(failure: state.failure!),
                ],
                const SizedBox(height: PicPacSpacing.xl),
                if (!codeMode || state.codeRequested)
                  MinTapTarget(
                    child: FilledButton(
                      onPressed: state.busy ? null : _submit,
                      child: state.busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.loginSubmit),
                    ),
                  ),
                const SizedBox(height: PicPacSpacing.md),
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => context.canPop()
                            ? context.pop()
                            : context.go(AppRoutes.catalog),
                  child: Text(l10n.loginGuestContinue),
                ),
                MinTapTarget(
                  child: InkWell(
                    onTap: state.busy
                        ? null
                        : () => context.push(AppRoutes.orderLookup),
                    borderRadius: BorderRadius.circular(PicPacRadii.field),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: PicPacSpacing.md,
                        horizontal: PicPacSpacing.sm,
                      ),
                      child: Text(
                        l10n.loginLookup,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: FunnelText.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
                if (isDev) ...<Widget>[
                  const SizedBox(height: PicPacSpacing.xl),
                  _DemoAccess(
                    onCustomer: () => _fillDemo(support: false),
                    onSupport: () => _fillDemo(support: true),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _validEmail(String? value) {
    final email = value?.trim() ?? '';
    final at = email.indexOf('@');
    return at > 0 && at < email.length - 3 && email.contains('.', at);
  }
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unauthorized = failure.code == ApiErrorCode.unauthorized;
    final message = unauthorized
        ? l10n.loginInvalidCredentials
        : failure.code == ApiErrorCode.notFound
        ? l10n.loginCodeExpired
        : failureText(l10n, failure);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(PicPacSpacing.md),
        decoration: BoxDecoration(
          color: PicPacColors.accentSoft,
          borderRadius: BorderRadius.circular(PicPacRadii.field),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.error_outline,
              size: 20,
              color: PicPacColors.accentText,
            ),
            const SizedBox(width: PicPacSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(PicPacSpacing.md),
    decoration: BoxDecoration(
      color: PicPacColors.fillBeige,
      borderRadius: BorderRadius.circular(PicPacRadii.field),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: PicPacColors.ink),
        const SizedBox(width: PicPacSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class _DemoAccess extends StatelessWidget {
  const _DemoAccess({required this.onCustomer, required this.onSupport});

  final VoidCallback onCustomer;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.loginDemoTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: PicPacSpacing.xs),
        Text(
          l10n.loginDemoHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: FunnelText.secondary,
          ),
        ),
        const SizedBox(height: PicPacSpacing.sm),
        for (final entry in <(String, VoidCallback)>[
          (l10n.loginDemoCustomer, onCustomer),
          (l10n.loginDemoSupport, onSupport),
        ])
          InkWell(
            onTap: entry.$2,
            borderRadius: BorderRadius.circular(PicPacRadii.field),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: PicPacSpacing.md,
                horizontal: PicPacSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.content_copy, size: 18),
                  const SizedBox(width: PicPacSpacing.sm),
                  Expanded(
                    child: Text(entry.$1, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
