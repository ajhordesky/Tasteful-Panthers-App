import 'package:flutter/material.dart';
import 'package:pdh_recommendation/services/tasteful_twin_service.dart';

class TwinComparisonPopup extends StatelessWidget {
  final List<TwinComparisonRow> rows;
  final List<String> twinIds;

  const TwinComparisonPopup({required this.rows, required this.twinIds});

  /// Helper to shorten long userIds for display
  String shortenId(String id) {
    return id.length > 6 ? id.substring(0, 6) : id;
  }

  /// Helper to truncate long meal names with ellipsis
  String truncateMeal(String name, {int max = 24}) {
    if (name.length <= max) return name;
    if (max <= 1) return name.substring(0, max);
    return '${name.substring(0, max - 1)}…';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Tasteful Twins"),
      content: SingleChildScrollView(
        scrollDirection: Axis.horizontal, // allow horizontal scrolling
        child: DataTable(
          columnSpacing: 16.0, // reduce spacing between columns
          columns: [
            const DataColumn(
              label: Text("Meal", style: TextStyle(fontSize: 12)),
            ),
            const DataColumn(
              label: Text("Me", style: TextStyle(fontSize: 12)),
            ),
            ...twinIds.map(
              (id) => DataColumn(
                label: Text(
                  shortenId(id), // show only first few chars
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
          rows: rows.map((row) {
            final bool isSimilarityRow = row.foodName.startsWith('Twin Similarity Scores');
            return DataRow(
              color: row.highlight
                  ? WidgetStateProperty.all(Colors.yellow[100])
                  : isSimilarityRow
                      ? WidgetStateProperty.all(Colors.blue[50])
                      : null,
              cells: [
                DataCell(
                  Tooltip(
                    message: row.foodName,
                    child: Text(
                      truncateMeal(row.foodName),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSimilarityRow ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    row.highlight ? '(?)' : row.meDisplay,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: row.highlight ? FontStyle.italic : FontStyle.normal,
                      fontWeight: isSimilarityRow ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                ...twinIds.map(
                  (id) => DataCell(
                    Text(
                      row.twinRatings[id] ?? "-",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSimilarityRow ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}