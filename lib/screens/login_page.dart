import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 👇 引入你要跳转的其他页面 (注意路径，如果它们都在 screens 文件夹下，直接写文件名即可)
import 'main_dashboard.dart'; 
import 'setup_profile_page.dart';

// ==========================================
// 2. LOGIN MODULE
// ==========================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true;
  bool _isLoading = false;



  Future<void> _submitAuth() async {
    setState(() => _isLoading = true);
    try {
      if (_isLoginMode) {
        // === LOGIN ===
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // === REGISTER ===
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration Successful! Logging in...')),
        );
      }

      // === NEW LOGIC: Check where to send the user ===
      if (mounted) {
        bool hasData = await checkUserHasData(); // Check Firestore
        
        if (!mounted) return;

        if (hasData) {
          // User has data -> Go to Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainDashboard()),
          );
        } else {
          // New user -> Go to Setup Profile
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SetupProfilePage(isEditing: false)),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "Operation Failed";
      if (e.code == 'user-not-found') message = "User not found.";
      if (e.code == 'wrong-password') message = "Wrong password.";
      if (e.code == 'email-already-in-use') message = "Email already registered.";
      if (e.code == 'weak-password') message = "Password too weak.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // === 新增：Google 快捷登录逻辑 ===
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 1. 触发 Google 登录流程
      await GoogleSignIn().signOut();
      
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // 用户在弹窗时点了取消
      }

      // 2. 获取 Google 身份验证凭据
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. 登录到 Firebase Auth
      await FirebaseAuth.instance.signInWithCredential(credential);

      // 4. 完美复用你的路由逻辑：检查是否有数据
      if (mounted) {
        bool hasData = await checkUserHasData();
        if (hasData) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainDashboard()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SetupProfilePage(isEditing: false)));
        }
      }
    } catch (e) {
      print("Google Sign-In Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Google Login Failed: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // === HELPER: Check Firestore for User Document ===
  Future<bool> checkUserHasData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fitness_center, size: 80, color: Colors.teal),
                const SizedBox(height: 20),
                Text(
                  _isLoginMode ? 'Welcome Back' : 'Create Account',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _submitAuth,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                          child: Text(_isLoginMode ? 'LOGIN' : 'REGISTER'),
                        ),
                      ),
                      
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                        child: Text(_isLoginMode ? 'No account? Register here' : 'Have an account? Login here', style: const TextStyle(color: Colors.teal)),
                      ),
                      
                      // 👈 === 以下是新增的 Google 登录 UI === 👉
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("OR", style: TextStyle(color: Colors.grey, fontSize: 12))),
                          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _signInWithGoogle, 
                          // 核心改变：直接用内置图标，不需要网络加载！
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 36, color: Colors.blue), 
                          label: const Text(
                            "Continue with Google", 
                            style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            elevation: 0,
                            side: BorderSide(color: Colors.grey.shade300, width: 1.5), // 精致的浅灰色边框
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)) // 更圆润现代的圆角
                          ),
                        ),
                      ),
                      // 👈 === 结束 === 👉
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}