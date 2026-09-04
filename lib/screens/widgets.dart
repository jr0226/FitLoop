  import 'package:flutter/material.dart';
  // ==========================================
  // 11. PHYSICAL CALCULATOR SHEET (BMI, BMR, TDEE)
  // ==========================================
  class _PhysicalCalculatorSheet extends StatefulWidget {
    const _PhysicalCalculatorSheet();

    @override
    State<_PhysicalCalculatorSheet> createState() => _PhysicalCalculatorSheetState();
  }

  class _PhysicalCalculatorSheetState extends State<_PhysicalCalculatorSheet> {
    final _ageCtrl = TextEditingController();
    final _weightCtrl = TextEditingController();
    final _heightCtrl = TextEditingController();

    String _gender = "Male";
    String _activity = "Moderate";

    // Results
    double? _bmi;
    double? _bmr;
    double? _tdee;
    String _bmiCategory = "";

    void _calculate() {
      // Hide keyboard
      FocusScope.of(context).unfocus();

      if (_ageCtrl.text.isEmpty || _weightCtrl.text.isEmpty || _heightCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields for precise calculation")));
        return;
      }

      double weight = double.tryParse(_weightCtrl.text) ?? 0;
      double heightCm = double.tryParse(_heightCtrl.text) ?? 0;
      int age = int.tryParse(_ageCtrl.text) ?? 0;

      if (weight == 0 || heightCm == 0 || age == 0) return;

      // 1. Calculate BMI = kg/m^2
      double heightM = heightCm / 100;
      double bmi = weight / (heightM * heightM);
      
      String category = "Normal";
      if (bmi < 18.5) {
        category = "Underweight";
      } else if (bmi >= 25 && bmi < 29.9) {
        category = "Overweight";
      } else if (bmi >= 30) {
        category = "Obese";
      }

      // 2. Calculate BMR (Mifflin-St Jeor Equation - most precise)
      double bmr = (10 * weight) + (6.25 * heightCm) - (5 * age);
      bmr += (_gender == "Male") ? 5 : -161;

      // 3. Calculate TDEE
      double multiplier = 1.2;
      if (_activity == "Light") multiplier = 1.375;
      if (_activity == "Moderate") multiplier = 1.55;
      if (_activity == "Active") multiplier = 1.725;
      if (_activity == "Very Active") multiplier = 1.9;

      setState(() {
        _bmi = bmi;
        _bmiCategory = category;
        _bmr = bmr;
        _tdee = bmr * multiplier;
      });
    }

    @override
    Widget build(BuildContext context) {
      final theme = Theme.of(context);
      return Container(
        padding: EdgeInsets.only(
          top: 20, left: 20, right: 20,
          // Prevent keyboard from hiding the calculate button
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Advanced Physical Calculator",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
              Text(
                "Get your precise BMI, BMR, and TDEE.",
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // --- INPUT FIELDS ---
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder(), prefixIcon: Icon(Icons.cake, size: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField(
                      initialValue: _gender,
                      items: ["Male", "Female"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _gender = v.toString()),
                      decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: const InputDecoration(labelText: "Weight (kg)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.monitor_weight, size: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: const InputDecoration(labelText: "Height (cm)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.height, size: 18)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField(
                initialValue: _activity,
                isExpanded: true,
                items: ["Sedentary", "Light", "Moderate", "Active", "Very Active"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _activity = v.toString()),
                decoration: const InputDecoration(labelText: "Activity Level", border: OutlineInputBorder(), prefixIcon: Icon(Icons.directions_run, size: 18)),
              ),
              const SizedBox(height: 20),

              // --- CALCULATE BUTTON ---
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _calculate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Calculate My Stats", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              // --- RESULTS SECTION ---
              if (_bmi != null) ...[
                const SizedBox(height: 25),
                const Divider(),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.surfaceContainerHighest
                        : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("BMI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
                          Text("${_bmi!.toStringAsFixed(1)} ($_bmiCategory)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _bmiCategory == "Normal" ? Colors.green : Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("BMR (Resting Cal)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
                          Text("${_bmr!.toStringAsFixed(0)} kcal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("TDEE (Daily Needs)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
                          Text("${_tdee!.toStringAsFixed(0)} kcal", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
                        ],
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      );
    }
  }