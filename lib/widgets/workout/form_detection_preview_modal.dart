import 'package:flutter/material.dart';

class FormDetectionPreviewModal extends StatefulWidget {
  final String exerciseName;

  const FormDetectionPreviewModal({super.key, required this.exerciseName});

  static Future<void> show(BuildContext context, {required String exerciseName}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FormDetectionPreviewModal(exerciseName: exerciseName),
    );
  }

  @override
  State<FormDetectionPreviewModal> createState() => _FormDetectionPreviewModalState();
}

class _FormDetectionPreviewModalState extends State<FormDetectionPreviewModal> {
  bool _isAnalyzing = true;
  final double _formScore = 0.94;
  final int _repCount = 8;
  final String _liveFeedback = "Optimal depth detected. Keep spine neutral.";

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark slate aesthetic
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.cyanAccent, Colors.purpleAccent],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.black87, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "AI Camera Form Coach",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.exerciseName,
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Camera Viewport Simulation
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Grid overlay lines
                Center(
                  child: Icon(
                    Icons.accessibility_new_rounded,
                    size: 130,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),

                // Simulated Pose Keypoints (Joint points & lines)
                CustomPaint(
                  painter: PoseSkeletonPainter(),
                ),

                // Top Live HUD
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                            SizedBox(width: 4),
                            Text(
                              "LIVE POSE AI",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          "Rep Counter: $_repCount",
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Live Feedback HUD
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.tealAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isAnalyzing ? "Calibrating camera position..." : _liveFeedback,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Real-time metrics
          Row(
            children: [
              _buildMetricCard("Form Accuracy", "${(_formScore * 100).toInt()}%", Colors.greenAccent),
              const SizedBox(width: 10),
              _buildMetricCard("Range of Motion", "Full (100%)", Colors.cyanAccent),
              const SizedBox(width: 10),
              _buildMetricCard("Tempo / Rep", "2.4 sec", Colors.amberAccent),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.done_all_rounded, color: Colors.black87),
              label: const Text(
                "Return to Workout Logger",
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PoseSkeletonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final head = Offset(size.width * 0.5, size.height * 0.32);
    final shoulderL = Offset(size.width * 0.42, size.height * 0.42);
    final shoulderR = Offset(size.width * 0.58, size.height * 0.42);
    final elbowL = Offset(size.width * 0.38, size.height * 0.52);
    final elbowR = Offset(size.width * 0.62, size.height * 0.52);
    final hipL = Offset(size.width * 0.44, size.height * 0.65);
    final hipR = Offset(size.width * 0.56, size.height * 0.65);
    final kneeL = Offset(size.width * 0.43, size.height * 0.8);
    final kneeR = Offset(size.width * 0.57, size.height * 0.8);

    // Draw lines
    canvas.drawLine(shoulderL, shoulderR, linePaint);
    canvas.drawLine(shoulderL, elbowL, linePaint);
    canvas.drawLine(shoulderR, elbowR, linePaint);
    canvas.drawLine(shoulderL, hipL, linePaint);
    canvas.drawLine(shoulderR, hipR, linePaint);
    canvas.drawLine(hipL, hipR, linePaint);
    canvas.drawLine(hipL, kneeL, linePaint);
    canvas.drawLine(hipR, kneeR, linePaint);

    // Draw joints
    for (final point in [head, shoulderL, shoulderR, elbowL, elbowR, hipL, hipR, kneeL, kneeR]) {
      canvas.drawCircle(point, 4, jointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
