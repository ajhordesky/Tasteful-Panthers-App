import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdh_recommendation/widgets/individual_suggestion_card.dart';

class StaffSuggestionScreen extends StatelessWidget {
  const StaffSuggestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topQuery = FirebaseFirestore.instance
      .collection('suggestions')
      .orderBy('likes', descending: true)
      .orderBy('timestamp', descending: true)
      .limit(50);

    return Scaffold(
      appBar: AppBar(title: const Text('Staff Suggestions')),
      body: StreamBuilder<QuerySnapshot>(
        stream: topQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final raw = snapshot.data?.docs ?? [];
          // Patch missing likes fields and filter planned==true out
          final unplanned = <DocumentSnapshot>[];
          for (final d in raw) {
            final data = d.data() as Map<String, dynamic>?;
            if (data != null) {
              if (!data.containsKey('likes')) {
                d.reference.update({'likes': 0}).catchError((_) {});
              }
              if (data['planned'] == true) continue;
            }
            unplanned.add(d);
          }
          final topFive = unplanned.take(5).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Top 5 Most Liked Suggestions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (topFive.isEmpty)
                          const Text('No unplanned suggestions found.')
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: topFive.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => IndividualSuggestionCard(doc: topFive[i], isStaff: true),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Planned suggestions section
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('suggestions')
                      .where('planned', isEqualTo: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, plannedSnap) {
                    if (plannedSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (plannedSnap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text('Error loading planned suggestions: ${plannedSnap.error}'),
                      );
                    }
                    final plannedDocs = plannedSnap.data?.docs ?? [];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Planned Suggestions',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (plannedDocs.isEmpty)
                              const Text('No planned suggestions yet.')
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: plannedDocs.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, i) => IndividualSuggestionCard(doc: plannedDocs[i], isStaff: true),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
