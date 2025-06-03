import 'package:flutter/material.dart';

abstract class ISupportDialogService {
  Future<void> checkAndShowSupportDialog(BuildContext context);
}
