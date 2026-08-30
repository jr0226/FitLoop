import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../widgets/change_password_dialog.dart';
import '../login_page.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  bool _isLoading = true;
  String _userName = "Athlete";
  String _userGoal = "Maintenance";
  
  // App Preferences
  bool _isDarkMode = false;
  bool _isMetric = true;
  bool _notificationsEnabled = true;

  final List<String> _goals = ["Weight Loss", "Maintenance", "Muscle Gain"];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    if (currentUser != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
        if (mounted && doc.exists) {
          setState(() {
            _userName = doc.data()?['name'] ?? "Athlete";
            
            // === THE FIX ===
            String fetchedGoal = doc.data()?['goal'] ?? "Maintenance";
            
            // If the fetched goal from Firebase isn't in our list, add it dynamically!
            if (!_goals.contains(fetchedGoal)) {
              _goals.add(fetchedGoal);
            }
            _userGoal = fetchedGoal;
            // ==============
            
            _isMetric = doc.data()?['isMetric'] ?? true;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint("Error fetching profile: $e");
        setState(() => _isLoading = false);
      }
    }
  }

  // --- FIREBASE UPDATES ---
  Future<void> _updateGoal(String newGoal) async {
    setState(() => _userGoal = newGoal);
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'goal': newGoal,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitness goal updated! AI will now adjust your plans.")));
      }
    }
  }

  Future<void> _updateUnitPreference(bool isMetric) async {
    setState(() => _isMetric = isMetric);
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'isMetric': isMetric,
      });
    }
  }

  // --- ACCOUNT MANAGEMENT ---
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.teal),
            SizedBox(width: 10),
            Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("Are you sure you want to log out of FitLoop?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _performSignOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }

  Future<void> _performSignOut() async {
    // Show non-dismissible loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.teal),
                SizedBox(height: 16),
                Text("Signing out...", style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await AuthService.signOut();
      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Clear full navigation stack and navigate to LoginPage
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      // Close loading dialog if open
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to sign out: $e")),
      );
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Account?", style: TextStyle(color: Colors.red)),
        content: const Text("This action is permanent and will wipe all your workout logs, diets, and routines. Are you absolutely sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              try {
                // Delete user document from Firestore (Cloud Functions usually handle sub-collection cleanup)
                await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).delete();
                // Delete Auth user
                await currentUser!.delete();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Requires recent login. Please re-authenticate.")));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Delete Everything"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Profile & Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.teal))
        : ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              // PROFILE HEADER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.teal.shade100,
                      child: const Icon(Icons.person, size: 40, color: Colors.teal),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(currentUser?.email ?? "No Email", style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // FITNESS GOALS
              _buildSectionHeader("Fitness Profile"),
              Container(
                color: Colors.white,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.flag, color: Colors.orange),
                  ),
                  title: const Text("Current Goal", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Determines AI suggestions"),
                  trailing: DropdownButton<String>(
                    value: _userGoal,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                    onChanged: (String? newValue) {
                      if (newValue != null) _updateGoal(newValue);
                    },
                    items: _goals.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 20),
              Container(
                color: Colors.white,
                child: SwitchListTile(
                  activeColor: Colors.teal,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.straighten, color: Colors.blue),
                  ),
                  title: const Text("Metric Units", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_isMetric ? "Kilograms & Kilometers" : "Pounds & Miles"),
                  value: _isMetric,
                  onChanged: _updateUnitPreference,
                ),
              ),

              const SizedBox(height: 20),

              // APP PREFERENCES
              _buildSectionHeader("App Preferences"),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: Colors.teal,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.dark_mode, color: Colors.purple),
                      ),
                      title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.w600)),
                      value: _isDarkMode,
                      onChanged: (val) {
                        setState(() => _isDarkMode = val);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Requires ThemeProvider wrapper to apply globally.")));
                      },
                    ),
                    const Divider(height: 1, indent: 70),
                    SwitchListTile(
                      activeColor: Colors.teal,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.notifications_active, color: Colors.green),
                      ),
                      title: const Text("Push Notifications", style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text("Workout & hydration reminders"),
                      value: _notificationsEnabled,
                      onChanged: (val) => setState(() => _notificationsEnabled = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // DATA & PRIVACY
              _buildSectionHeader("Data & Privacy"),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_download, color: Colors.grey),
                      title: const Text("Export Workout Data"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating CSV file...")));
                      },
                    ),
                    const Divider(height: 1, indent: 70),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip, color: Colors.grey),
                      title: const Text("Privacy Policy"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              // SECURITY & ACCOUNT
              _buildSectionHeader("Account Security"),
              Container(
                color: Colors.white,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.lock_reset, color: Colors.teal),
                  ),
                  title: const Text("Change / Reset Password", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Update password or send reset email"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ChangePasswordDialog.show(context),
                ),
              ),

              const SizedBox(height: 20),

              // DANGER ZONE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OutlinedButton.icon(
                  onPressed: _confirmSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text("Sign Out"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextButton(
                  onPressed: _confirmDeleteAccount,
                  child: const Text("Delete Account", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade500,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}