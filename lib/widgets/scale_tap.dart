import 'package:flutter/material.dart';

class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isInteractive = widget.onTap != null;

    return GestureDetector(
      onTapDown: (_) => isInteractive ? _controller.forward() : null,
      onTapUp: (_) => isInteractive ? _controller.reverse() : null,
      onTapCancel: () => isInteractive ? _controller.reverse() : null,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
