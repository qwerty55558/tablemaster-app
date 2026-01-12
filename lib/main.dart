import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/websocket_service.dart';
import 'pages/welcome_page.dart';
import 'theme/app_colors.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await ApiService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthStatus>? _authSubscription;
  AuthStatus _previousStatus = AuthStatus.initializing;

  @override
  void initState() {
    super.initState();
    _previousStatus = ApiService().authService.status;
    _authSubscription = ApiService().authService.statusStream.listen(_onAuthStatusChange);

    // 이미 인증된 상태면 WebSocket 연결
    if (_previousStatus == AuthStatus.authenticated) {
      WebSocketService().connect();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onAuthStatusChange(AuthStatus status) {
    print('[AUTH] 상태 변경: $_previousStatus → $status');

    // 인증 성공 → WebSocket 연결
    if (status == AuthStatus.authenticated) {
      print('[AUTH] WebSocket 연결 시도');
      WebSocketService().connect();
    }

    // 인증됨 → 미등록/실패로 변경된 경우 처리
    if (_previousStatus == AuthStatus.authenticated &&
        (status == AuthStatus.unregistered || status == AuthStatus.failed)) {
      print('[AUTH] 인증 해제 감지 → _handleAuthLost 호출');
      _handleAuthLost(status);
    }
    _previousStatus = status;
  }

  void _handleAuthLost(AuthStatus status) {
    // WebSocket 연결 종료
    WebSocketService().disconnect();

    final context = navigatorKey.currentContext;
    if (context == null) return;

    // 토스트 표시
    showToast(
      context: context,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: const Text('연결 끊김'),
          subtitle: Text(
            status == AuthStatus.unregistered
                ? '디바이스 등록이 해제되었습니다'
                : ApiService().authService.errorMessage ?? '서버 연결이 끊어졌습니다',
          ),
          leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        ),
      ),
    );

    // 웰컴 페이지로 이동
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      navigatorKey: navigatorKey,
      title: 'TableMaster',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(colorScheme: LegacyColorSchemes.darkZinc(), radius: 0.5),
      home: StreamBuilder<AuthStatus>(
        stream: ApiService().authService.statusStream,
        initialData: ApiService().authService.status,
        builder: (context, snapshot) {
          return WelcomePage(
            authStatus: snapshot.data ?? AuthStatus.initializing,
          );
        },
      ),
    );
  }
}
