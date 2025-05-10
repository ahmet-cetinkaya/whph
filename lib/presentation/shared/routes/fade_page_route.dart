import 'package:flutter/material.dart';

class FadePageRoute<T> extends PageRoute<T> {
  final Widget child;

  FadePageRoute({
    required this.child,
    super.settings,
  });

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _FadePageTransition(
      primaryAnimation: animation,
      secondaryAnimation: secondaryAnimation,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}

class _FadePageTransition extends StatefulWidget {
  final Animation<double> primaryAnimation;
  final Animation<double> secondaryAnimation;
  final Color backgroundColor;
  final Widget child;

  const _FadePageTransition({
    required this.primaryAnimation,
    required this.secondaryAnimation,
    required this.backgroundColor,
    required this.child,
  });

  @override
  State<_FadePageTransition> createState() => _FadePageTransitionState();
}

class _FadePageTransitionState extends State<_FadePageTransition> {
  late final Animation<double> _enterAnimation;

  @override
  void initState() {
    super.initState();

    // Enter animation for the new page
    _enterAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: widget.primaryAnimation,
      curve: const Interval(
        0.0,
        1.0,
        curve: Curves.easeOutCubic,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.backgroundColor,
      child: FadeTransition(
        opacity: _enterAnimation,
        child: widget.child,
      ),
    );
  }
}
