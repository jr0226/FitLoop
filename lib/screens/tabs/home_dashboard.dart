import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:health/health.dart';

// ==========================================
// 5. 首页 TAB (HOME TAB) - FULLY DYNAMIC
// ==========================================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _waterMl = 0;
  int _stepCount = 0;
  double _sleepHours = 0;
  bool _isHealthConnected = false;

  List<HealthDataType> types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
  ];

  @override
  void initState() {
    super.initState();
    _fetchHealthData();
  }

  Future<void> _fetchHealthData() async {
    bool requested = await Health().requestAuthorization(types);

    if (requested) {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);

      int? steps = await Health().getTotalStepsInInterval(startOfDay, now);
      
      if (mounted) {
        setState(() {
          _stepCount = steps ?? 0;
          _isHealthConnected = true;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isHealthConnected = false);
      }
    }
  }

  void _showWaterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Adjust your hydration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 15, runSpacing: 15,
                alignment: WrapAlignment.center,
                children: [-100, 100, 200].map((amount) {
                  bool isAdd = amount > 0; 
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _waterMl += amount;
                        if (_waterMl < 0) _waterMl = 0; 
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isAdd ? "Glug glug! +${amount}ml 💧" : "Adjusted: ${amount}ml 💧")
                      ));
                    },
                    child: Container(
                      width: 80, padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isAdd ? Colors.blue.shade50 : Colors.red.shade50, 
                        borderRadius: BorderRadius.circular(15), 
                        border: Border.all(color: isAdd ? Colors.blue.shade200 : Colors.red.shade200)
                      ),
                      child: Center(
                        child: Text(
                          isAdd ? "+$amount" : "$amount", 
                          style: TextStyle(
                            color: isAdd ? Colors.blue : Colors.red, 
                            fontWeight: FontWeight.bold, fontSize: 16
                          )
                        )
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    
    DateTime now = DateTime.now();
    String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
          String name = userData['name'] ?? "User";
          int target = userData['dailyCaloriesTarget'] ?? 2000;
          int streak = userData['currentStreak'] ?? 1; // Pull streak from DB
          
          // STREAM 1: FOOD LOGS (Eaten)
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('food_logs')
                .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                .where('timestamp', isLessThan: endOfDay)
                .snapshots(),
            builder: (context, foodSnapshot) {
              
              int consumed = 0;
              if (foodSnapshot.hasData && foodSnapshot.data!.docs.isNotEmpty) {
                for (var doc in foodSnapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  consumed += (data['calories'] as num?)?.toInt() ?? 0;
                }
              }

              // STREAM 2: WORKOUT LOGS (Burned)
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('workout_logs')
                    .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                    .where('timestamp', isLessThan: endOfDay)
                    .snapshots(),
                builder: (context, workoutSnapshot) {

                  int burned = 0;
                  if (workoutSnapshot.hasData && workoutSnapshot.data!.docs.isNotEmpty) {
                    for (var doc in workoutSnapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      burned += (data['caloriesBurned'] as num?)?.toInt() ?? 0;
                    }
                  }

                  // Net Calories = Eaten - Burned
                  int netCalories = consumed - burned;
                  int remaining = target - netCalories;
                  double progress = (target > 0) ? netCalories / target : 0;
                  if (progress > 1.0) progress = 1.0; 
                  if (progress < 0.0) progress = 0.0;

                  return Scaffold(
                    backgroundColor: Colors.grey[50],
                    appBar: AppBar(
                      backgroundColor: Colors.white, elevation: 0,
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("👋 Hi, $name", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                          const Text("Consistency is key! Keep pushing.", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)), // Motivational Quote
                        ],
                      ),
                      actions: [
                        Container(
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                              const SizedBox(width: 4),
                              Text("$streak Day Streak", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        )
                      ],
                    ),

                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // TODAY'S OVERVIEW CARD
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0, 2))]),
                            child: Row(
                              children: [
                                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_month, color: Colors.teal)),
                                const SizedBox(width: 15),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Today's Date", style: TextStyle(color: Colors.grey, fontSize: 12)), Text(todayStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                                const Spacer(),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)), child: Row(children: const [Icon(Icons.check_circle, color: Colors.green, size: 16), SizedBox(width: 4), Text("On Track", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))]))
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // NUTRI-RING CARD (Now calculates Eaten vs Burned)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))]),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Calories Remaining", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      Text("$remaining", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: remaining < 0 ? Colors.red : Colors.teal)),
                                      const Text("kcal left", style: TextStyle(color: Colors.grey)),
                                      const SizedBox(height: 15),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildMacroChip("🍔 $consumed Eaten", Colors.orange),
                                          _buildMacroChip("🔥 $burned Burned", Colors.purple),
                                        ]
                                      )
                                    ],
                                  ),
                                ),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(width: 100, height: 100, child: CircularProgressIndicator(value: progress, backgroundColor: Colors.grey.shade100, color: remaining < 0 ? Colors.red : Colors.teal, strokeWidth: 10, strokeCap: StrokeCap.round)),
                                    Column(mainAxisSize: MainAxisSize.min, children: [Text("${(progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))])
                                  ],
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // DYNAMIC QUICK START WORKOUT CARD
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(5)), child: const Text("QUICK START", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), const Icon(Icons.fitness_center, color: Colors.white70)]),
                                const SizedBox(height: 10),
                                const Text("Ready to train?", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                const Text("Jump into the Training Hub to select your next routine.", style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity, 
                                  child: ElevatedButton(
                                    // Make sure you hook this up to navigate to your WorkoutTab!
                                    onPressed: () {}, 
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
                                    child: const Text("Go to Training Hub")
                                  )
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // DAILY TRACKERS 
                          Row(
                            children: [
                              const Text("Daily Trackers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isHealthConnected ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isHealthConnected ? Icons.watch : Icons.watch_off, 
                                      size: 12, 
                                      color: _isHealthConnected ? Colors.green : Colors.red
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isHealthConnected ? "Synced" : "Not Synced", 
                                      style: TextStyle(
                                        fontSize: 10, 
                                        color: _isHealthConnected ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold
                                      )
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                          
                          // Water Tracker
                          Container(
                            padding: const EdgeInsets.all(16), 
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.water_drop, color: Colors.blue)),
                                    const SizedBox(width: 15),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Hydration", style: TextStyle(fontSize: 14, color: Colors.grey)),
                                        RichText(text: TextSpan(children: [TextSpan(text: "${(_waterMl / 1000).toStringAsFixed(2)}L", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)), const TextSpan(text: " / 2.5L", style: TextStyle(color: Colors.grey))])),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [-50, -100, 50, 100, 200].map((amount) {
                                      bool isAdd = amount > 0;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 10.0),
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _waterMl += amount;
                                              if (_waterMl < 0) _waterMl = 0; 
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isAdd ? Colors.blue.shade50 : Colors.red.shade50, 
                                              borderRadius: BorderRadius.circular(20), 
                                              border: Border.all(color: isAdd ? Colors.blue.shade200 : Colors.red.shade200)
                                            ),
                                            child: Text(
                                              isAdd ? "+$amount" : "$amount", 
                                              style: TextStyle(
                                                color: isAdd ? Colors.blue : Colors.red, 
                                                fontWeight: FontWeight.bold, 
                                                fontSize: 14
                                              )
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Steps & Sleep 
                          Row(
                            children: [
                              Expanded(child: _buildMiniTracker(Icons.directions_walk, "Steps", "$_stepCount", Colors.orange)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildMiniTracker(Icons.bedtime, "Sleep", "${_sleepHours}h", Colors.purple)),
                            ],
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  );
                }
              );
            }
          );
        }
        return const Center(child: Text("Loading Dashboard..."));
      },
    );
  }

  Widget _buildMacroChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)), 
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))
    );
  }

  Widget _buildMiniTracker(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Icon(icon, color: color, size: 24), 
          const SizedBox(height: 10), 
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)), 
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
        ]
      )
    );
  }
}