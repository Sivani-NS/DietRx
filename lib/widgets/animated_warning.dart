import 'package:flutter/material.dart';

class AnimatedWarningIcon extends StatefulWidget {
  final double top;
  final double? left;
  final double? right;
  final double size;
  final double delay;
  final bool isLeft;
  final Color color; 

  const AnimatedWarningIcon({
    super.key,
    required this.top,
    this.left,
    this.right,
    required this.size,
    this.delay = 0.0,
    required this.isLeft,
    required this.color, 
  });

  @override
  State<AnimatedWarningIcon> createState() => _AnimatedWarningIconState();
}

class _AnimatedWarningIconState extends State<AnimatedWarningIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
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
    return Positioned(
      top: widget.top,
      left: widget.left,
      right: widget.right,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double t = Curves.easeOutExpo.transform(_controller.value);

          double startX = widget.isLeft ? -150.0 : 150.0;
          double currentX = startX * (1 - t);

          double entranceRotation = (widget.isLeft ? -0.5 : 0.5) * (1 - t);
          double finalStaticTilt = widget.isLeft ? -0.15 : 0.15;

          return Transform.translate(
            offset: Offset(currentX, 0),
            child: Transform.rotate(
              angle: entranceRotation + finalStaticTilt,
              child: child,
            ),
          );
        },
        child: Icon(Icons.no_meals, color: widget.color, size: widget.size),
      ),
    );
  }
}
