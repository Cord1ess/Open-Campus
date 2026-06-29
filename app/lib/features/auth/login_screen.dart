import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/brand_logo.dart';
import '../../shared/widgets.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? message;
  const LoginScreen({super.key, this.message});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _remember = false;
  bool _slowHint = false;
  Timer? _slowTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.message;
    _prefillSaved();
    // Warm the backend while the user types — a sleeping free-tier server then
    // has a head start and the actual login isn't waiting on a cold boot.
    ref.read(apiClientProvider).warmUp();
  }

  /// If the user previously opted to remember their login (on-device, ≤30 days),
  /// prefill the fields and keep the checkbox ticked.
  Future<void> _prefillSaved() async {
    final saved = await ref.read(credentialStoreProvider).read();
    if (saved != null && mounted) {
      setState(() {
        _id.text = saved.id;
        _pw.text = saved.password;
        _remember = true;
      });
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_id.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() => _error = 'Enter your student ID and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _slowHint = false;
    });
    // If login is taking a while, reassure the user it's a cold start, not a hang.
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _busy) setState(() => _slowHint = true);
    });
    final err = await ref
        .read(authControllerProvider.notifier)
        .login(_id.text.trim(), _pw.text, remember: _remember);
    _slowTimer?.cancel();
    if (mounted) {
      setState(() {
        _busy = false;
        _slowHint = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Scaffold(
      body: Stack(
        children: [
          // Soft tonal backdrop.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [scheme.primaryContainer, scheme.surface],
                stops: const [0, 0.45],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SpringIn(child: BrandLogo(size: 96)),
                    const SizedBox(height: Spacing.sm),
                    Text('Sign in with your UCAM account',
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: Spacing.xxl),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.lg),
                        child: Column(
                          children: [
                            TextField(
                              controller: _id,
                              decoration: const InputDecoration(
                                labelText: 'Student ID',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              keyboardType: TextInputType.number,
                              enabled: !_busy,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: Spacing.md),
                            TextField(
                              controller: _pw,
                              obscureText: _obscure,
                              enabled: !_busy,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: Spacing.xs),
                            // Remember-me: saves credentials on THIS device only,
                            // for 30 days. No server involvement.
                            InkWell(
                              borderRadius: BorderRadius.circular(Radii.sm),
                              onTap: _busy
                                  ? null
                                  : () =>
                                      setState(() => _remember = !_remember),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: Spacing.xs),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _remember,
                                      onChanged: _busy
                                          ? null
                                          : (v) => setState(
                                              () => _remember = v ?? false),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const SizedBox(width: Spacing.xs),
                                    Expanded(
                                      child: Text(
                                        'Keep me signed in on this device for 30 days',
                                        style: context.text.bodySmall?.copyWith(
                                            color: context
                                                .scheme.onSurfaceVariant),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AnimatedSize(
                              duration: Motion.fast,
                              child: _error == null
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(
                                          top: Spacing.md),
                                      child: _ErrorBanner(_error!),
                                    ),
                            ),
                            const SizedBox(height: Spacing.lg),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: Text(_busy ? 'Signing in…' : 'Sign in'),
                            ),
                            AnimatedSize(
                              duration: Motion.fast,
                              child: !_slowHint
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(
                                          top: Spacing.md),
                                      child: Text(
                                        'Waking up the server — first sign-in '
                                        'after a while can take up to a minute.',
                                        textAlign: TextAlign.center,
                                        style: context.text.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: Spacing.xl),
                    Text(
                      'A cleaner, faster window into UCAM. Your data is fetched '
                      'live from your own account — your password is never stored, '
                      'and nothing is kept on our servers. Open Campus is an '
                      'independent, unofficial app.',
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: context.status.badContainer,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: context.status.bad, size: 18),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(text,
                style: TextStyle(color: context.status.bad, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
