import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/formatters.dart';

/// Text that ticks every second with the time elapsed since [since].
class ElapsedTimer extends StatefulWidget {
  final DateTime since;
  final TextStyle? style;

  const ElapsedTimer({super.key, required this.since, this.style});

  @override
  State<ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<ElapsedTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var elapsed = DateTime.now().difference(widget.since);
    if (elapsed.isNegative) elapsed = Duration.zero;
    return Text(formatClock(elapsed), style: widget.style);
  }
}
