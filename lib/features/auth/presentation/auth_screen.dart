import 'package:flutter/material.dart';

typedef LoginSubmit = Future<void> Function(
  String identifier,
  String password,
);
typedef RegisterSubmit = Future<void> Function({
  required String username,
  required String email,
  required String password,
  required String displayName,
});

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
    this.isBusy = false,
    this.errorMessage,
  });

  final LoginSubmit onLogin;
  final RegisterSubmit onRegister;
  final bool isBusy;
  final String? errorMessage;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _registering = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.isBusy || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_registering) {
      await widget.onRegister(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
      );
    } else {
      await widget.onLogin(
        _identifierController.text.trim(),
        _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.forum_rounded,
                        size: 38,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'فايكو',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _registering
                          ? 'أنشئ حسابك وابدأ التواصل'
                          : 'سجّل دخولك حتى تتابع منشوراتك',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 28),
                    if (_registering) ...[
                      TextFormField(
                        key: const ValueKey('display-name'),
                        controller: _displayNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الظاهر',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'اكتب الاسم الظاهر';
                          }
                          if (value!.trim().length > 60) {
                            return 'الاسم طويل جداً';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const ValueKey('username'),
                        controller: _usernameController,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (value) {
                          final username = (value ?? '').trim();
                          if (username.length < 3 || username.length > 24) {
                            return 'اسم المستخدم من 3 إلى 24 حرفاً';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
                            return 'استخدم الأحرف الإنجليزية والأرقام والشرطة السفلية';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const ValueKey('email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = (value ?? '').trim();
                          if (!email.contains('@') ||
                              email.length < 5 ||
                              email.length > 254) {
                            return 'اكتب بريداً إلكترونياً صحيحاً';
                          }
                          return null;
                        },
                      ),
                    ] else
                      TextFormField(
                        key: const ValueKey('identifier'),
                        controller: _identifierController,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم أو البريد الإلكتروني',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().length < 3) {
                            return 'اكتب اسم المستخدم أو البريد الإلكتروني';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('password'),
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'إخفاء كلمة المرور'
                              : 'إظهار كلمة المرور',
                          onPressed: () {
                            setState(() => _showPassword = !_showPassword);
                          },
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 10) {
                          return 'كلمة المرور لازم تكون 10 أحرف على الأقل';
                        }
                        if (RegExp(r'^.{73,}$', dotAll: true)
                            .hasMatch(value ?? '')) {
                          return 'كلمة المرور طويلة جداً';
                        }
                        return null;
                      },
                    ),
                    if (widget.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.errorMessage!,
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: widget.isBusy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: widget.isBusy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _registering ? 'إنشاء الحساب' : 'تسجيل الدخول',
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.isBusy
                          ? null
                          : () => setState(() {
                                _registering = !_registering;
                              }),
                      child: Text(
                        _registering
                            ? 'عندي حساب — تسجيل الدخول'
                            : 'ما عندي حساب — إنشاء حساب جديد',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يتم حفظ رمز الدخول على الجهاز بصورة آمنة.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
