import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CitrusHeader extends StatelessWidget {
  final double height;
  final String? title;
  final bool showBackButton;
  final Widget? child;

  const CitrusHeader({
    super.key,
    this.height = 200,
    this.title,
    this.showBackButton = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(
        gradient: AppTheme.orangeGradient,
      ),
      child: Stack(
        children: [
          // Background Citrus Art Painting
          Positioned.fill(
            child: CustomPaint(
              painter: CitrusHeaderPainter(),
            ),
          ),
          
          // Content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showBackButton)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      if (title != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          title!,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ],
                    ],
                  ),
                  if (child != null) ...[
                    const Spacer(),
                    child!,
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CitrusHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Paints a few citrus slices at strategic corners as seen in the screenshots
    final paintOrangeOuter = Paint()..color = const Color(0xFFF37A20).withOpacity(0.45);
    final paintOrangeInner = Paint()..color = const Color(0xFFFFB74D).withOpacity(0.45);
    final paintLemonOuter = Paint()..color = const Color(0xFFFBC02D).withOpacity(0.45);
    final paintLemonInner = Paint()..color = const Color(0xFFFFF59D).withOpacity(0.45);
    final paintGrapefruitOuter = Paint()..color = const Color(0xFFE57373).withOpacity(0.45);
    final paintGrapefruitInner = Paint()..color = const Color(0xFFFFCDD2).withOpacity(0.45);
    final paintWhite = Paint()..color = Colors.white.withOpacity(0.45);
    final paintLeaf = Paint()..color = const Color(0xFF4CAF50).withOpacity(0.45);
    final paintDarkLeaf = Paint()..color = const Color(0xFF2E7D32).withOpacity(0.45);

    // Helper to draw a citrus slice
    void drawCitrusSlice(Canvas canvas, Offset center, double radius, Paint outerPaint, Paint innerPaint) {
      // Outer rind
      canvas.drawCircle(center, radius, outerPaint);
      // Pith (white circle)
      canvas.drawCircle(center, radius * 0.9, paintWhite);
      // Core (inner color)
      canvas.drawCircle(center, radius * 0.82, innerPaint);
      
      // Draw 8 wedges
      final wedgePaint = Paint()
        ..color = paintWhite.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08;
      
      for (int i = 0; i < 8; i++) {
        double angle = i * pi / 4;
        canvas.drawLine(
          center,
          Offset(center.dx + radius * 0.8 * cos(angle), center.dy + radius * 0.8 * sin(angle)),
          wedgePaint,
        );
      }
      
      // Center pith
      canvas.drawCircle(center, radius * 0.15, paintWhite);
    }

    // Helper to draw a leaf
    void drawLeaf(Canvas canvas, Offset stem, Offset tip, Paint leafPaint) {
      final path = Path();
      path.moveTo(stem.dx, stem.dy);
      // Control points for a leaf shape
      final ctrl1 = Offset((stem.dx + tip.dx) / 2 - 15, (stem.dy + tip.dy) / 2 + 15);
      final ctrl2 = Offset((stem.dx + tip.dx) / 2 + 15, (stem.dy + tip.dy) / 2 - 15);
      
      path.quadraticBezierTo(ctrl1.dx, ctrl1.dy, tip.dx, tip.dy);
      path.quadraticBezierTo(ctrl2.dx, ctrl2.dy, stem.dx, stem.dy);
      path.close();
      
      canvas.drawPath(path, leafPaint);
      
      // Draw leaf vein line
      final veinPaint = Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(stem, tip, veinPaint);
    }

    // Draw background blob wave
    final wavePaint = Paint()..color = Colors.white.withOpacity(0.08);
    final wavePath = Path();
    wavePath.moveTo(0, size.height * 0.5);
    wavePath.quadraticBezierTo(size.width * 0.35, size.height * 0.3, size.width * 0.7, size.height * 0.6);
    wavePath.quadraticBezierTo(size.width * 0.85, size.height * 0.75, size.width, size.height * 0.55);
    wavePath.lineTo(size.width, 0);
    wavePath.lineTo(0, 0);
    wavePath.close();
    canvas.drawPath(wavePath, wavePaint);

    // 1. Draw leaves for orange on top-left
    drawLeaf(canvas, const Offset(20, 10), const Offset(-10, 50), paintDarkLeaf);
    drawLeaf(canvas, const Offset(35, 5), const Offset(70, -5), paintLeaf);

    // 2. Draw Orange slice at top-left
    drawCitrusSlice(canvas, const Offset(-25, -25), 75, paintOrangeOuter, paintOrangeInner);

    // 3. Draw Grapefruit slice peaking at top-right
    drawCitrusSlice(canvas, Offset(size.width * 0.98, -20), 65, paintGrapefruitOuter, paintGrapefruitInner);

    // 4. Draw Lemon slice peaking on the right side
    drawCitrusSlice(canvas, Offset(size.width + 20, size.height * 0.5), 55, paintLemonOuter, paintLemonInner);
    
    // 5. Draw another orange slice on top center-right
    drawCitrusSlice(canvas, Offset(size.width * 0.76, 10), 45, paintOrangeOuter, paintOrangeInner);
    drawLeaf(canvas, Offset(size.width * 0.76 + 20, 10), Offset(size.width * 0.76 + 50, 30), paintLeaf);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
