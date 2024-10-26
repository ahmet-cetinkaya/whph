import 'package:flutter/material.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/utils/app_theme_helper.dart';

class DetailTableRowData {
  final String label;
  final IconData icon;
  final Widget widget;

  DetailTableRowData({
    required this.label,
    required this.icon,
    required this.widget,
  });
}

class DetailTable extends StatelessWidget {
  final List<DetailTableRowData> rowData;

  const DetailTable({super.key, required this.rowData});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rowData.map((data) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenLarge)) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Row(
                            children: [
                              Icon(data.icon),
                              const SizedBox(width: 8),
                              Text(
                                data.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: data.widget,
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(data.icon),
                              ),
                              Text(
                                data.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        data.widget,
                      ],
                    );
                  }
                },
              ),
              Divider()
            ],
          ),
        );
      }).toList(),
    );
  }
}
