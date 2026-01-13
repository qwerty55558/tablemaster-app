import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/websocket_service.dart';
import 'providers/providers.dart';
import 'pages/welcome_page.dart';
import 'theme/app_colors.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await ApiService().initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  AuthStatus _previousStatus = AuthStatus.initializing;

  @override
  void initState() {
    super.initState();
    _previousStatus = ApiService().authService.status;

    // 이미 인증된 상태면 WebSocket 연결
    if (_previousStatus == AuthStatus.authenticated) {
      WebSocketService().connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 인증 상태 구독
    ref.listen<AsyncValue<AuthStatus>>(authStatusProvider, (previous, next) {
      next.whenData((status) {
        _onAuthStatusChange(status);
      });
    });

    final authStatus = ref.watch(currentAuthStatusProvider);

    return ShadcnApp(
      navigatorKey: navigatorKey,
      title: 'TableMaster',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(colorScheme: LegacyColorSchemes.darkZinc(), radius: 0.5),
      home: WelcomePage(authStatus: authStatus),
    );
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
}
