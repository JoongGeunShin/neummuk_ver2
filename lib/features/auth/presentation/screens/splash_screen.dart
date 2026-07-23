import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';
import '../../../map/presentation/providers/map_mode_provider.dart';
import '../../../mode_a/presentation/providers/mode_a_nav_provider.dart';
import '../../../mode_a/presentation/providers/mode_a_provider.dart';
import '../../../mode_b/presentation/providers/mode_b_nav_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  bool _timerDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    Future.delayed(const Duration(milliseconds: 2500), _onTimerDone);
  }

  void _onTimerDone() {
    if (!mounted) return;
    _timerDone = true;
    final auth = ref.read(authStateProvider);
    if (!auth.isLoading) _doRoute(auth.valueOrNull);
  }

  Future<void> _doRoute(UserEntity? user) async {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (user == null) {
      context.go('/login');
      return;
    }
    if (user.isGuest) {
      if (await _restoreNavIfAny()) return;
      context.go('/home');
      return;
    }
    final done = await resolveOnboardingDone(ref, user);
    if (!mounted) return;
    if (!done) {
      context.go('/onboarding');
      return;
    }
    if (await _restoreNavIfAny()) return;
    context.go('/home');
  }

  /// Mode A → Mode B 순서로 안내 중이던 내비게이션 복원을 시도한다. 복원에 성공하면
  /// 곧바로 /map으로 이동시키고 true를 반환(호출측은 그대로 return하면 됨).
  Future<bool> _restoreNavIfAny() async {
    if (await _tryRestoreModeANav()) {
      if (!mounted) return true;
      ref.read(mapModeProvider.notifier).set(MapMode.modeA);
      context.go('/map');
      return true;
    }
    if (await _tryRestoreModeBNav()) {
      if (!mounted) return true;
      ref.read(mapModeProvider.notifier).set(MapMode.modeB);
      context.go('/map');
      return true;
    }
    return false;
  }

  /// Mode A는 route 지오메트리를 저장하지 않으므로(mode_a_nav_provider.dart 참고),
  /// 저장된 출발/도착/경유지/이동수단으로 search()를 다시 호출해 경로를 재계산해야
  /// 복원이 완성된다 — 네트워크 호출이 필요해 Mode B보다 한 단계 더 거친다.
  Future<bool> _tryRestoreModeANav() async {
    try {
      final savedNav = await ModeANav.tryRestoreFromPrefs();
      if (savedNav == null || !mounted) return false;
      await ref.read(modeAProvider.notifier).restoreFromPrefs();
      if (!mounted) return false;
      final s = ref.read(modeAProvider);
      if (s.originLat == null || s.destLat == null) return false;
      await ref.read(modeAProvider.notifier).search();
      if (!mounted || ref.read(modeAProvider).routeResult == null) return false;
      ref.read(modeANavProvider.notifier).restore(savedNav);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryRestoreModeBNav() async {
    try {
      final savedState = await ModeBNav.tryRestoreFromPrefs();
      if (savedState == null || !mounted) return false;
      ref.read(modeBNavProvider.notifier).restore(savedState);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserEntity?>>(authStateProvider, (_, next) {
      if (_timerDone && !next.isLoading) _doRoute(next.valueOrNull);
    });

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1E),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/app_icon.png',
                width: size.width * 0.28,
                height: size.width * 0.28,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 28),
              const Text(
                '내움먹',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '내가 움직이는 이유는, 먹기 위해서',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 48),
              const _LoadingDots(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF7A45).withValues(alpha: opacity),
              ),
            );
          },
        );
      }),
    );
  }
}
