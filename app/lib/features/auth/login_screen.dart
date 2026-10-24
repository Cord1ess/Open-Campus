import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/brand_logo.dart';
import '../../shared/widgets.dart';
import '../about/about_page.dart';
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

  void _openSettings() {
    Navigator.of(context).push(appRoute(const AboutPage()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final canvas = context.palette.canvas;
    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: canvas,
        actions: [
          IconButton(
            onPressed: _openSettings,
            tooltip: 'Settings',
            icon: const Icon(AppIcons.settings),
          ),
          const SizedBox(width: Spacing.sm),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _StaggerColumn(
              children: [
                const Center(child: BrandLogo(height: 56)),
                const SizedBox(height: Spacing.xl),
                Text('Sign in with your UCAM account',
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Use the same student ID and password as the UCAM portal.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: Spacing.xl),
                TextField(
                  controller: _id,
                  decoration: const InputDecoration(
                    labelText: 'Student ID',
                    prefixIcon: Icon(AppIcons.id),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: Spacing.lg),
                TextField(
                  controller: _pw,
                  obscureText: _obscure,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(AppIcons.locked),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(_obscure
                          ? AppIcons.visibility
                          : AppIcons.visibilityOff),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: Spacing.sm),
                // Remember-me: saves credentials on THIS device only, for 30
                // days. No server involvement.
                CheckboxListTile(
                  value: _remember,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _remember = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Keep me signed in on this device for 30 days',
                    style: context.text.bodySmall,
                  ),
                ),
                AnimatedSize(
                  duration: Motion.fast,
                  alignment: Alignment.topCenter,
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: Spacing.sm),
                          child: InfoNote(
                            text: _error!,
                            tone: StatusTone.danger,
                            icon: AppIcons.error,
                          ),
                        ),
                ),
                const SizedBox(height: Spacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExpressiveLoader(
                                size: 20, color: scheme.onSurfaceVariant),
                            const SizedBox(width: Spacing.sm),
                            const Text('Signing in…'),
                          ],
                        )
                      : const Text('Sign in'),
                ),
                AnimatedSize(
                  duration: Motion.fast,
                  alignment: Alignment.topCenter,
                  child: !_slowHint
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: Spacing.md),
                          child: Text(
                            'Waking up the server — the first sign-in after a '
                            'while can take up to a minute.',
                            textAlign: TextAlign.center,
                            style: context.text.bodySmall,
                          ),
                        ),
                ),
                const SizedBox(height: Spacing.xl),
                Text(
                  'Your data is fetched live from your own UCAM account. Your '
                  'password is never stored and nothing is kept on our servers. '
                  'Open Campus is an independent, unofficial app.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A stretched column whose content rises in one item after another (spacers
/// are passed through untouched so the stagger follows the visible blocks).
class _StaggerColumn extends StatelessWidget {
  final List<Widget> children;
  const _StaggerColumn({required this.children});

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in children)
          c is SizedBox ? c : Reveal(index: i++, child: c),
      ],
    );
  }
}
