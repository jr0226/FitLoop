import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/health_report_data.dart';
import '../services/health_report_service.dart';
import '../services/health_report_pdf_builder.dart';

class HealthReportScreen extends StatefulWidget {
  const HealthReportScreen({super.key});

  @override
  State<HealthReportScreen> createState() => _HealthReportScreenState();
}

class _HealthReportScreenState extends State<HealthReportScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  HealthReportPeriodType _selectedPeriod = HealthReportPeriodType.last7Days;
  late DateTime _startDate;
  late DateTime _endDate;

  bool _isLoading = true;
  String? _errorMessage;
  HealthReportData? _reportData;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _setPredefinedRange(HealthReportPeriodType.last7Days);
    _loadReport();
  }

  void _setPredefinedRange(HealthReportPeriodType period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _selectedPeriod = period;
    if (period == HealthReportPeriodType.last7Days) {
      _startDate = today.subtract(const Duration(days: 6));
      _endDate = today;
    } else if (period == HealthReportPeriodType.last30Days) {
      _startDate = today.subtract(const Duration(days: 29));
      _endDate = today;
    }
  }

  Future<void> _loadReport() async {
    if (_user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please sign in to generate a health report.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await HealthReportService.instance.fetchReportData(
        uid: _user.uid,
        startDate: _startDate,
        endDate: _endDate,
        periodType: _selectedPeriod,
      );

      final bytes = await HealthReportPdfBuilder.buildPdf(data);

      if (mounted) {
        setState(() {
          _reportData = data;
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to generate PDF report: $e';
        });
      }
    }
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: _startDate.isAfter(today) ? today : _startDate,
        end: _endDate.isAfter(today) ? today : _endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!mounted) return;
      if (picked.start.isAfter(picked.end)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start date cannot be after end date.')),
        );
        return;
      }

      setState(() {
        _selectedPeriod = HealthReportPeriodType.custom;
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadReport();
    }
  }

  Future<void> _shareReport() async {
    if (_pdfBytes == null || _reportData == null) return;
    try {
      await Printing.sharePdf(
        bytes: _pdfBytes!,
        filename: _reportData!.defaultFileName,
      );
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DateFormat formatter = DateFormat('MMM d, yyyy');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Health & Fitness Report',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        actions: [
          if (_pdfBytes != null)
            IconButton(
              icon: Icon(Icons.share_rounded, color: theme.colorScheme.primary),
              tooltip: 'Share Report',
              onPressed: _shareReport,
            ),
        ],
      ),
      body: Column(
        children: [
          // Period Selector Bar
          Container(
            color: theme.cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Last 7 Days'),
                            selected: _selectedPeriod ==
                                HealthReportPeriodType.last7Days,
                            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: _selectedPeriod ==
                                      HealthReportPeriodType.last7Days
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                              fontWeight: _selectedPeriod ==
                                      HealthReportPeriodType.last7Days
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected && !_isLoading) {
                                _setPredefinedRange(
                                    HealthReportPeriodType.last7Days);
                                _loadReport();
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Last 30 Days'),
                            selected: _selectedPeriod ==
                                HealthReportPeriodType.last30Days,
                            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: _selectedPeriod ==
                                      HealthReportPeriodType.last30Days
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                              fontWeight: _selectedPeriod ==
                                      HealthReportPeriodType.last30Days
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected && !_isLoading) {
                                _setPredefinedRange(
                                    HealthReportPeriodType.last30Days);
                                _loadReport();
                              }
                            },
                          ),
                          ActionChip(
                            avatar: Icon(Icons.date_range, size: 16, color: theme.colorScheme.primary),
                            label: Text(
                              _selectedPeriod == HealthReportPeriodType.custom
                                  ? '${DateFormat('MM/dd').format(_startDate)} - ${DateFormat('MM/dd').format(_endDate)}'
                                  : 'Custom Range',
                            ),
                            backgroundColor: _selectedPeriod ==
                                    HealthReportPeriodType.custom
                                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                : theme.colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: _selectedPeriod ==
                                      HealthReportPeriodType.custom
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                              fontWeight: _selectedPeriod ==
                                      HealthReportPeriodType.custom
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onPressed: _isLoading ? null : _pickCustomDateRange,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Range: ${formatter.format(_startDate)} – ${formatter.format(_endDate)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Main View: Preview or Loading
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      bottomNavigationBar: _pdfBytes != null && !_isLoading
          ? Container(
              color: theme.cardColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Print / Save PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          if (_pdfBytes != null) {
                            await Printing.layoutPdf(
                              onLayout: (_) => _pdfBytes!,
                              name: _reportData?.defaultFileName ??
                                  'FitLoop_Report.pdf',
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _shareReport,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              'Generating your FitLoop report...',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Compiling nutrition, workouts & measurements',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadReport,
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfBytes == null) {
      return const Center(child: Text('No PDF data available.'));
    }

    return PdfPreview(
      build: (format) => _pdfBytes!,
      useActions: false, // We provide clean, custom FitLoop bottom action buttons
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      loadingWidget: const Center(
        child: CircularProgressIndicator(color: Colors.teal),
      ),
      pdfFileName: _reportData?.defaultFileName ?? 'FitLoop_Report.pdf',
    );
  }
}
