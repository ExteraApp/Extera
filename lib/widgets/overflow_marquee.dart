import 'package:flutter/material.dart';

import 'package:marquee/marquee.dart'; // Make sure you have this package installed

class OverflowMarquee extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double height;
  final double velocity;

  const OverflowMarquee({
    super.key,
    required this.text,
    required this.style,
    this.height = 14,
    this.velocity = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: text, style: style);
        final textPainter = TextPainter(
          text: span,
          maxLines: 1,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final isOverflowing = textPainter.width > constraints.maxWidth;
        if (isOverflowing) {
          return SizedBox(
            height: height,
            child: Marquee(
              text: text,
              style: style,
              crossAxisAlignment: CrossAxisAlignment.start,
              velocity: velocity,
              startPadding: 0.0,
              blankSpace: 24,
              pauseAfterRound: const Duration(seconds: 2),
              accelerationDuration: const Duration(milliseconds: 500),
              accelerationCurve: Curves.linear,
              decelerationDuration: const Duration(milliseconds: 500),
              decelerationCurve: Curves.linear,
              scrollAxis: .horizontal,
            ),
          );
        } else {
          return Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
      },
    );
  }
}
