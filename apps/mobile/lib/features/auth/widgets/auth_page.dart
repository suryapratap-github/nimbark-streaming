import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/models/auth_session.dart';
import '../services/auth_api.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.authApi,
    required this.onAuthenticated,
    super.key,
  });

  final AuthApi authApi;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isRegister = false;
  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    try {
      final session = _isRegister
          ? await widget.authApi.register(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              displayName: _displayNameController.text.trim(),
              username: _usernameController.text.trim(),
            )
          : await widget.authApi.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );

      widget.onAuthenticated(session);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController =
        TextEditingController(text: _emailController.text.trim());
    final tokenController = TextEditingController();
    final newPasswordController = TextEditingController();
    var isRequesting = false;
    var isResetting = false;
    var resetMessage = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> requestReset() async {
              final email = emailController.text.trim();

              if (email.isEmpty || isRequesting) {
                return;
              }

              setDialogState(() {
                isRequesting = true;
                resetMessage = '';
              });

              try {
                final result =
                    await widget.authApi.forgotPassword(email: email);

                setDialogState(() {
                  resetMessage = result.message;
                  if (result.resetToken != null) {
                    tokenController.text = result.resetToken!;
                    resetMessage =
                        '${result.message} Reset code filled for local development.';
                  }
                });
              } catch (error) {
                setDialogState(() => resetMessage = error.toString());
              } finally {
                setDialogState(() => isRequesting = false);
              }
            }

            Future<void> resetPassword() async {
              final token = tokenController.text.trim();
              final password = newPasswordController.text;

              if (token.isEmpty || password.length < 8 || isResetting) {
                setDialogState(() => resetMessage =
                    'Enter the reset code and a password of at least 8 characters.');
                return;
              }

              setDialogState(() {
                isResetting = true;
                resetMessage = '';
              });

              try {
                final message = await widget.authApi.resetPassword(
                  token: token,
                  password: password,
                );

                if (!context.mounted) {
                  return;
                }

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              } catch (error) {
                setDialogState(() => resetMessage = error.toString());
              } finally {
                setDialogState(() => isResetting = false);
              }
            }

            return AlertDialog(
              title: const Text('Reset password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isRequesting ? null : requestReset,
                      icon: isRequesting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.key_outlined),
                      label: const Text('Get reset code'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Reset code',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (resetMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(resetMessage),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isResetting ? null : resetPassword,
                  child: Text(isResetting ? 'Resetting' : 'Reset password'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    tokenController.dispose();
    newPasswordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF08090D),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.2,
            colors: [
              Color(0x5533E0C5),
              Color(0x332D132F),
              Color(0xFF08090D),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withAlpha(220),
                        border: Border.all(
                          color: colorScheme.outline.withAlpha(36),
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 44,
                            offset: Offset(0, 24),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    height: 52,
                                    width: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFF4B35),
                                          Color(0xFF7C3AED),
                                          Color(0xFF00A6A6),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x55FF4B35),
                                          blurRadius: 20,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: colorScheme.onPrimary,
                                      size: 34,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Nimbark',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _isRegister
                                              ? 'Create your creator-ready account'
                                              : 'Welcome back to your feed',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Login'),
                                    icon: Icon(Icons.login),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('Register'),
                                    icon: Icon(
                                      Icons.person_add_alt_1_outlined,
                                    ),
                                  ),
                                ],
                                selected: {_isRegister},
                                onSelectionChanged: (selection) {
                                  setState(() {
                                    _error = null;
                                    _isRegister = selection.first;
                                  });
                                },
                              ),
                              const SizedBox(height: 18),
                              if (_isRegister) ...[
                                TextFormField(
                                  controller: _displayNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Display name',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Username',
                                    prefixIcon: Icon(Icons.alternate_email),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextFormField(
                                controller: _emailController,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: _required,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                autofillHints: const [AutofillHints.password],
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _isPasswordVisible =
                                          !_isPasswordVisible,
                                    ),
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                                obscureText: !_isPasswordVisible,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (value) {
                                  if (value == null || value.length < 8) {
                                    return 'Password must be at least 8 characters';
                                  }
                                  return null;
                                },
                              ),
                              if (!_isRegister) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : _showForgotPasswordDialog,
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: _isSubmitting ? null : _submit,
                                icon: _isSubmitting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _isRegister
                                            ? Icons.person_add_alt_1_outlined
                                            : Icons.login,
                                      ),
                                label: Text(
                                  _isSubmitting
                                      ? 'Please wait'
                                      : _isRegister
                                          ? 'Create account'
                                          : 'Login',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }
}
