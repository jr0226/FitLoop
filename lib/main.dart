import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // ✅ 新增：引入 Firebase 核心
import 'firebase_options.dart'; // ✅ 新增：引入配置文件
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/main_dashboard.dart';
import 'screens/login_page.dart';

// Import scanner
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
// ✅ 修改：把 main 变成 async，并初始化 Firebase
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 必须加这行，确保 Flutter 引擎先启动
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // 读取你刚才生成的配置
  );
  final user = FirebaseAuth.instance.currentUser;
  runApp(MyApp(isLoggedIn: user != null));
}

// ==========================================
// 下面的代码保持不变
// ==========================================
class MyApp extends StatelessWidget { 
  final bool isLoggedIn; // 👈 增加这个变量
  const MyApp({super.key, required this.isLoggedIn}); // 👈 更新构造函数

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'FitLoop',
          debugShowCheckedModeBanner: false,
          
          theme: ThemeData(
            primarySwatch: Colors.teal,
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.grey[50],
          ),
          
          darkTheme: ThemeData(
            primarySwatch: Colors.teal,
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1F1F1F)),
            cardColor: const Color(0xFF1E1E1E),
          ),

          themeMode: currentMode, 
          
          // 👈 核心修改：如果已登录，直接进入主页；未登录，才进入登录页
          home: isLoggedIn ? const MainDashboard() : const LoginPage(),
        );
      },
    );
  }
}



