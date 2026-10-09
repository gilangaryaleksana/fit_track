import 'package:flutter/material.dart';

/// Two small bars showing progress through the live-activity flow
/// (1 = pick a type, 2 = tracking).
class StepIndicator extends StatelessWidget {
  final int step;
  const StepIndicator({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    Widget bar(bool done) => Container(
          width: 28,
          height: 4,
          decoration: BoxDecoration(
            color: done ? const Color(0xFF2EC4B6) : const Color(0xFFE4EAE9),
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        bar(step >= 1),
        const SizedBox(width: 6),
        bar(step >= 2),
      ],
    );
  }
}
