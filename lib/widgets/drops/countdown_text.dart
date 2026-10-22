import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drop_state.dart';

/// "mm:ss" style countdown against the server clock. Calls [onElapsed] once when it reaches zero.
class CountdownText extends StatefulWidget {
  final DateTime target;
  final TextStyle? style;
  final String prefix;
  final String elapsedText;
  final VoidCallback? onElapsed;

  const CountdownText({
    super.key,
    required this.target,
    this.style,
    this.prefix = '',
    this.elapsedText = '00:00',
    this.onElapsed,
  });

  /// 4:07 / 1:02:09 / 2d 3h
  static String format(Duration d) {
    if (d.isNegative) d = Duration.zero;
    if (d.inHours >= 24) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) _fired = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = context.read<DropState>().timeLeft(widget.target);
    final elapsed = left <= Duration.zero;
    if (elapsed && !_fired && widget.onElapsed != null) {
      _fired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onElapsed!();
      });
    }
    return Text(
      '${widget.prefix}${elapsed ? widget.elapsedText : CountdownText.format(left)}',
      style: widget.style,
    );
  }
}
