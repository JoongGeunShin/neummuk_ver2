import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/email_signup_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/mode_b/presentation/screens/mode_b_search_screen.dart';
import '../../features/event/presentation/screens/event_detail_screen.dart';
import '../../features/restaurant/presentation/screens/restaurant_detail_screen.dart';
import '../../features/explore/presentation/screens/explore_screen.dart';
import '../../features/record/presentation/screens/my_record_screen.dart';
import '../../features/user/presentation/screen/user_info_screen.dart';
import '../../features/user/presentation/screen/user_edit_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (_, __) => const EmailSignupScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomeScreen(),
    ),
    // 통합 지도 화면: 탐색·모드A·모드B 전부 여기서 처리
    GoRoute(
      path: '/map',
      builder: (_, __) => const UnifiedMapScreen(),
    ),
    GoRoute(
      path: '/explore',
      builder: (_, __) => const ExploreScreen(),
    ),
    GoRoute(
      path: '/mode-b',
      builder: (_, __) => const ModeBSearchScreen(),
    ),
    GoRoute(
      path: '/event/:contentId',
      builder: (_, state) => EventDetailScreen(
        contentId: state.pathParameters['contentId']!,
        fallbackImageUrl: state.extra as String?,
      ),
    ),
    GoRoute(
      path: '/restaurant/:id',
      builder: (_, state) =>
          RestaurantDetailScreen(restaurantId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/record',
      builder: (_, __) => const MyRecordScreen(),
    ),
    GoRoute(
      path: '/user',
      builder: (_, __) => const UserInfoScreen(),
    ),
    GoRoute(
      path: '/user/edit',
      builder: (_, __) => const UserEditScreen(),
    )
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}',
          style: const TextStyle(color: Colors.white70)),
    ),
  ),
);
