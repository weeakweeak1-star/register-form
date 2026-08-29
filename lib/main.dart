import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'app_secrets.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_review_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/admin',
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/admin/review/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AdminReviewScreen(applicationId: id);
      },
    ),
  ],
  redirect: (context, state) {
    final session = supabase.auth.currentSession;
    final isGoingToAdmin = state.matchedLocation.startsWith('/admin');
    final isGoingToLogin = state.matchedLocation == '/admin';

    if (isGoingToAdmin) {
      if (session == null && !isGoingToLogin) {
        return '/admin';
      }
      if (session != null && isGoingToLogin) {
        return '/admin/dashboard';
      }
    }
    return null;
  },
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ادارة وياك',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D47A1),
        fontFamily: 'Tajawal',
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }
}
