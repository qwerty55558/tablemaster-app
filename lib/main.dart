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

  const bool isProd = bool.fromEnvironment('IS_PROD', defaultValue: false);
  final envFile = isProd ? '.env.production' : '.env.development';
  await dotenv.load(fileName: envFile);

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

    // 백그라운드에서 초기화 (UI 블로킹 없음)
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final apiService = ApiService();
    final connected = await apiService.initialize();

    if (connected) {
      // 내 테이블 복원 (Riverpod)
      final myTable = await apiService.getMyTable();
      ref.read(currentTableProvider.notifier).update(myTable);

      // WebSocket 연결
      WebSocketService().connect();

      // tablesProvider 즉시 초기화 (브로드캐스트 리스너 활성화)
      ref.read(tablesProvider);
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
    // 같은 상태로 중복 호출 무시
    if (status == _previousStatus) return;
    print('[AUTH] 상태 변경: $_previousStatus → $status');

    // 인증 성공 → WebSocket 연결 + 내 테이블 동기화
    if (status == AuthStatus.authenticated) {
      print('[AUTH] WebSocket 연결 시도');
      WebSocketService().connect().then((_) async {
        final table = await ApiService().getMyTable();
        ref.read(currentTableProvider.notifier).update(table);
        ref.read(tablesProvider); // 브로드캐스트 리스너 활성화
        print('[AUTH] 내 테이블 동기화: ${table?.id ?? 'null'}');
      });
    }

    // 연결 끊김 (일시적) → 데이터 유지, 재연결 대기
    if (status == AuthStatus.connectionLost) {
      print('[AUTH] 연결 끊김 → 데이터 유지, 재연결 대기');
      _previousStatus = status;
      return;
    }

    // 인증됨 → 미등록/실패로 변경된 경우 처리 (영구적 인증 해제)
    if (_previousStatus == AuthStatus.authenticated &&
        (status == AuthStatus.unregistered || status == AuthStatus.failed)) {
      print('[AUTH] 인증 해제 감지 → _handleAuthLost 호출');
      _handleAuthLost(status);
    }

    // connectionLost → authenticated 복구 시 동기화
    if (_previousStatus == AuthStatus.connectionLost &&
        status == AuthStatus.authenticated) {
      print('[AUTH] 연결 복구 → WebSocket 재연결 + 동기화');
      WebSocketService().connect().then((_) async {
        final table = await ApiService().getMyTable();
        ref.read(currentTableProvider.notifier).update(table);
        print('[AUTH] 재연결 후 테이블 동기화: ${table?.id ?? 'null'}');
      });
    }

    _previousStatus = status;
  }

  void _handleAuthLost(AuthStatus status) {
    // WebSocket 연결 종료
    WebSocketService().disconnect();

    // 테이블 상태 초기화 (Riverpod)
    ref.read(currentTableProvider.notifier).clear();

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
