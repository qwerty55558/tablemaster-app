import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/websocket_service.dart';
import 'providers/providers.dart';
import 'models/table_model.dart';
import 'pages/matching_page.dart';
import 'pages/welcome_page.dart';
import 'theme/app_colors.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const bool isProd = bool.fromEnvironment('IS_PROD', defaultValue: false);
  final envFile = isProd
      ? '.env.production'
      : kIsWeb
          ? '.env.web'
          : '.env.development';
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
  bool _initialConnectDone = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _previousStatus = ApiService().authService.status;

    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChange,
    );

    // 백그라운드에서 초기화 (UI 블로킹 없음)
    _initializeApp();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// Fix 1: 백그라운드 → 포그라운드 복귀 시 WS 상태 확인
  void _onLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final ws = WebSocketService();
      if (!ws.isConnected && _previousStatus == AuthStatus.authenticated) {
        debugPrint('[LIFECYCLE] resumed: WS dead → 재연결');
        ws.connect().then((_) {
          ref.read(tableRepositoryProvider).refresh();
        });
      }
    }
  }

  Future<void> _initializeApp() async {
    final apiService = ApiService();
    final connected = await apiService.initialize();

    if (connected) {
      // Fix 6: 초기 연결은 여기서 직접 처리, auth listener 중복 방지
      _initialConnectDone = true;

      // WebSocket 연결 → _requestSync() → TABLES_SNAPSHOT으로 초기 데이터 수신
      WebSocketService().connect();

      // Repository 구독 활성화 (WS 델타 수신 시작)
      ref.read(tableRepositoryProvider);
      await _loadCatalogResources();

      // Fix 2: SNAPSHOT 타임아웃 → HTTP fallback
      Future.delayed(const Duration(seconds: 8), () {
        final repo = ref.read(tableRepositoryProvider);
        if (repo.tables.isEmpty) {
          debugPrint('[INIT] SNAPSHOT 타임아웃 → HTTP fallback');
          repo.refresh();
        }
      });
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

    // 내 테이블 등록 감지 → 즉시 MatchingPage로 이동
    ref.listen<TableModel?>(currentTableProvider, (previous, next) {
      if (previous == null && next != null) {
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        // 기존 스택 정리 후 MatchingPage push
        nav.popUntil((route) => route.isFirst);
        nav.push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MatchingPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
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
    debugPrint('[AUTH] 상태 변경: $_previousStatus → $status');

    // 인증 성공
    if (status == AuthStatus.authenticated) {
      // Fix 6: 초기 연결에서 이미 처리한 경우 스킵
      if (_initialConnectDone) {
        _initialConnectDone = false;
      } else {
        debugPrint('[AUTH] WebSocket 연결 시도');
        WebSocketService().connect().then((_) {
          ref.read(tableRepositoryProvider).refresh();
          debugPrint('[AUTH] 테이블 동기화 완료');
        });
      }
      _loadCatalogResources();
    }

    // 연결 끊김 (일시적) → 데이터 유지, 재연결 대기
    if (status == AuthStatus.connectionLost) {
      debugPrint('[AUTH] 연결 끊김 → 데이터 유지, 재연결 대기');
      _previousStatus = status;
      return;
    }

    // 인증됨 → 미등록/실패로 변경된 경우 처리 (영구적 인증 해제)
    if (_previousStatus == AuthStatus.authenticated &&
        (status == AuthStatus.unregistered || status == AuthStatus.failed)) {
      debugPrint('[AUTH] 인증 해제 감지 → _handleAuthLost 호출');
      _handleAuthLost(status);
    }

    // connectionLost → authenticated 복구 시 동기화
    if (_previousStatus == AuthStatus.connectionLost &&
        status == AuthStatus.authenticated) {
      debugPrint('[AUTH] 연결 복구 → WebSocket 재연결 + 동기화');
      WebSocketService().connect().then((_) {
        ref.read(tableRepositoryProvider).refresh();
        debugPrint('[AUTH] 재연결 후 테이블 동기화 완료');
      });
    }

    _previousStatus = status;
  }

  void _handleAuthLost(AuthStatus status) {
    // WebSocket 연결 종료
    WebSocketService().disconnect();

    // 테이블 상태 초기화
    ref.read(tableRepositoryProvider).clearCurrentTable();

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

  Future<void> _loadCatalogResources() async {
    await ref.read(catalogResourcesProvider.notifier).load();
    if (!mounted) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final catalog = ref.read(catalogResourcesProvider);
    final imageUrls = <String>{
      for (final item in catalog.menuItems)
        if (item.resolvedImageUrl != null) item.resolvedImageUrl!,
      for (final item in catalog.giftItems)
        if (item.resolvedImageUrl != null) item.resolvedImageUrl!,
    };

    for (final imageUrl in imageUrls) {
      try {
        if (!context.mounted) return;
        if (imageUrl.endsWith('.svg')) {
          final loader = SvgNetworkLoader(imageUrl);
          await svg.cache.putIfAbsent(
            imageUrl,
            () => loader.loadBytes(context),
          );
        } else {
          await precacheImage(NetworkImage(imageUrl), context);
        }
      } catch (_) {
        // 이미지 프리캐시는 실패해도 진행
      }
    }
  }
}
