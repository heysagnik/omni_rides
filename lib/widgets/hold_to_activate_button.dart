import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A premium, customizable press-and-hold interaction button.
///
/// Prevents accidental triggers (e.g. for emergency SOS requests)
/// by requiring the user to hold down the button for a specific duration
/// before executing the callback.
///
/// Supports two layouts:
/// - Rectangular: Elegant full-width container with a horizontal progress fill (e.g., Safety Screen).
/// - Circular: Sleek map floating action button with a circular progress stroke (e.g., In Transit Screen).
class HoldToActivateButton extends StatefulWidget {
  final VoidCallback onTriggered;
  final String label;
  final String releaseLabel;
  final bool isBusy;
  final Duration duration;
  final bool isCircular;
  final Color color;
  final double size;
  final double height;

  const HoldToActivateButton({
    super.key,
    required this.onTriggered,
    this.label = 'PRESS & HOLD FOR 2s TO SOS',
    this.releaseLabel = 'RELEASE TO CANCEL',
    this.isBusy = false,
    this.duration = const Duration(seconds: 2),
    this.isCircular = false,
    this.color = AppColors.error,
    this.size = 52.0,
    this.height = 50.0,
  });

  @override
  State<HoldToActivateButton> createState() => _HoldToActivateButtonState();
}

class _HoldToActivateButtonState extends State<HoldToActivateButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        setState(() => _isHolding = false);
        widget.onTriggered();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    if (widget.isBusy) return;
    setState(() => _isHolding = true);
    _controller.forward();
  }

  void _onTapUp(_) {
    if (widget.isBusy) return;
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
    setState(() => _isHolding = false);
  }

  void _onTapCancel() {
    if (widget.isBusy) return;
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
    setState(() => _isHolding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCircular) {
      return GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _isHolding ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: widget.size + 8,
                height: widget.size + 8,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CircularProgressIndicator(
                      value: _controller.value,
                      strokeWidth: 4.0,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                    );
                  },
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: widget.isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Rectangular full-width button
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _isHolding ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Container(
                height: widget.height,
                width: double.infinity,
                color: Colors.white,
                alignment: Alignment.center,
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _controller.value,
                      child: Container(
                        color: widget.color.withValues(alpha: 0.15),
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: widget.isBusy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.color,
                          ),
                        )
                      : Text(
                          _isHolding ? widget.releaseLabel : widget.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: widget.color,
                            letterSpacing: 0.8,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
