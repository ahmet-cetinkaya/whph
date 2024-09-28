import 'package:flutter/material.dart';

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
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Icon(
                      data.icon,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      data.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
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
          ),
        );
      }).toList(),
    );
  }
}
