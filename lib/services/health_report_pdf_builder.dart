import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/health_report_data.dart';

/// An unbreakable wrapper for PDF elements that must never split across pages.
/// Inherits from SingleChildWidget and explicitly sets canSpan to false so MultiPage
/// will always move the entire block to the next page if it cannot fit on the current page.
class _KeepTogether extends pw.SingleChildWidget {
  _KeepTogether({required pw.Widget child}) : super(child: child);

  @override
  bool get canSpan => false;

  @override
  void paint(pw.Context context) {
    super.paint(context);
    paintChild(context);
  }
}

/// Builds a professional, multi-page FitLoop Health & Fitness Report in A4 PDF format.
/// Employs 100% PDF-safe ASCII typography to eliminate replacement glyphs.
class HealthReportPdfBuilder {
  // Brand colors
  static const PdfColor tealPrimary = PdfColor.fromInt(0xFF00897B);
  static const PdfColor tealLight = PdfColor.fromInt(0xFFE0F2F1);
  static const PdfColor darkSlate = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor neutralGrey = PdfColor.fromInt(0xFF64748B);
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor borderGrey = PdfColor.fromInt(0xFFE2E8F0);

  /// Cleans strings of any unsupported characters (emojis, CJK, special Unicode)
  /// so that standard Helvetica never renders square / X missing-glyph boxes.
  static String safeAscii(String text) {
    return text
        .replaceAll('–', '-') // en dash
        .replaceAll('—', '-') // em dash
        .replaceAll('•', '|') // bullet
        .replaceAll('·', '|') // middle dot
        .replaceAll('≥', '>=') // greater than or equal
        .replaceAll('≤', '<=') // less than or equal
        .replaceAll('±', '+/-')
        .replaceAll('…', '...')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '') // Strip all non-ASCII
        .trim();
  }

  /// Helper for singular / plural count formatting.
  static String pluralize(int count, String singular, [String? plural]) {
    plural ??= '${singular}s';
    return '$count ${count == 1 ? singular : plural}';
  }

  /// Generates the raw PDF bytes from aggregated report data.
  static Future<Uint8List> buildPdf(HealthReportData data) async {
    final pdf = pw.Document(
      title: 'FitLoop Health & Fitness Report',
      author: 'FitLoop Personal AI Health System',
    );

    final String dateRangeFormatted =
        '${DateFormat('MMM d, yyyy').format(data.startDate)} - ${DateFormat('MMM d, yyyy').format(data.endDate)}';
    final String generatedAtFormatted =
        DateFormat('MMM d, yyyy | HH:mm').format(data.generatedAt);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (pw.Context context) => _buildHeader(
          data: data,
          dateRange: dateRangeFormatted,
          generatedAt: generatedAtFormatted,
        ),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context context) => [
          // 1. PROFILE & GOAL OVERVIEW
          _buildProfileOverviewSection(data),

          pw.SizedBox(height: 14),

          // 2. NUTRITION SUMMARY
          _buildNutritionSection(data),

          pw.SizedBox(height: 14),

          // 3. WORKOUT PERFORMANCE SUMMARY
          _buildWorkoutSection(data),

          pw.SizedBox(height: 14),

          // 4. BODY MEASUREMENTS & PROGRESS (Never orphaned across page boundary)
          _KeepTogether(child: _buildBodyProgressSection(data)),

          pw.SizedBox(height: 14),

          // 5. UNLOCKED ACHIEVEMENTS
          _KeepTogether(child: _buildAchievementsSection(data)),

          pw.SizedBox(height: 14),

          // 6. DISCLAIMER
          _KeepTogether(child: _buildDisclaimer()),
        ],
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // HEADER & FOOTER
  // =========================================================================
  static pw.Widget _buildHeader({
    required HealthReportData data,
    required String dateRange,
    required String generatedAt,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: tealPrimary, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'FIT',
                    style: pw.TextStyle(
                      color: tealPrimary,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.Text(
                    'LOOP',
                    style: pw.TextStyle(
                      color: darkSlate,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Health & Fitness Progress Report',
                style: const pw.TextStyle(
                  color: neutralGrey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                dateRange,
                style: pw.TextStyle(
                  color: darkSlate,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Generated: $generatedAt',
                style: const pw.TextStyle(
                  color: neutralGrey,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: borderGrey, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'FitLoop | Confidential Personal Fitness Report',
            style: const pw.TextStyle(color: neutralGrey, fontSize: 8),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              color: neutralGrey,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. PROFILE OVERVIEW
  // =========================================================================
  static pw.Widget _buildProfileOverviewSection(HealthReportData data) {
    final p = data.userProfile;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: borderGrey),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'PROFILE & TARGET OVERVIEW',
                style: pw.TextStyle(
                  color: tealPrimary,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              if (p.currentStreak > 0)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const pw.BoxDecoration(
                    color: tealLight,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    '${p.currentStreak}-Day Streak',
                    style: pw.TextStyle(
                      color: tealPrimary,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildKeyValueItem('Athlete', safeAscii(p.name)),
              _buildKeyValueItem('Goal', safeAscii(p.fitnessGoal)),
              _buildKeyValueItem('Level', safeAscii(p.fitnessLevel)),
              _buildKeyValueItem('Activity', safeAscii(p.activityLevel)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildKeyValueItem('Current Weight', p.formattedCurrentWeight),
              _buildKeyValueItem('Target Weight', p.formattedTargetWeight),
              _buildKeyValueItem('Height', p.formattedHeight),
              _buildKeyValueItem('Calorie Target', '${NumberFormat('#,##0').format(p.calorieTarget)} kcal/day'),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: borderGrey, thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'Diet Preference: ',
                    style: pw.TextStyle(
                      color: darkSlate,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    safeAscii(p.dietPreference),
                    style: const pw.TextStyle(
                      color: neutralGrey,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text(
                    'Weight vs Target: ',
                    style: pw.TextStyle(
                      color: darkSlate,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    p.goalProgressStatus,
                    style: const pw.TextStyle(
                      color: neutralGrey,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. NUTRITION SUMMARY & RECENT MEALS
  // =========================================================================
  static pw.Widget _buildNutritionSection(HealthReportData data) {
    final n = data.nutrition;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('NUTRITION & DIETARY SUMMARY'),
        pw.SizedBox(height: 8),

        if (!n.hasData)
          _buildEmptyNotice('No nutrition logs recorded during this period.')
        else ...[
          // Metrics Grid
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildMetricCard(
                  'Logged Meals',
                  '${n.totalMealsLogged}',
                  subtitle: pluralize(n.daysWithLogs, 'active day'),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricCard(
                  'Avg Daily Intake',
                  '${NumberFormat('#,##0').format(n.avgDailyCalories)} kcal/day',
                  subtitle: 'Target: ${NumberFormat('#,##0').format(n.calorieTarget)} kcal/day',
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMacrosCard(n),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricCard(
                  'AI Meal Score',
                  n.avgMealScore != null
                      ? '${n.avgMealScore!.round()} / 100'
                      : 'N/A',
                  subtitle: 'Quality rating',
                ),
              ),
            ],
          ),

          // Calorie Trend Bars
          if (n.dailyCalorieTrend.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _buildCalorieTrendBarChart(n.dailyCalorieTrend, n.calorieTarget, n.daysWithLogs),
          ],

          // Recent Meals Table
          if (n.recentMeals.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Recent Logged Meals',
              style: pw.TextStyle(
                color: darkSlate,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            _buildNutritionTable(n.recentMeals),
          ],
        ],
      ],
    );
  }

  static pw.Widget _buildMacrosCard(NutritionReportSummary n) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderGrey),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Avg Macronutrients',
            style: const pw.TextStyle(color: neutralGrey, fontSize: 8),
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroItem('Protein', '${n.avgProtein.round()} g/d'),
              _buildMacroItem('Carbs', '${n.avgCarbs.round()} g/d'),
              _buildMacroItem('Fat', '${n.avgFat.round()} g/d'),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Daily average intake',
            style: const pw.TextStyle(color: neutralGrey, fontSize: 6.5),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMacroItem(String name, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          name,
          style: const pw.TextStyle(color: neutralGrey, fontSize: 6.5),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: darkSlate,
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCalorieTrendBarChart(
    List<NutritionDailyData> trend,
    int target,
    int activeDays,
  ) {
    final bool isWeekly = trend.length <= 7;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderGrey),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Daily Calorie Intake vs Target (${NumberFormat('#,##0').format(target)} kcal/day)',
                style: pw.TextStyle(
                  color: darkSlate,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${trend.length} days (${pluralize(activeDays, 'active day')})',
                style: const pw.TextStyle(color: neutralGrey, fontSize: 8),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: trend.asMap().entries.map((entry) {
              final idx = entry.key;
              final d = entry.value;
              final double heightFraction = target > 0
                  ? (d.totalCalories / (target * 1.5)).clamp(0.04, 1.0)
                  : 0.2;
              final bool isOver = d.totalCalories > target;

              // Determine date label
              String dateLabel = '';
              if (isWeekly) {
                dateLabel = DateFormat('E').format(d.date);
              } else if (trend.length <= 14) {
                dateLabel = DateFormat('M/d').format(d.date);
              } else {
                if (idx == 0 || idx == trend.length - 1 || idx % 5 == 0) {
                  dateLabel = DateFormat('M/d').format(d.date);
                }
              }

              return pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 1),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      if (d.totalCalories > 0 && (isWeekly || idx % 5 == 0 || idx == trend.length - 1))
                        pw.Text(
                          '${d.totalCalories}',
                          style: const pw.TextStyle(fontSize: 5, color: neutralGrey),
                        ),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        height: 30 * heightFraction,
                        decoration: pw.BoxDecoration(
                          color: d.totalCalories == 0
                              ? borderGrey
                              : (isOver
                                  ? const PdfColor.fromInt(0xFFF59E0B)
                                  : tealPrimary),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(2)),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        dateLabel,
                        style: const pw.TextStyle(fontSize: 6, color: neutralGrey),
                        maxLines: 1,
                      ),
                      if (isWeekly)
                        pw.Text(
                          DateFormat('M/d').format(d.date),
                          style: const pw.TextStyle(fontSize: 5, color: neutralGrey),
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNutritionTable(List<NutritionMealItem> meals) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderGrey, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.0),
        1: const pw.FlexColumnWidth(3.4),
        2: const pw.FlexColumnWidth(1.1),
        3: const pw.FlexColumnWidth(0.8),
        4: const pw.FlexColumnWidth(0.8),
        5: const pw.FlexColumnWidth(0.8),
        6: const pw.FlexColumnWidth(0.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: lightBg),
          children: [
            _buildTableHeaderCell('Date'),
            _buildTableHeaderCell('Meal Description'),
            _buildTableHeaderCell('Calories'),
            _buildTableHeaderCell('Protein'),
            _buildTableHeaderCell('Carbs'),
            _buildTableHeaderCell('Fat'),
            _buildTableHeaderCell('Score'),
          ],
        ),
        ...meals.map(
          (m) => pw.TableRow(
            children: [
              _buildTableCell(DateFormat('MMM d').format(m.date)),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      safeAscii(m.name),
                      style: pw.TextStyle(
                        color: darkSlate,
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      safeAscii(m.mealType),
                      style: const pw.TextStyle(
                        color: neutralGrey,
                        fontSize: 6.5,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTableCell('${m.calories} kcal'),
              _buildTableCell('${m.protein.toStringAsFixed(0)}g'),
              _buildTableCell('${m.carbs.toStringAsFixed(0)}g'),
              _buildTableCell('${m.fat.toStringAsFixed(0)}g'),
              _buildTableCell(m.score != null ? '${m.score!.round()}' : '-'),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 3. WORKOUT PERFORMANCE & RECENT SESSIONS
  // =========================================================================
  static pw.Widget _buildWorkoutSection(HealthReportData data) {
    final w = data.workout;
    final bool isMetric = data.userProfile.isMetric;
    final String volUnit = isMetric ? 'kg' : 'lbs';
    final double displayVolume = isMetric ? w.totalVolumeKg : (w.totalVolumeKg * 2.20462);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('WORKOUT PERFORMANCE & VOLUME'),
        pw.SizedBox(height: 8),

        if (!w.hasData)
          _buildEmptyNotice('No workout logs recorded during this period.')
        else ...[
          // Metrics Grid
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildMetricCard(
                  'Workouts Completed',
                  '${w.totalWorkouts}',
                  subtitle: pluralize(w.activeWorkoutDays, 'active day'),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricCard(
                  'Total Duration',
                  '${w.totalDurationMinutes} mins',
                  subtitle: 'Avg ${w.avgDurationMinutes} mins/session',
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricCard(
                  'Calories Burned',
                  '${NumberFormat('#,##0').format(w.totalCaloriesBurned)} kcal',
                  subtitle: '${pluralize(w.totalSets, 'set')} | ${pluralize(w.totalReps, 'rep')}',
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricCard(
                  'Total Volume Lifted',
                  w.totalVolumeKg > 0
                      ? '${NumberFormat('#,##0').format(displayVolume.round())} $volUnit'
                      : 'Bodyweight',
                  subtitle: w.maxWeightLiftedKg != null
                      ? 'Max: ${NumberFormat('#,##0').format((isMetric ? w.maxWeightLiftedKg! : w.maxWeightLiftedKg! * 2.20462).round())} $volUnit'
                      : 'Endurance / Cardio',
                ),
              ),
            ],
          ),

          if (w.mostFrequentExercise != null || w.highestVolumeExercise != null) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (w.mostFrequentExercise != null)
                    pw.Expanded(
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Top Movement: ',
                              style: pw.TextStyle(
                                color: darkSlate,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.TextSpan(
                              text: safeAscii(w.mostFrequentExercise!),
                              style: const pw.TextStyle(color: neutralGrey, fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (w.mostFrequentExercise != null && w.highestVolumeExercise != null)
                    pw.SizedBox(width: 12),
                  if (w.highestVolumeExercise != null)
                    pw.Expanded(
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Peak Volume Exercise: ',
                              style: pw.TextStyle(
                                color: darkSlate,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.TextSpan(
                              text: safeAscii(w.highestVolumeExercise!),
                              style: const pw.TextStyle(color: neutralGrey, fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Recent Workouts Table
          if (w.recentWorkouts.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Recent Workout Sessions',
              style: pw.TextStyle(
                color: darkSlate,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            _buildWorkoutTable(w.recentWorkouts, isMetric),
          ],
        ],
      ],
    );
  }

  static pw.Widget _buildWorkoutTable(
    List<WorkoutSessionItem> workouts,
    bool isMetric,
  ) {
    final String volUnit = isMetric ? 'kg' : 'lbs';

    return pw.Table(
      border: pw.TableBorder.all(color: borderGrey, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.0),
        1: const pw.FlexColumnWidth(2.8),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: lightBg),
          children: [
            _buildTableHeaderCell('Date'),
            _buildTableHeaderCell('Routine / Session'),
            _buildTableHeaderCell('Duration'),
            _buildTableHeaderCell('Calories'),
            _buildTableHeaderCell('Volume'),
          ],
        ),
        ...workouts.map(
          (w) {
            final double sessionVol = isMetric ? w.totalVolumeKg : (w.totalVolumeKg * 2.20462);
            return pw.TableRow(
              children: [
                _buildTableCell(DateFormat('MMM d').format(w.date)),
                _buildTableCell(safeAscii(w.routineName), isBold: true),
                _buildTableCell('${w.durationMinutes} mins'),
                _buildTableCell('${NumberFormat('#,##0').format(w.caloriesBurned)} kcal'),
                _buildTableCell(w.totalVolumeKg > 0
                    ? '${NumberFormat('#,##0').format(sessionVol.round())} $volUnit'
                    : pluralize(w.totalSets, 'set')),
              ],
            );
          },
        ),
      ],
    );
  }

  // =========================================================================
  // 4. BODY PROGRESS & WEIGHT TREND
  // =========================================================================
  static pw.Widget _buildBodyProgressSection(HealthReportData data) {
    final b = data.bodyProgress;
    final unit = b.isMetric ? 'kg' : 'lbs';
    final lengthUnit = b.isMetric ? 'cm' : 'in';

    double formatWeightVal(double? kg) {
      if (kg == null) return 0.0;
      return b.isMetric ? kg : (kg * 2.20462);
    }

    // Determine clean Body Composition display
    String compValue = 'No records';
    String compSubtitle = 'Track in Body Progress';
    if (b.latestBodyFat != null && b.latestBodyFat! > 0) {
      compValue = '${b.latestBodyFat!.toStringAsFixed(1)}% Fat';
      if (b.startBodyFat != null && b.startBodyFat! > 0) {
        final diff = b.latestBodyFat! - b.startBodyFat!;
        compSubtitle = 'Delta: ${diff > 0 ? "+" : ""}${diff.toStringAsFixed(1)}%';
      } else {
        compSubtitle = 'Latest measurement';
      }
    } else if (b.latestWaistCm != null && b.latestWaistCm! > 0) {
      final waistVal = b.isMetric ? b.latestWaistCm! : (b.latestWaistCm! * 0.393701);
      compValue = '${waistVal.toStringAsFixed(1)} $lengthUnit Waist';
      if (b.startWaistCm != null && b.startWaistCm! > 0) {
        final startWaist = b.isMetric ? b.startWaistCm! : (b.startWaistCm! * 0.393701);
        final diff = waistVal - startWaist;
        compSubtitle = 'Delta: ${diff > 0 ? "+" : ""}${diff.toStringAsFixed(1)} $lengthUnit';
      } else {
        compSubtitle = 'Latest measurement';
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('BODY MEASUREMENTS & PROGRESSION'),
        pw.SizedBox(height: 8),

        if (!b.hasData)
          _buildEmptyNotice('No body composition measurements recorded during this period.')
        else ...[
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildMetricCard(
                  'Starting Weight',
                  b.startWeightKg != null
                      ? '${formatWeightVal(b.startWeightKg).toStringAsFixed(1)} $unit'
                      : '${formatWeightVal(b.latestWeightKg).toStringAsFixed(1)} $unit',
                  subtitle: pluralize(b.totalMeasurementLogs, 'log entry', 'log entries'),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricCard(
                  'Latest Weight',
                  b.latestWeightKg != null
                      ? '${formatWeightVal(b.latestWeightKg).toStringAsFixed(1)} $unit'
                      : 'N/A',
                  subtitle: 'Target: ${formatWeightVal(b.targetWeightKg).toStringAsFixed(1)} $unit',
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricCard(
                  'Period Net Change',
                  b.hasWeightChange
                      ? '${b.weightDeltaKg! > 0 ? "+" : ""}${formatWeightVal(b.weightDeltaKg).toStringAsFixed(1)} $unit'
                      : 'Stable',
                  subtitle: b.hasWeightChange
                      ? (b.weightDeltaKg! < 0 ? 'Weight lost' : 'Weight gained')
                      : 'Requires 2+ logs',
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricCard(
                  'Body Composition',
                  compValue,
                  subtitle: compSubtitle,
                ),
              ),
            ],
          ),

          if (b.weightTrend.length >= 2) ...[
            pw.SizedBox(height: 8),
            _buildWeightTrendPoints(b.weightTrend, unit, b.isMetric),
          ],
        ],
      ],
    );
  }

  static pw.Widget _buildWeightTrendPoints(
    List<WeightDataPoint> trend,
    String unit,
    bool isMetric,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderGrey),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Recorded Weight Progression ($unit)',
            style: pw.TextStyle(
              color: darkSlate,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 12,
            runSpacing: 4,
            children: trend.map((p) {
              final double w = isMetric ? p.weightKg : (p.weightKg * 2.20462);
              return pw.Text(
                '${DateFormat('MMM d').format(p.date)}: ${w.toStringAsFixed(1)} $unit',
                style: const pw.TextStyle(color: neutralGrey, fontSize: 8),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. ACHIEVEMENTS
  // =========================================================================
  static pw.Widget _buildAchievementsSection(HealthReportData data) {
    final achievements = data.achievements;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('UNLOCKED ACHIEVEMENTS & MILESTONES'),
        pw.SizedBox(height: 8),

        if (achievements.isEmpty)
          _buildEmptyNotice('No achievements unlocked yet. Keep working out to earn badges!')
        else
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: achievements.map((a) {
              return pw.Container(
                width: 240,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderGrey),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          safeAscii(a.title),
                          style: pw.TextStyle(
                            color: tealPrimary,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (a.unlockedAt != null)
                          pw.Text(
                            DateFormat('MMM d').format(a.unlockedAt!),
                            style: const pw.TextStyle(color: neutralGrey, fontSize: 7),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      safeAscii(a.description),
                      style: const pw.TextStyle(color: neutralGrey, fontSize: 8),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // =========================================================================
  // 6. DISCLAIMER
  // =========================================================================
  static pw.Widget _buildDisclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderGrey, width: 0.5),
      ),
      child: pw.Text(
        'Disclaimer: This report is automatically compiled from your personal FitLoop app logs and is intended for wellness and fitness tracking purposes only. It is not intended as medical advice, clinical diagnosis, or treatment. Consult a physician before beginning any new diet or exercise regimen.',
        style: const pw.TextStyle(
          color: neutralGrey,
          fontSize: 7,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  // =========================================================================
  // REUSABLE PDF ATOMS
  // =========================================================================
  static pw.Widget _buildSectionHeader(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 3,
          height: 12,
          color: tealPrimary,
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          title,
          style: pw.TextStyle(
            color: darkSlate,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMetricCard(
    String label,
    String value, {
    String? subtitle,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderGrey),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(color: neutralGrey, fontSize: 8),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: darkSlate,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(color: neutralGrey, fontSize: 7),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildKeyValueItem(String key, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          key,
          style: const pw.TextStyle(color: neutralGrey, fontSize: 8),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: darkSlate,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildEmptyNotice(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderGrey, width: 0.5),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          color: neutralGrey,
          fontSize: 8,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: darkSlate,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: darkSlate,
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
