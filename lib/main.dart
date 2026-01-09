import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'pages/welcome_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경변수 로드
  await dotenv.load(fileName: '.env');

  // 초기화 및 자동 로그인 시도
  await ApiService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
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
