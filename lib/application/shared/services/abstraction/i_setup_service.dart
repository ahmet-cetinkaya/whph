import 'package:flutter/material.dart';

abstract class ISetupService {
  Future<void> setupEnvironment();
  Future<void> checkForUpdates(BuildContext context);
}
