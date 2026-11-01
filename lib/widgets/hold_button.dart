import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A button that only fires after being held, with a progress ring showing how
/// close it is. Prevents pocket presses without making the action slow, and
/// exposes a plain tap action to screen readers, which can't press and hold.
class HoldButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  final String semanticLabel;
  final Widget child;
  final Color color;
  final Color ringColor;
  final double size;
  final Duration holdFor;

  const HoldButton({
    super.key,
    required this.onConfirmed,
    required this.semanticLabel,
    required this.child,
    required this.color,
    this.ringColor = Colors.white,
    this.size = 220,
    this.holdFor = const Duration(milliseconds: 1200),
  });

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: widget.holdFor)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          _progress.value = 0;
          widget.onConfirmed();
        }
      });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    _progress.forward();
  }

  void _release() {
    if (_progress.isAnimating) _progress.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      onTap: widget.onConfirmed,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, child) => Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35),
                  blurRadius: 28 + 20 * _progress.value,
                  spreadRadius: 4 + 8 * _progress.value,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      value: _progress.value,
                      strokeWidth: 6,
                      color: widget.ringColor,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
                child!,
              ],
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
