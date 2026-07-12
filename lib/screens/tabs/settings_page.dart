import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../main.dart'; // Needed for themeNotifier
import '../login_page.dart'; // Needed to redirect after Log Out
import '../setup_profile_page.dart'; // Needed for Edit Profile

// ==========================================
// 9. Setting page
// ==========================================

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- STATE VARIABLES ---
  bool _isDarkMode = false;
  bool _keepScreenAwake = false;
  
  // Units
  String _weightUnit = "kg";
  String _distanceUnit = "km";
  String _energyUnit = "kcal";

  // Notifications
  bool _workoutReminder = true;
  bool _mealReminder = true;
  bool _hydrationReminder = false;
  bool _weighInReminder = false;

  String _selectedLanguage = "English";

  // --- HELPER FUNCTIONS ---

  // 1. Language Picker
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: ["English 🇺🇸", "Chinese (中文) 🇨🇳", "Malay (Bahasa) 🇲🇾"]
            .map((lang) => SimpleDialogOption(
                  onPressed: () {
                    setState(() => _selectedLanguage = lang);
                    Navigator.pop(context);
                  },
                  child: Text(lang),
                ))
            .toList(),
      ),
    );
  }

  // 2. Unit Picker (Generic)
  void _showUnitPicker(String title, List<String> options, Function(String) onSelect) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select $title Unit'),
        children: options
            .map((opt) => SimpleDialogOption(
                  onPressed: () {
                    onSelect(opt);
                    Navigator.pop(context);
                  },
                  child: Text(opt),
                ))
            .toList(),
      ),
    );
  }

  // 3. Quick Update Weight Dialog
  void _showUpdateWeightDialog() {
    final TextEditingController weightCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Current Weight"),
        content: TextField(
          controller: weightCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: "Current Weight ($_weightUnit)", border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Logged: ${weightCtrl.text} $_weightUnit")));
              Navigator.pop(context);
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  // 4. Physical Calculator (BMI, BMR, TDEE)
  void _openCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 变透明以便显示圆角
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: const SizedBox(
          height: 300,
          child: Center(child: Text('Physical Calculator (Coming soon)')),
        ),
      ),
    );
  }

  // 5. Destructive Action Confirm
  Future<void> _confirmDestructiveAction(String title, String content, VoidCallback onConfirm) async {
    bool confirm = await showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          // ==========================
          // 1. ACCOUNT & GOALS
          // ==========================
          _buildHeader("Account & Goals"),
          ListTile(
                leading: const Icon(Icons.remove_red_eye_outlined, color: Colors.teal),
                title: const Text("View Profile Details"),
                subtitle: const Text("See your full health stats & TDEE"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
          // 1. 获取当前用户
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  // 2. 显示一个简单的加载提示（可选，体验更好）
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Loading profile..."), duration: Duration(milliseconds: 500))
                  );

                  // 3. 从 Firebase 获取该用户的最新数据
                  final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                  
                  // 4. 数据获取成功后，把数据传给你的弹窗函数
                  if (doc.exists && context.mounted) {
                    _showProfileDetails(doc.data() as Map<String, dynamic>);
                  }
                }, // 将流里获取的数据直接传给弹窗
              ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Edit Profile"),
            subtitle: const Text("Goals, Micro-Splits, Frequency"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SetupProfilePage(isEditing: true))),
          ),
          ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: const Text("Quick Weight Log"),
            subtitle: const Text("Update current weight only"),
            trailing: const Icon(Icons.add_circle_outline, color: Colors.teal),
            onTap: _showUpdateWeightDialog,
          ),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text("Physical Calculator"),
            subtitle: const Text("Check BMI/TDEE scenarios"),
            onTap: _openCalculator,
          ),

          const Divider(),

          // ==========================
          // 2. UNITS & PREFERENCES
          // ==========================
          _buildHeader("Units & Display"),
          ListTile(
            title: const Text("Weight Unit"),
            trailing: Text(_weightUnit.toUpperCase(), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            onTap: () => _showUnitPicker("Weight", ["kg", "lbs"], (val) => setState(() => _weightUnit = val)),
          ),
          ListTile(
            title: const Text("Distance Unit"),
            trailing: Text(_distanceUnit.toUpperCase(), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            onTap: () => _showUnitPicker("Distance", ["km", "miles"], (val) => setState(() => _distanceUnit = val)),
          ),
          ListTile(
            title: const Text("Energy Unit"),
            trailing: Text(_energyUnit.toUpperCase(), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            onTap: () => _showUnitPicker("Energy", ["kcal", "kJ"], (val) => setState(() => _energyUnit = val)),
          ),
          SwitchListTile(
            title: const Text("Keep Screen Awake"),
            subtitle: const Text("Prevent locking during workouts"),
            value: _keepScreenAwake,
            onChanged: (val) => setState(() => _keepScreenAwake = val),
          ),
          SwitchListTile(
            title: const Text("Dark Mode"),
            secondary: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode),
            value: _isDarkMode,
            onChanged: (val) {
              setState(() => _isDarkMode = val);
              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Language"),
            subtitle: Text(_selectedLanguage),
            onTap: _showLanguageDialog,
          ),

          const Divider(),

          // ==========================
          // 3. NOTIFICATIONS
          // ==========================
          _buildHeader("Notifications"),
          SwitchListTile(title: const Text("Workout Reminders"), value: _workoutReminder, onChanged: (v) => setState(() => _workoutReminder = v)),
          SwitchListTile(title: const Text("Meal Logging"), value: _mealReminder, onChanged: (v) => setState(() => _mealReminder = v)),
          SwitchListTile(title: const Text("Hydration Alerts"), value: _hydrationReminder, onChanged: (v) => setState(() => _hydrationReminder = v)),
          SwitchListTile(title: const Text("Weekly Weigh-in"), value: _weighInReminder, onChanged: (v) => setState(() => _weighInReminder = v)),

          const Divider(),

          // ==========================
          // 4. DATA & PRIVACY
          // ==========================
          _buildHeader("Data & Support"),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text("Export Data"),
            subtitle: const Text("Download PDF/CSV Report"),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating Report... (Demo Only)"))),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text("Clear History"),
            onTap: () => _confirmDestructiveAction("Clear History?", "This will delete all past workout and meal logs.", () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("History Cleared")));
            }),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text("Report a Bug"),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thank you for your report!"))),
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text("Help Center"),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening FAQ..."))),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("Version"),
            subtitle: Text("v1.0.2 (Beta)"),
          ),

          const SizedBox(height: 20),
          
          // ==========================
          // 5. DANGER ZONE (LOGOUT / DELETE)
          // ==========================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, elevation: 0),
              icon: const Icon(Icons.logout),
              label: const Text("Log Out"),
              onPressed: () => _confirmDestructiveAction("Log Out?", "Are you sure you want to exit?", () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              }),
            ),
          ),
          TextButton(
            onPressed: () => _confirmDestructiveAction("Delete Account?", "This action is PERMANENT. All data will be lost.", () {
               // Add delete logic here
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account deletion request sent.")));
            }),
            child: const Text("Delete Account", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  // --- 新增：显示完整个人资料的弹窗 ---
  void _showProfileDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_ind, color: Colors.teal),
                SizedBox(width: 10),
                Text("Complete Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow("Name", data['name']),
            _buildDetailRow("Gender", data['gender']),
            _buildDetailRow("Age", "${data['age']} years"),
            _buildDetailRow("Weight", "${data['weight']} kg"),
            _buildDetailRow("Height", "${data['height']} cm"),
            const Divider(height: 30),
            _buildDetailRow("Activity Level", data['activityLevel']),
            _buildDetailRow("Goal", data['goal']),
            const Divider(height: 30),
            _buildDetailRow("BMR (Resting Cal)", "${(data['bmr'] as num?)?.toStringAsFixed(0) ?? '--'} kcal"),
            _buildDetailRow("TDEE (Daily Burn)", "${(data['tdee'] as num?)?.toStringAsFixed(0) ?? '--'} kcal"),
            _buildDetailRow("Target Calories", "${data['dailyCaloriesTarget'] ?? '--'} kcal"),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            )
          ],
        ),
      ),
    )
    );
  }

  // 辅助组件：生成详细资料的一行文字
  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text("${value ?? '--'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

