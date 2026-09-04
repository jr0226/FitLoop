import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_models.dart';
import '../services/exercise_service.dart';
import '../services/favorite_exercises_service.dart';
import '../widgets/workout/exercise_list_card.dart';
import '../widgets/workout/exercise_detail_modal.dart';
import '../widgets/workout/add_to_routine_sheet.dart';

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
    'Favorites',
    'Chest',
    'Back',
    'Core',
    'Arms',
    'Shoulders',
    'Legs',
    'Cardio',
  ];

  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<ExerciseModel> _exercises = [];
  Set<String> _favoriteIds = {};
  StreamSubscription<Set<String>>? _favSubscription;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _favSubscription = FavoriteExercisesService.getFavoriteExerciseIdsStream().listen((ids) {
      if (mounted) {
        setState(() {
          _favoriteIds = ids;
        });
      }
    });
    _loadExercisesForCategory(_selectedCategory);
  }

  @override
  void dispose() {
    _favSubscription?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(ExerciseModel exercise) async {
    final effectiveId = FavoriteExercisesService.getEffectiveExerciseId(exercise);
    final currentlyFav = _favoriteIds.contains(effectiveId);

    setState(() {
      if (currentlyFav) {
        _favoriteIds.remove(effectiveId);
        if (_selectedCategory == 'Favorites') {
          _exercises.removeWhere((e) => FavoriteExercisesService.getEffectiveExerciseId(e) == effectiveId);
        }
      } else {
        _favoriteIds.add(effectiveId);
      }
    });

    try {
      await FavoriteExercisesService.toggleFavorite(exercise);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (currentlyFav) {
            _favoriteIds.add(effectiveId);
          } else {
            _favoriteIds.remove(effectiveId);
          }
        });

        final isPermissionDenied = e is FirebaseException && e.code == 'permission-denied';
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPermissionDenied
                  ? "Unable to save favorite (Firestore permission denied - security rules update required)."
                  : "Unable to save favorite. Please try again.",
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
        return 'waist'; // ExerciseDB canonical body part for abs / core movements
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
      if (category.toLowerCase() == 'favorites') {
        final favs = await FavoriteExercisesService.getFavoriteExercises();
        if (mounted) {
          setState(() {
            _exercises = favs;
            _isLoading = false;
          });
        }
        return;
      }

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

    if (_selectedCategory == 'Favorites') {
      final favs = await FavoriteExercisesService.getFavoriteExercises();
      final filteredFavs = favs.where((e) {
        final q = clean.toLowerCase();
        return e.name.toLowerCase().contains(q) ||
            e.targetMuscle.toLowerCase().contains(q) ||
            e.equipment.toLowerCase().contains(q);
      }).toList();
      if (mounted) {
        setState(() {
          _exercises = filteredFavs;
          _isLoading = false;
        });
      }
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
    final effectiveId = FavoriteExercisesService.getEffectiveExerciseId(exercise);
    final isFav = _favoriteIds.contains(effectiveId);

    ExerciseDetailModal.show(
      context,
      exercise: exercise,
      allLibraryExercises: _exercises,
      isFavorite: isFav,
      onToggleFavorite: () => _toggleFavorite(exercise),
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
      resizeToAvoidBottomInset: true,
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
      body: SafeArea(
        child: Column(
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
                    final isFavTab = cat == 'Favorites';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isFavTab) ...[
                              Icon(
                                isSelected ? Icons.favorite : Icons.favorite_border,
                                size: 14,
                                color: isSelected ? Colors.white : Colors.redAccent,
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(cat),
                          ],
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                        selectedColor: isFavTab ? Colors.redAccent.shade400 : Colors.teal,
                        backgroundColor: isFavTab && !isSelected ? Colors.pink.shade50 : Colors.grey.shade100,
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? (isFavTab ? Colors.redAccent.shade400 : Colors.teal)
                                : (isFavTab ? Colors.pink.shade200 : Colors.transparent),
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
      ),
    );
  }

  Widget _buildBody(List<ExerciseModel> filtered) {
    if (_isLoading) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(height: 16),
              Text(
                "Loading exercises from backend...",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      final msg = _errorMessage.toLowerCase();
      final isTimeout = msg.contains("timed out") || msg.contains("timeout");
      final isNetwork = msg.contains("socket") ||
          msg.contains("network") ||
          msg.contains("failed host") ||
          msg.contains("connection");

      final errorTitle = isTimeout
          ? "Connection Timed Out"
          : (isNetwork
              ? "Network Connection Error"
              : "Exercise Service Unavailable");

      final errorIcon = isTimeout
          ? Icons.timer_off_rounded
          : (isNetwork ? Icons.wifi_off_rounded : Icons.cloud_off_rounded);

      final errorDescription = isTimeout
          ? "The request took too long to complete. Please check your internet connection and try again."
          : (isNetwork
              ? "Could not reach the server. Please verify your connection."
              : (_errorMessage.isNotEmpty
                  ? _errorMessage
                  : "The exercise catalog is temporarily unavailable. Please try again shortly."));

      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(errorIcon, color: Colors.orange.shade700, size: 52),
              const SizedBox(height: 14),
              Text(
                errorTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                errorDescription,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 18),
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
      if (_selectedCategory == 'Favorites' && _searchQuery.isEmpty) {
        return Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border_rounded, size: 56, color: Colors.pink.shade300),
                const SizedBox(height: 14),
                const Text(
                  "No favorite exercises yet.",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  "Tap the heart icon on an exercise to save it here.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 52, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? "No exercises found for '$_searchQuery'"
                    : "No exercises found in category '$_selectedCategory'",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty
                    ? "Try searching for a different muscle, movement name, or equipment."
                    : "Try exploring another muscle category or search for specific movements.",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final ex = filtered[index];
        final effectiveId = FavoriteExercisesService.getEffectiveExerciseId(ex);
        final isFav = _favoriteIds.contains(effectiveId);
        return ExerciseListCard(
          exercise: ex,
          isFavorite: isFav,
          onToggleFavorite: () => _toggleFavorite(ex),
          onTap: () => _openExerciseDetail(ex),
          onAdd: widget.onSelectExerciseForWorkout != null
              ? () => widget.onSelectExerciseForWorkout!(ex)
              : null,
          onAddToRoutine: widget.onSelectExerciseForWorkout == null
              ? () => AddToRoutineSheet.show(context, ex)
              : null,
        );
      },
    );
  }
}
