import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'services/api_service.dart';
import 'pages/welcome_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 앱 시작 시 토큰 클리어 (매번 새로 발급)
  await ApiService().clearToken();

  // 디바이스 ID로 자동 등록 시도
  final isConnected = await ApiService().registerDevice();

  runApp(MyApp(isConnected: isConnected));
}

class MyApp extends StatelessWidget {
  final bool isConnected;

  const MyApp({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'TableMaster',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(colorScheme: LegacyColorSchemes.darkZinc(), radius: 0.5),
      home: WelcomePage(isConnected: isConnected),
    );
  }
}
