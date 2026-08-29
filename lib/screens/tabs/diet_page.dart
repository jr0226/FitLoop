import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http; // 👈 Needed for Kalori API
import 'dart:convert';
// ==========================================
// 8. DIET PAGE (MAIN LOG & DASHBOARD - SYNCED WITH FIREBASE)
// ==========================================
class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  DateTime _selectedDate = DateTime.now();
  bool _showPercentage = false; 
  final int _exerciseBurn = 0; // Fixed to 0 since workout page isn't done

  String _getDateString(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _changeDate(int days) {
    setState(() { _selectedDate = _selectedDate.add(Duration(days: days)); });
  }

  // --- NEW: POPUP CALENDAR SELECTOR ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023), // Allow going back
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.teal, onPrimary: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    String selectedDateStr = _getDateString(_selectedDate);

    DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Make the calendar icon functional
        leading: IconButton(icon: const Icon(Icons.calendar_today, color: Colors.teal), onPressed: () => _selectDate(context)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.black), onPressed: () => _changeDate(-1)),
            Text(
              "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black), onPressed: () => _changeDate(1)),
          ],
        ),
        centerTitle: true,
      ),

      // Use StreamBuilder to get Target Calories
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          int dailyTarget = userData?['dailyCaloriesTarget'] ?? 2000;
          String goal = userData?['goal'] ?? "Maintenance (保持)"; // 获取用户目标

          // --- 科学营养素计算逻辑 (MACROS SCIENCE) ---
          double proPercent = 0.3;  // 默认比例
          double carbPercent = 0.4;
          double fatPercent = 0.3;

          if (goal.contains("Weight Loss")) {
            proPercent = 0.4; // 减脂期：提高蛋白质比例，保护肌肉
            carbPercent = 0.3;
            fatPercent = 0.3;
          } else if (goal.contains("Muscle Gain")) {
            proPercent = 0.3;
            carbPercent = 0.5; // 增肌期：高碳水提供训练能量
            fatPercent = 0.2;
          }

          // 计算克数 (Grams) = (总卡路里 * 比例) / 每克卡路里
          double targetPro = (dailyTarget * proPercent) / 4;
          double targetCarbs = (dailyTarget * carbPercent) / 4;
          double targetFat = (dailyTarget * fatPercent) / 9;
          // ------------------------------------------
          // Use StreamBuilder to get Food Logs for the specific day
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('food_logs')
                .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                .where('timestamp', isLessThan: endOfDay)
                .orderBy('timestamp', descending: true).snapshots(),
            builder: (context, foodSnapshot) {
              if (foodSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              // Calculate dynamic totals from Firebase
              int foodEaten = 0;
              int totalPro = 0;
              int totalCarbs = 0;
              int totalFat = 0;
              List<Map<String, dynamic>> loggedMeals = [];

              if (foodSnapshot.hasData && foodSnapshot.data!.docs.isNotEmpty) {
                for (var doc in foodSnapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  loggedMeals.add(data);
                  foodEaten += (data['calories'] as num?)?.toInt() ?? 0;
                  totalPro += (data['proteins'] as num?)?.toInt() ?? 0;
                  totalCarbs += (data['carbs'] as num?)?.toInt() ?? 0;
                  totalFat += (data['fats'] as num?)?.toInt() ?? 0;
                }
              }

              int remaining = dailyTarget - foodEaten + _exerciseBurn;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // 1. SUMMARY CARD
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMathColumn("Goal", "$dailyTarget"),
                              const Text("-", style: TextStyle(fontSize: 20, color: Colors.grey)),
                              _buildMathColumn("Food", "$foodEaten"),
                              const Text("+", style: TextStyle(fontSize: 20, color: Colors.grey)),
                              _buildMathColumn("Exercise", "$_exerciseBurn"),
                              const Text("=", style: TextStyle(fontSize: 20, color: Colors.grey)),
                              _buildMathColumn("Remaining", "$remaining", isBold: true, color: remaining < 0 ? Colors.red : Colors.teal),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 10),
                          
                          InkWell(
                            onTap: () => setState(() => _showPercentage = !_showPercentage),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Mock targets for macros based on standard 2000kcal diet (can be made dynamic later)
                                _buildMacroBar("Protein", totalPro.toDouble(), targetPro, Colors.purple),
                                _buildMacroBar("Carbs", totalCarbs.toDouble(), targetCarbs, Colors.orange),
                                _buildMacroBar("Fat", totalFat.toDouble(), targetFat, Colors.blue),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Center(child: Text("Tap bars to toggle %", style: TextStyle(color: Colors.grey, fontSize: 10))),
                        ],
                      ),
                    ),

                    // 2. REAL FIREBASE MEALS LIST
                    _buildMealBucket("Logged Meals", loggedMeals),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            }
          );
        }
      ),
    );
  }

  Widget _buildMathColumn(String label, String value, {bool isBold = false, Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? (isBold ? Colors.teal : Colors.black))),
      ],
    );
  }

  Widget _buildMacroBar(String label, double current, double target, Color color) {
    double progress = current / target;
    if (progress > 1) progress = 1;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        SizedBox(
          width: 90,
          child: LinearProgressIndicator(value: progress, backgroundColor: color.withOpacity(0.1), color: color, minHeight: 6, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(height: 5),
        Text(
          _showPercentage ? "${(progress * 100).toInt()}%" : "${(target - current).toInt()}g left",
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMealBucket(String title, List<Map<String, dynamic>> items) {
    double bucketCals = items.fold(0, (sum, item) => sum + (item['calories'] as num).toDouble());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("${bucketCals.toInt()} kcal", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ),
          const Divider(height: 1),
          
          if (items.isEmpty)
             const Padding(padding: EdgeInsets.all(20), child: Text("No meals logged yet today.", style: TextStyle(color: Colors.grey))),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: const Icon(Icons.fastfood, color: Colors.orange),
                title: Text(item['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text("${item['calories']} kcal • Pro: ${item['proteins']}g"),
                trailing: const Icon(Icons.info_outline, color: Colors.grey),
                onTap: () {
                   showDialog(context: context, builder: (c) => AlertDialog(
                     title: Text(item['name']),
                     content: Text("Calories: ${item['calories']} kcal\nProtein: ${item['proteins']}g\nCarbs: ${item['carbs']}g\nFat: ${item['fats']}g"),
                     actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close"))],
                   ));
                },
              );
            },
          ),
          
          InkWell(
            // We use standard navigation so it doesn't crash. 
            // In a real app, this Add Food page should also save to Firebase.
            onTap: () => Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => AddFoodPage(
                  mealCategory: "Meal", 
                  selectedDate: _selectedDate, // 👈 加上这个，告诉它存到哪一天
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: const Row(
                children: [
                  Icon(Icons.add, color: Colors.teal),
                  SizedBox(width: 8),
                  Text("MANUAL ADD", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// NEW PAGE: ADD FOOD INTERFACE
// ==========================================
class AddFoodPage extends StatefulWidget {
  final String mealCategory;
  final DateTime selectedDate;

  const AddFoodPage({super.key, required this.mealCategory, required this.selectedDate});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  // 移除了 TabController，因为我们不再需要底部的 Tabs
  List<dynamic> _searchResults = [];
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;

  final String apiKey = "YOUR_NINJAS_API_KEY_HERE"; // Replace with your actual API key from https://api-ninjas.com/api/food

  // --- 1. SEARCH FOOD VIA API ---
  Future<void> _searchFoodApi(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      // 💡 优化：不再在这里清空 _searchResults。
      // 这样用户在等待新结果时，依然能看到“before data (之前的数据)”。
    });

    try {
      final url = Uri.parse('https://api-ninjas.com/api/food?query=$query'); 

      final response = await http.get(
        url,
        headers: {
          'X-API-Key': apiKey, 
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          _searchResults = data is List 
              ? data 
              : (data['data'] ?? data['results'] ?? data['items'] ?? []);
          _isSearching = false;
        });
        
        if (_searchResults.isEmpty && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No food found.")));
        }
      } else {
        throw Exception("API Error: ${response.statusCode}");
      }
    } catch (e) {
      print("API Fetch Error: $e");
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error fetching food database. Check API Key.")));
      }
    }
  }

  // --- 2. SAVE SELECTED FOOD DIRECTLY TO FIREBASE ---
  Future<void> _saveToFirebase(dynamic apiFood) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 显示一个无法点击关闭的加载圈
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.teal)));

    try {
      // 兼容 Kalori API 字段名
      String foodName = apiFood['name'] ?? apiFood['product_name'] ?? 'Unknown Food';
      int cals = (apiFood['calories'] ?? apiFood['energy'] ?? 0).toInt();
      int pro = (apiFood['protein'] ?? apiFood['proteins'] ?? 0).toInt();
      int carbs = (apiFood['carbohydrates'] ?? apiFood['carbs'] ?? 0).toInt();
      int fats = (apiFood['fat'] ?? apiFood['fats'] ?? 0).toInt();

      // 直接存入 Firebase，关联用户在日历上选中的日期
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('food_logs').add({
        'name': foodName,
        'calories': cals,
        'proteins': pro,
        'carbs': carbs,
        'fats': fats,
        'timestamp': widget.selectedDate, 
      });

      if (mounted) {
        Navigator.pop(context); // 关掉加载圈
        Navigator.pop(context); // 退回 Diet Page
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$foodName added!")));
      }
    } catch (e) {
      Navigator.pop(context); // 发生错误时也要关掉加载圈
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Search Food Database"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: _searchFoodApi, 
              decoration: InputDecoration(
                hintText: "Search food (e.g. Nasi Lemak, 100 Plus)",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.teal),
                  onPressed: () => _searchFoodApi(_searchCtrl.text),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          
          // 正在搜索时的细条加载动画，不会覆盖之前的数据
          if (_isSearching)
            const LinearProgressIndicator(color: Colors.teal, minHeight: 2),

          if (!_isSearching && _searchResults.isEmpty)
             Expanded(
               child: Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(Icons.fastfood_outlined, size: 80, color: Colors.grey.shade300),
                     const SizedBox(height: 10),
                     Text("Search for any Malaysian food!", style: TextStyle(color: Colors.grey.shade500)),
                   ],
                 ),
               ),
             ),

          // 搜索结果列表
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final food = _searchResults[index];
                
                String name = food['name'] ?? food['product_name'] ?? 'Unknown';
                String cals = (food['calories'] ?? food['energy'] ?? 0).toString();
                String pro = (food['protein'] ?? food['proteins'] ?? 0).toString();

                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.restaurant, color: Colors.teal, size: 20),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$cals kcal • ${pro}g Protein"),
                  trailing: const Icon(Icons.add_circle, color: Colors.teal, size: 28),
                  onTap: () => _saveToFirebase(food), 
                );
              },
            ),
          )
        ],
      ),
    );
  }
}