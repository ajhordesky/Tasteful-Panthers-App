import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class DetailedIssuePopup extends StatefulWidget {
  final DocumentSnapshot doc;
  const DetailedIssuePopup({super.key, required this.doc});

  @override
  State<DetailedIssuePopup> createState() => _DetailedIssuePopupState();
}

class _DetailedIssuePopupState extends State<DetailedIssuePopup> {
  late String _selectedStatus;
  final TextEditingController _noteController = TextEditingController();
  bool _saving = false;

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
  void initState() {
    super.initState();
    final data = (widget.doc.data() as Map<String, dynamic>?) ?? {};
    _selectedStatus = (data['status'] as String?) ?? 'open';
    final String? statusNote = (data['statusNote'] as String?)?.trim();
    if (statusNote != null && statusNote.isNotEmpty) {
      _noteController.text = statusNote;
    }
  }

  Future<void> _saveStatus(DocumentReference ref) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final note = _noteController.text.trim();
      final Map<String, dynamic> updateData = {
        'status': _selectedStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (note.isNotEmpty) {
        updateData['statusNote'] = note;
      } else {
        updateData['statusNote'] = FieldValue.delete();
      }
      if (uid != null) {
        updateData['statusUpdatedBy'] = uid;
      }
      await ref.update(updateData);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = (widget.doc.data() as Map<String, dynamic>?) ?? {};
    final mealName = (data['mealName'] as String?)?.trim();
    final text = (data['text'] as String?)?.trim() ?? '';
    final status = data['status'] as String?;
    final userId = data['userId'] as String?;
    final dateKey = data['dateKey'] as String?;
    final createdAtTs = data['createdAt'];
    DateTime? createdAt;
    if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();

    final List<dynamic> imageUrlsDyn = (data['imageUrls'] as List?) ?? const [];
    final imageUrls = imageUrlsDyn.map((e) => e.toString()).toList();
    final String? videoUrl = (data['videoUrl'] as String?);
    final List<dynamic> tagsDyn = (data['tags'] as List?) ?? const [];
    final tags = tagsDyn.map((e) => e.toString()).toList();
    final String? statusNote = (data['statusNote'] as String?)?.trim();

    final createdFmt = createdAt != null ? timeago.format(createdAt) : '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      insetPadding: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      mealName?.isNotEmpty == true ? mealName! : 'Unknown meal',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.1),
                      border: Border.all(color: _statusColor(status).withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(fontSize: 12, color: _statusColor(status)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              if (text.isNotEmpty)
                Text(
                  text,
                  style: const TextStyle(fontSize: 14.0),
                ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12.0),
                Wrap(
                  spacing: 6,
                  runSpacing: -6,
                  children: tags
                      .map((t) => Chip(
                            label: Text(t),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ],
              if (imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12.0),
                const Text('Images', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8.0),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrls[i],
                        width: 120,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: imageUrls.length,
                  ),
                ),
              ],
              if (videoUrl != null && videoUrl.isNotEmpty) ...[
                const SizedBox(height: 12.0),
                Row(
                  children: const [
                    Icon(Icons.videocam, size: 18),
                    SizedBox(width: 6),
                    Text('Includes a video'),
                  ],
                ),
              ],
              if (statusNote != null && statusNote.isNotEmpty) ...[
                const SizedBox(height: 12.0),
                const Text('Handler note', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4.0),
                Text(statusNote),
              ],
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    createdFmt,
                    style: const TextStyle(fontSize: 12.0, color: Colors.black45),
                  ),
                  Text(
                    '${_anonUser(userId)}${dateKey != null ? ' • $dateKey' : ''}',
                    style: const TextStyle(fontSize: 12.0, color: Colors.black45),
                  ),
                ],
              ),

              const SizedBox(height: 16.0),
              const Divider(),
              const SizedBox(height: 8.0),
              const Text('Update status', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8.0),
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                ],
                onChanged: (v) => setState(() => _selectedStatus = v ?? 'open'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8.0),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Handler note',
                  hintText: 'Explain the state or resolution…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12.0),
              const SizedBox(height: 12.0),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : () => _saveStatus(widget.doc.reference),
                      icon: _saving
                          ? const SizedBox(
                              width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
