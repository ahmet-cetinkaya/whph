import 'package:flutter/widgets.dart';
import 'package:whph/domain/features/shared/constants/app_assets.dart';

class AppLogo extends StatelessWidget {
  final double width;
  final double height;

  const AppLogo({super.key, this.width = 100, this.height = 100});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logoAdaptiveFg,
      width: width,
      height: height,
    );
  }
}
