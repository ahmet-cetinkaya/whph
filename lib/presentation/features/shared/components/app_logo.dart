import 'package:flutter/widgets.dart';

class AppLogo extends StatelessWidget {
  final double width;
  final double height;

  const AppLogo({super.key, this.width = 100, this.height = 100});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'lib/domain/features/shared/assets/whph_logo_adaptive_fg.png',
      width: width,
      height: height,
    );
  }
}
