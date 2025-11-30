import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'detailed_issue_popup.dart';

class IndividualIssueCard extends StatelessWidget {
  final DocumentSnapshot doc;

  const IndividualIssueCard({super.key, required this.doc});

  String _statusLabel(String? status) {
    switch ((status ?? 'open').toLowerCase()) {
      case 'in_progress':
        return 'In progress';
      case 'resolved':
        return 'Resolved';
      default:
        return 'Open';
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? 'open').toLowerCase()) {
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.redAccent;
    }
  }

  String _anonUser(String? userId) {
    if (userId == null || userId.isEmpty) return 'User • anon';
    final tail = userId.length <= 6 ? userId : userId.substring(userId.length - 6);
    return 'User • $tail';
  }

  @override
  Widget build(BuildContext context) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final mealName = (data['mealName'] as String?)?.trim();
    final text = (data['text'] as String?)?.trim() ?? '';
    final status = data['status'] as String?;
    final userId = data['userId'] as String?;
    final createdAtTs = data['createdAt'];
    DateTime? createdAt;
    if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();
    final relative = createdAt != null ? timeago.format(createdAt, locale: 'en_short') : '';

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => DetailedIssuePopup(doc: doc),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    mealName?.isNotEmpty == true ? mealName! : 'Unknown meal',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    border: Border.all(color: _statusColor(status).withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(fontSize: 11, color: _statusColor(status)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            Text(
              text.isEmpty ? '(No description provided)' : text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.0, color: Colors.black87),
            ),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  relative,
                  style: const TextStyle(fontSize: 11.0, color: Colors.black45),
                ),
                Text(
                  _anonUser(userId),
                  style: const TextStyle(fontSize: 11.0, color: Colors.black45),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
