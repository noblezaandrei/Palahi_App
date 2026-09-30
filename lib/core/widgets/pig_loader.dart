import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import 'pig_icon.dart';

/// The app's loading animation: the pig hopping, with its shadow shrinking
/// as it jumps and three dots pulsing underneath. Used wherever a screen or
/// list is waiting for data, instead of a plain spinner.
class PigLoader extends StatefulWidget {
  /// Height of the pig; everything else scales with it.
  final double size;

  /// Optional line under the dots, e.g. "Loading bookings…".
  final String? message;

  const PigLoader({super.key, this.size = 56, this.message});

  @override
  State<PigLoader> createState() => _PigLoaderState();
}

class _PigLoaderState extends State<PigLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final hop = size * 0.35;

    return Semantics(
      label: widget.message ?? 'Loading',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size * 1.2,
            height: size + hop,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // 0 → 1 → 0 over each cycle: up, then down.
                final t = math.sin(_controller.value * math.pi);
                // A little squash on landing, stretch in the air.
                final squash = 1 - (1 - t) * 0.12;
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Shadow, smaller and fainter the higher the pig is.
                    Container(
                      width: size * (0.7 - 0.3 * t),
                      height: size * 0.1,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(
                          (60 - 35 * t).round(),
                        ),
                        borderRadius: BorderRadius.circular(size),
                      ),
                    ),
                    Positioned(
                      bottom: size * 0.04 + hop * t,
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.diagonal3Values(
                          1 + (1 - squash) * 0.8,
                          squash,
                          1,
                        ),
                        child: PigIcon(size: size),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: size * 0.18),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  _Dot(
                    size: math.max(5, size * 0.11),
                    // Each dot peaks a third of a cycle after the last.
                    phase: (_controller.value - i / 3) % 1,
                  ),
              ],
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 10),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;
  final double phase;

  const _Dot({required this.size, required this.phase});

  @override
  Widget build(BuildContext context) {
    final pulse = math.sin(phase * math.pi).clamp(0.0, 1.0);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: size * 0.4),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(AppColors.primaryLighter, AppColors.primary, pulse),
      ),
      transform: Matrix4.translationValues(0, -size * 0.6 * pulse, 0),
    );
  }
}

/// Fades and slides [child] up into place when it first appears. List items
/// pass their [index] so they arrive one after another (capped, so a long
/// list doesn't keep the last items waiting).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;

  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 45 * math.min(widget.index, 6));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// A softly pulsing grey block, shown in place of a photo while it loads.
class LoadingPulse extends StatefulWidget {
  const LoadingPulse({super.key});

  @override
  State<LoadingPulse> createState() => _LoadingPulseState();
}

class _LoadingPulseState extends State<LoadingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: double.infinity,
        height: double.infinity,
        color: Color.lerp(
          Colors.grey.shade200,
          Colors.grey.shade100,
          Curves.easeInOut.transform(_controller.value),
        ),
      ),
    );
  }
}
