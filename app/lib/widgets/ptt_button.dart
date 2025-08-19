import 'dart:async';
import 'package:flutter/material.dart';

enum PTTButtonState { idle, pressed, disabled }

enum PTTEvent { press, hold, release }

class PTTButton extends StatefulWidget {
  final String label;
  final bool isEnabled;
  final Function(PTTEvent) onEvent;
  final Color primaryColor;
  final Color disabledColor;
  final IconData? icon;
  final Duration holdThreshold;

  const PTTButton({
    super.key,
    required this.label,
    required this.onEvent,
    this.isEnabled = true,
    this.primaryColor = Colors.blue,
    this.disabledColor = Colors.grey,
    this.icon,
    this.holdThreshold = const Duration(milliseconds: 500),
  });

  @override
  State<PTTButton> createState() => _PTTButtonState();
}

class _PTTButtonState extends State<PTTButton>
    with SingleTickerProviderStateMixin {
  PTTButtonState _buttonState = PTTButtonState.idle;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled) return;
    
    setState(() {
      _buttonState = PTTButtonState.pressed;
    });
    _animationController.forward();
    widget.onEvent(PTTEvent.press);
    
    // Start hold timer
    _holdTimer = Timer(widget.holdThreshold, () {
      if (_buttonState == PTTButtonState.pressed) {
        widget.onEvent(PTTEvent.hold);
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isEnabled) return;
    
    _handleRelease();
  }

  void _handleTapCancel() {
    if (!widget.isEnabled) return;
    
    _handleRelease();
  }

  void _handleRelease() {
    _holdTimer?.cancel();
    setState(() {
      _buttonState = PTTButtonState.idle;
    });
    _animationController.reverse();
    widget.onEvent(PTTEvent.release);
  }

  Color get _currentColor {
    if (!widget.isEnabled) return widget.disabledColor;
    return _buttonState == PTTButtonState.pressed
        ? widget.primaryColor.withValues(alpha: 0.8)
        : widget.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isEnabled ? _handleTapDown : null,
      onTapUp: widget.isEnabled ? _handleTapUp : null,
      onTapCancel: widget.isEnabled ? _handleTapCancel : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _currentColor,
                shape: BoxShape.circle,
                boxShadow: widget.isEnabled
                    ? [
                        BoxShadow(
                          color: _currentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null)
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 32,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}