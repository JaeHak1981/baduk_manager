import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/academy_provider.dart';
import 'providers/student_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/order_provider.dart';
import 'utils/seed_data.dart';

import 'screens/login_screen.dart';
import 'screens/home_page.dart';

import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 초기 데이터 시딩 (개발용) - 비동기로 실행하여 UI 차단 방지
  seedTextbooks();

  Intl.defaultLocale = 'ko_KR';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AcademyProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],

      child: MaterialApp(
        title: '바둑 학원 관리',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown,
          },
        ),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
        locale: const Locale('ko', 'KR'),
        home: const AuthWrapper(),
      ),
    );
  }
}

/// 인증 상태에 따라 화면을 분기하는 위젯
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // 로딩 중일 때
    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 인증 상태에 따라 화면 분기
    if (authProvider.isAuthenticated) {
      return const HomePage();
    } else {
      return const LoginScreen();
    }
  }
}
