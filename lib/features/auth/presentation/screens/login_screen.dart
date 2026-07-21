import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/context_ext.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (_, next) {
      next.whenData((user) async {
        if (user == null) return;
        if (user.isGuest) {
          if (context.mounted) context.go('/home');
          return;
        }
        final prefs = await SharedPreferences.getInstance();
        if (!context.mounted) return;
        final done = prefs.getBool('onboarding_done_${user.uid}') ?? false;
        context.go(done ? '/home' : '/onboarding');
      });
    });

    final tags = ['🚶 도보 235 kcal', '🍜 명동교자 520 kcal', '🏞 남산 둘레길', '🥓 삼겹살 −90분'];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              context.wp(6), context.hp(5), context.wp(6), context.hp(4)),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BrandLogo(size: context.wp(40)),
                    SizedBox(height: context.hp(3.5)),
                    Text(
                      '먹고 싶은 만큼,\n움직여요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.wp(7.5),
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        letterSpacing: -0.8,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: context.hp(1.8)),
                    Text(
                      '관광지 맛집과 활동량을 칼로리로 연결.\n같이 떠나볼까요?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.wp(3.5),
                        color: c.textMuted,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: context.hp(3)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: tags.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: c.outline),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: context.wp(3),
                            fontWeight: FontWeight.w600,
                            color: c.textMuted,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  AppButton(
                    label: authState.isLoading ? '로그인 중...' : '이메일로 시작하기',
                    onPressed: authState.isLoading
                        ? () {}
                        : () => context.push('/signup'),
                    variant: ButtonVariant.primary,
                    fullWidth: true,
                  ),
                  if (authState.hasError) ...[
                    SizedBox(height: context.hp(1)),
                    Text(
                      '로그인 중 오류가 발생했습니다. 다시 시도해주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.wp(3),
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  SizedBox(height: context.hp(1.5)),
                  SizedBox(height: context.hp(0.5)),
                  GestureDetector(
                    onTap: () => _showPassLoginDialog(context, ref),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: context.hp(0.8)),
                      child: Text(
                        '로그인 없이 둘러보기',
                        style: TextStyle(
                          fontSize: context.wp(3.2),
                          color: c.textMuted,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: c.textMuted,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.hp(0.5)),
                  Text(
                    '가입 시 서비스 이용약관과 개인정보 처리방침에 동의한 것으로 간주됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: context.wp(2.8),
                      color: c.textFaint,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showPassLoginDialog(BuildContext context, WidgetRef ref) {
  final c = context.colors;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '로그인 없이 계속할까요?',
        style: TextStyle(
          color: c.text,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      content: Text(
        '회원가입 없이도 앱을 사용할 수 있어요.\n단, 활동 기록이 저장되지 않고\n추정 칼로리로 계산됩니다.',
        style: TextStyle(
          color: c.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            '로그인하기',
            style: TextStyle(
              color: c.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            ref.read(authStateProvider.notifier).passLogin();
          },
          child: Text(
            '계속하기',
            style: TextStyle(
              color: c.primary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}
