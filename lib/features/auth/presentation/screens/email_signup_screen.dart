import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class EmailSignupScreen extends ConsumerStatefulWidget {
  const EmailSignupScreen({super.key});

  @override
  ConsumerState<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends ConsumerState<EmailSignupScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(authStateProvider, (_, next) {
      next.whenData((user) async {
        if (user == null || user.isGuest || !mounted) return;
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        final done = prefs.getBool('onboarding_done_${user.uid}') ?? false;
        context.go(done ? '/home' : '/onboarding');
      });
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(authStateProvider.notifier).signInWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
  }

  String _errorMessage(Object? error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
          return '비밀번호가 올바르지 않습니다.';
        case 'email-already-in-use':
          return '이미 가입된 이메일입니다.';
        case 'invalid-email':
          return '올바른 이메일 형식이 아닙니다.';
        case 'weak-password':
          return '비밀번호는 6자 이상이어야 합니다.';
        case 'network-request-failed':
          return '네트워크 연결을 확인해주세요.';
        case 'too-many-requests':
          return '잠시 후 다시 시도해주세요.';
        case 'invalid-credential':
          return '이메일 또는 비밀번호를 확인해주세요.';
        default:
          return '오류가 발생했습니다. (${error.code})';
      }
    }
    return '오류가 발생했습니다. 다시 시도해주세요.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: c.text, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '이메일로 시작하기',
          style: TextStyle(
            color: c.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              context.wp(6), context.hp(3), context.wp(6), context.hp(4)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이메일 주소',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.textMuted,
                  ),
                ),
                SizedBox(height: context.hp(0.8)),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: c.text, fontSize: 15),
                  decoration: _inputDecoration(c, '이메일을 입력하세요'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '이메일을 입력하세요';
                    if (!v.contains('@')) return '올바른 이메일 형식이 아닙니다'; // 현재 실제 메일주소는 사용 안함 (gmail.com)
                    return null;
                  },
                ),
                SizedBox(height: context.hp(2.5)),
                Text(
                  '비밀번호',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.textMuted,
                  ),
                ),
                SizedBox(height: context.hp(0.8)),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: TextStyle(color: c.text, fontSize: 15),
                  decoration: _inputDecoration(c, '비밀번호를 입력하세요').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: c.textMuted,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '비밀번호를 입력하세요';
                    if (v.length < 6) return '비밀번호는 6자 이상이어야 합니다';
                    return null;
                  },
                ),
                SizedBox(height: context.hp(1)),
                Text(
                  '처음 사용하시면 자동으로 가입됩니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textFaint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                AppButton(
                  label: authState.isLoading ? '처리 중...' : '로그인 / 가입하기',
                  onPressed: authState.isLoading ? () {} : _submit,
                  variant: ButtonVariant.primary,
                  fullWidth: true,
                ),
                if (authState.hasError) ...[
                  SizedBox(height: context.hp(1.5)),
                  Text(
                    _errorMessage(authState.error),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(dynamic c, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.textFaint, fontSize: 15),
      filled: true,
      fillColor: c.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }
}
