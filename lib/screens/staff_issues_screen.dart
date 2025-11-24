import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh_recommendation/widgets/individual_issue_card.dart';

class StaffIssuesScreen extends StatelessWidget {
  const StaffIssuesScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Issues'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _IssuesGroup(title: 'Open', status: 'open'),
            _IssuesGroup(title: 'In progress', status: 'in_progress'),
            _IssuesGroup(title: 'Resolved', status: 'resolved'),
          ],
        ),
      ),
    );
  }
}
class _IssuesGroup extends StatelessWidget {
  final String title;
  final String status;
  const _IssuesGroup({required this.title, required this.status});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('issues')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('Error: ${snapshot.error}'),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: SizedBox(
                    height: 40,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  child: Text('None'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                itemBuilder: (_, i) => IndividualIssueCard(doc: docs[i]),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: docs.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
              );
            },
          ),
        ],
      ),
    );
  }
}