import 'package:flutter/material.dart';
import '../models/workout_models.dart';
import '../mock/mock_workout_data.dart';
import '../widgets/workout/exercise_list_card.dart';
import '../widgets/workout/exercise_detail_modal.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final ValueChanged<ExerciseModel>? onSelectExerciseForWorkout;

  const ExerciseLibraryScreen({
    super.key,
    this.onSelectExerciseForWorkout,
  });

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final List<String> _categories = [
    'All',
    'Chest',
    'Back',
    'Legs',
    'Arms',
    'Core',
    'Full Body',
  ];

  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late final List<ExerciseModel> _allExercises;

  @override
  void initState() {
    super.initState();
    _allExercises = MockWorkoutData.comprehensiveExerciseLibrary;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExerciseModel> get _filteredExercises {
    return _allExercises.where((ex) {
      final matchesCategory = _selectedCategory == 'All' ||
          ex.targetMuscle.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          ex.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          ex.equipment.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          ex.targetMuscle.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _openExerciseDetail(ExerciseModel exercise) {
    ExerciseDetailModal.show(
      context,
      exercise: exercise,
      allLibraryExercises: _allExercises,
      onSelectAlternative: (altExercise) {
        _openExerciseDetail(altExercise);
      },
      onAddToWorkout: widget.onSelectExerciseForWorkout != null
          ? () => widget.onSelectExerciseForWorkout!(exercise)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredExercises;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Exercise Library",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: "Search movements, equipment, muscles...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 2. Horizontal Category Pill Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(cat),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      selectedColor: Colors.teal,
                      backgroundColor: Colors.grey.shade100,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? Colors.teal : Colors.transparent,
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(height: 1),

          // 3. Exercise Count & Results Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "SHOWING ${filtered.length} MOVEMENTS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (_selectedCategory != 'All')
                  InkWell(
                    onTap: () => setState(() => _selectedCategory = 'All'),
                    child: Text(
                      "Clear Filter",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 4. Exercise List Cards
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          "No exercises found for '$_searchQuery'",
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final ex = filtered[index];
                      return ExerciseListCard(
                        exercise: ex,
                        onTap: () => _openExerciseDetail(ex),
                        onAdd: widget.onSelectExerciseForWorkout != null
                            ? () => widget.onSelectExerciseForWorkout!(ex)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
