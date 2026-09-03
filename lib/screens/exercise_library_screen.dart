import 'dart:async';
import 'package:flutter/material.dart';
import '../models/workout_models.dart';
import '../services/exercise_service.dart';
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
    'Shoulders',
    'Core',
    'Cardio',
  ];

  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<ExerciseModel> _exercises = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadExercisesForCategory(_selectedCategory);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _mapCategoryToBodyPart(String category) {
    switch (category.toLowerCase()) {
      case 'chest':
        return 'chest';
      case 'back':
        return 'back';
      case 'legs':
        return 'legs';
      case 'arms':
        return 'arms';
      case 'shoulders':
        return 'shoulders';
      case 'core':
        return 'core';
      case 'cardio':
        return 'cardio';
      default:
        return 'all';
    }
  }

  Future<void> _loadExercisesForCategory(String category) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final bodyPart = _mapCategoryToBodyPart(category);
      final rawList = await ExerciseService.getExercisesByBodyPart(bodyPart, limit: 40);

      if (mounted) {
        setState(() {
          _exercises = rawList.map((e) {
            if (e is Map<String, dynamic>) {
              return ExerciseModel.fromJson(e);
            } else if (e is Map) {
              return ExerciseModel.fromJson(Map<String, dynamic>.from(e));
            }
            return ExerciseModel(id: '', name: e.toString(), targetMuscle: category, equipment: 'Bodyweight');
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString().replaceAll("Exception:", "").trim();
        });
      }
    }
  }

  Future<void> _searchExercisesRemotely(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      _loadExercisesForCategory(_selectedCategory);
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final rawList = await ExerciseService.searchExercises(clean, limit: 40);

      if (mounted) {
        setState(() {
          _exercises = rawList.map((e) {
            if (e is Map<String, dynamic>) {
              return ExerciseModel.fromJson(e);
            } else if (e is Map) {
              return ExerciseModel.fromJson(Map<String, dynamic>.from(e));
            }
            return ExerciseModel(id: '', name: e.toString(), targetMuscle: 'General', equipment: 'Bodyweight');
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString().replaceAll("Exception:", "").trim();
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _searchQuery = val.trim();
    _debounceTimer?.cancel();

    if (_searchQuery.isEmpty) {
      _loadExercisesForCategory(_selectedCategory);
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _searchExercisesRemotely(_searchQuery);
      });
    }
  }

  List<ExerciseModel> get _filteredExercises {
    if (_searchQuery.isNotEmpty) {
      return _exercises;
    }
    return _exercises;
  }

  void _openExerciseDetail(ExerciseModel exercise) {
    ExerciseDetailModal.show(
      context,
      exercise: exercise,
      allLibraryExercises: _exercises,
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
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Search movements, equipment, muscles...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
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
                  final isSelected = _selectedCategory == cat && _searchQuery.isEmpty;
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
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedCategory = cat;
                        });
                        _loadExercisesForCategory(cat);
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
                  _isLoading
                      ? "FETCHING EXERCISES..."
                      : "SHOWING ${filtered.length} MOVEMENTS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (_selectedCategory != 'All' || _searchQuery.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedCategory = 'All';
                      });
                      _loadExercisesForCategory('All');
                    },
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

          // 4. Exercise List Cards / Loading / Error / Empty States
          Expanded(
            child: _buildBody(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<ExerciseModel> filtered) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 16),
            Text(
              "Loading exercises from backend...",
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 54),
              const SizedBox(height: 16),
              const Text(
                "Exercise Service Unavailable",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : "Could not connect to exercise service. Please check your network or backend connection.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (_searchQuery.isNotEmpty) {
                    _searchExercisesRemotely(_searchQuery);
                  } else {
                    _loadExercisesForCategory(_selectedCategory);
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? "No exercises found for '$_searchQuery'"
                  : "No exercises found in category '$_selectedCategory'",
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
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
    );
  }
}
