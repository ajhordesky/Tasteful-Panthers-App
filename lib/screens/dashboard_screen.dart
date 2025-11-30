import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh_recommendation/models/meal.dart';
import 'package:pdh_recommendation/services/favorites_service.dart';
import 'package:pdh_recommendation/services/tasteful_twin_service.dart';

import 'package:pdh_recommendation/widgets/dashboard_crowd_card.dart';
import 'package:pdh_recommendation/widgets/dashboard_favorites_card.dart';
import 'package:pdh_recommendation/widgets/dashboard_popularity_card.dart';
import 'package:pdh_recommendation/widgets/dashboard_prediction_card.dart';
import 'package:pdh_recommendation/widgets/dashboard_realized_card.dart';
import 'package:pdh_recommendation/widgets/dashboard_suggestion_card.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late String _userId = FirebaseAuth.instance.currentUser?.uid ?? "";
  late Future<List<Meal>> _favorites;
  late Future<List<String>> _twinSuggestions;
  late Future<List<String>> _realizedSuggestions;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    _twinSuggestions = TastefulTwinService().getTopFoodsFromTwins(_userId);
    _favorites = FavoritesService().getTodaysFavorites();
    _realizedSuggestions = _getRealizedSuggestions();
  }

  Future<List<String>> _getRealizedSuggestions() async {
    try {
      // Fetch today's meals
      final now = DateTime.now();
      final todayKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final mealSnapshot = await FirebaseFirestore.instance
          .collection('meals')
          .doc(todayKey)
          .collection('meals')
          .get();
      final todayMealNames = mealSnapshot.docs
          .map((d) => (d.data()['name'] as String?)?.trim().toLowerCase())
          .whereType<String>()
          .toSet();

      if (todayMealNames.isEmpty) return [];

      // Fetch recent suggestions (limit to avoid large reads)
      final suggestionSnapshot = await FirebaseFirestore.instance
          .collection('suggestions')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final matched = <String>{};
      for (final doc in suggestionSnapshot.docs) {
        final data = doc.data();
        final titleRaw = data['title'];
        if (titleRaw is! String) continue;
        final normalized = titleRaw.trim().toLowerCase();
        if (todayMealNames.contains(normalized)) {
          matched.add(titleRaw.trim());
          if (matched.length >= 3) break; // limit to 3 per requirements
        }
      }
      return matched.toList();
    } catch (e) {
      debugPrint('Error fetching realized suggestions: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Recommendations Section ---
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What’s Tasty Today?",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),

                     FutureBuilder<List<String>>(
                      future: _twinSuggestions,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return DashboardSuggestionCard(
                            suggestions: [],
                            isLoading: true,
                            userId: _userId,
                          );
                        }
                        if (snapshot.hasError) {
                          return DashboardSuggestionCard(
                            suggestions: [],
                            userId: _userId,
                          );
                        }
                        final foods = snapshot.data ?? [];
                        return DashboardSuggestionCard(
                          suggestions: foods,
                          userId: _userId,
                        );
                      },
                    ),
                      const DashboardCrowdCard(),

                      FutureBuilder<List<Meal>>(
                        future: _favorites,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const DashboardFavoritesCard(favorites: []);
                          }
                          if (snapshot.hasError) {
                            return const DashboardFavoritesCard(favorites: []);
                          }
                          final meals = snapshot.data ?? [];
                          return DashboardFavoritesCard(
                            favorites: meals.map((m) => m.name).toList(),
                          );
                        },
                      ),

                      FutureBuilder<List<String>>(
                        future: _realizedSuggestions,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const DashboardRealizedCard(realizedSuggestions: []);
                          }
                          final realized = snapshot.data ?? [];
                          return DashboardRealizedCard(realizedSuggestions: realized);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // --- Rankings Section ---
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "How am I ranked?",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      const DashboardPredictionsCard(),
                      DashboardPopularityCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}