import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/domain/features/shared/constants/app_info.dart';

class SupportMe extends StatelessWidget {
  SupportMe({super.key});

  final Uri _url = Uri.parse(AppInfo.supportUrl);

  Future<void> _launchUrl() async {
    var isOpened = await launchUrl(_url, mode: LaunchMode.externalApplication);
    if (!isOpened) {
      throw Exception("Could not open the url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(label: Text('Support me'), icon: Icon(Icons.coffee), onPressed: _launchUrl);
  }
}
