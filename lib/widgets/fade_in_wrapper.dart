import 'package:flutter/material.dart';

class FadeInWrapper extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;

  const FadeInWrapper({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 60),
  });

  @override
  State<FadeInWrapper> createState() => _FadeInWrapperState();
}

class _FadeInWrapperState extends State<FadeInWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _yTranslation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _yTranslation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0.0, _yTranslation.value),
            child: widget.child,
          ),
        );
      },
    );
  }
}
