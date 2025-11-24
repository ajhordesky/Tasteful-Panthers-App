import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdh_recommendation/widgets/weekly_suggestion_card.dart';
import 'package:pdh_recommendation/widgets/fab_cluster.dart';

class MainSuggestionScreen extends StatefulWidget {
  const MainSuggestionScreen({super.key});

  @override
  State<MainSuggestionScreen> createState() => _MainSuggestionScreenState();
}

class _MainSuggestionScreenState extends State<MainSuggestionScreen> {
  late final Stream<QuerySnapshot> _suggestionsStream;
  final Set<String> _likesPatched = {}; // track docs we've added likes field to

  @override
  void initState() {
    super.initState();
    final weekAgo = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 7)),
    );
    _suggestionsStream = FirebaseFirestore.instance
        .collection('suggestions')
        .where('timestamp', isGreaterThanOrEqualTo: weekAgo)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: _suggestionsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No suggestions this week.'));
              }
              // Sort the fetched suggestions by like count descending while retaining limit and time filter
              final docs = [...snapshot.data!.docs];
              // Patch missing likes fields once per doc & collect likes safely from map
              final Map<String, int> likesCache = {};
              for (final d in docs) {
                final data = d.data() as Map<String, dynamic>?;
                if (data == null) {
                  likesCache[d.id] = 0;
                  continue;
                }
                if (!data.containsKey('likes')) {
                  likesCache[d.id] = 0;
                  if (!_likesPatched.contains(d.id)) {
                    _likesPatched.add(d.id);
                    d.reference.update({'likes': 0}).catchError((e) => debugPrint('Failed to set likes=0 for ${d.id}: $e'));
                  }
                } else {
                  final raw = data['likes'];
                  likesCache[d.id] = raw is int
                      ? raw
                      : (raw is num ? raw.toInt() : 0);
                }
              }
              docs.sort((a, b) {
                final aInt = likesCache[a.id] ?? 0;
                final bInt = likesCache[b.id] ?? 0;
                return bInt.compareTo(aInt);
              });
              return WeeklySuggestionCard(
                suggestionDocs: docs,
                title: "Top Liked Suggestions (This Week)",
              );
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: const FabCluster(),
    );
  }
}