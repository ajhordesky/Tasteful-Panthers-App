import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal.dart';
import '../models/review.dart';
import 'dart:math';

class TwinComparisonRow {
  final String foodName;
  final String meDisplay; // rating string for "Me", e.g. "5" or "-"
  final Map<String, String> twinRatings; // userId -> rating string
  final bool highlight;

  TwinComparisonRow({
    required this.foodName,
    required this.meDisplay,
    required this.twinRatings,
    this.highlight = false,
  });
}

class TastefulTwinService {

  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates up to 3 meal recommendations for the given user
  /// based on similarity with other users' reviews.
  Future<List<Meal>> getRecommendationsForUser(String userId) async {
    // Fetch reviews by the target user
    final userReviews = await _getUserReviews(userId);

    // Fetch all reviews (needed to compare against other users)
    final allReviews = await _getAllReviews();

    // Compute similarity scores between this user and all others
    final similarityScores = _calculateSimilarity(userId, userReviews, allReviews);

    // Pick top 5 most similar users (excluding self)
    final topTwins = similarityScores.entries
        .where((e) => e.key != userId)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final twinIds = topTwins.take(5).map((e) => e.key).toList();

    // Get meals those top twins rated highly
    final recommendedMeals = await _getHighlyRatedMealsByUsers(twinIds);

    // Exclude meals the user has already reviewed
    final reviewedMealNames = userReviews.map((r) => r.meal).toSet();
    final unseenMeals = recommendedMeals
        .where((meal) => !reviewedMealNames.contains(meal.name))
        .toList();

    return unseenMeals;
  }

  /// Fetches all reviews written by a specific user
  Future<List<Review>> _getUserReviews(String userId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
  }

  /// Fetches all reviews in the system
  Future<List<Review>> _getAllReviews() async {
    final snapshot = await _firestore.collection('reviews').get();
    return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
  }

    /// Calculates similarity between target user and others using
    /// a weighted Pearson correlation with optional Jaccard overlap multiplier.
    /// - Mean-center ratings to remove user bias (users who rate generally higher/lower).
    /// - Require a minimum number of common meals to consider (minCommon = 3).
    /// - Apply shrinkage: similarity *= (nCommon / (nCommon + shrinkK)) to penalize tiny overlaps.
    /// - Multiply by Jaccard overlap = nCommon / unionSize for further distinctness weighting.
    Map<String, double> _calculateSimilarity(
      String targetUserId,
      List<Review> targetReviews,
      List<Review> allReviews,
    ) {
      const int minCommon = 3; // ignore pairs with fewer overlaps
      const double shrinkK = 5; // shrinkage parameter

      // Group reviews by user
      final userGroups = <String, List<Review>>{};
      for (var r in allReviews) {
        userGroups.putIfAbsent(r.userId, () => []).add(r);
      }

      final targetGroup = userGroups[targetUserId] ?? [];
      if (targetGroup.isEmpty) return {};

      // Map of target ratings and mean
      final targetRatings = {for (var r in targetGroup) r.meal: r.rating.toDouble()};
      final targetMean = targetRatings.values.isEmpty
          ? 0
          : targetRatings.values.reduce((a, b) => a + b) / targetRatings.length;

      final scores = <String, double>{};

      for (final entry in userGroups.entries) {
        final otherUserId = entry.key;
        if (otherUserId == targetUserId) continue;
        final otherReviews = entry.value;
        final otherRatings = {for (var r in otherReviews) r.meal: r.rating.toDouble()};
        final otherMean = otherRatings.values.isEmpty
            ? 0
            : otherRatings.values.reduce((a, b) => a + b) / otherRatings.length;

        final commonMeals = targetRatings.keys.toSet().intersection(otherRatings.keys.toSet());
        final nCommon = commonMeals.length;
        if (nCommon < minCommon) continue;

        double num = 0; // numerator for Pearson
        double denomTarget = 0;
        double denomOther = 0;
        for (final meal in commonMeals) {
          final tDev = targetRatings[meal]! - targetMean;
          final oDev = otherRatings[meal]! - otherMean;
          num += tDev * oDev;
          denomTarget += tDev * tDev;
          denomOther += oDev * oDev;
        }

        if (denomTarget == 0 || denomOther == 0) continue; // all same ratings -> undefined correlation
        double pearson = num / (sqrt(denomTarget) * sqrt(denomOther));
        if (pearson.isNaN || pearson.isInfinite) continue;

        // Shrinkage factor: reduces impact of small nCommon
        final shrinkFactor = nCommon / (nCommon + shrinkK);

        // Jaccard overlap factor
        final unionSize = targetRatings.keys.toSet().union(otherRatings.keys.toSet()).length;
        final jaccard = unionSize == 0 ? 0 : nCommon / unionSize;

        double similarity = pearson * shrinkFactor * jaccard;
        if (!similarity.isNaN && !similarity.isInfinite) {
          scores[otherUserId] = similarity;
        }
      }

      return scores;
    }

  /// Helper to compute vector magnitude for cosine similarity

  Future<List<String>> getTopFoodsFromTwins(String userId) async {
    final rows = await getTwinComparisonTable(userId);
    return rows.where((r) => r.highlight).map((r) => r.foodName).toList();
  }

  /// Fetches up to 3 distinct meals that top twins rated highly
  /// and that are also present on today's menu.
  Future<List<Meal>> _getHighlyRatedMealsByUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    // Get high-rated reviews from top twins
    final snapshot = await _firestore
        .collection('reviews')
        .where('userId', whereIn: userIds.take(10).toList()) // Firestore limit
        .where('rating', isGreaterThan: 4)
        .get();

    // Collect distinct meal names from those reviews
    final mealNames = snapshot.docs
        .map((doc) => (doc['meal'] as String).trim().toLowerCase())
        .toSet();
    if (mealNames.isEmpty) return [];

    // Fetch today's meals
    final today = DateTime.now();
    final todayKey =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final mealSnapshot = await _firestore
        .collection('meals')
        .doc(todayKey)
        .collection('meals')
        .get();
    final todaysMeals = mealSnapshot.docs.map((doc) => Meal.fromFirestore(doc)).toList();

    // Match twin-recommended meals against today's menu
    final matchedMeals = todaysMeals
        .where((m) => mealNames.contains(m.name.trim().toLowerCase()))
        .toList();

    // Deduplicate by meal name and limit to 3
    final uniqueMeals = {for (var m in matchedMeals) m.name: m}.values.toList();
    return uniqueMeals.take(3).toList();
  }

  Future<List<TwinComparisonRow>> getTwinComparisonTable(String userId) async {
    final userReviews = await _getUserReviews(userId);
    final allReviews = await _getAllReviews();

    // similarity scores
    final similarityScores = _calculateSimilarity(userId, userReviews, allReviews);

    // top 3 twins
    final topTwins = similarityScores.entries
        .where((e) => e.key != userId)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final twinIds = topTwins.take(3).map((e) => e.key).toList();

    // group reviews by user
    final userGroups = <String, List<Review>>{};
    for (var r in allReviews) {
      userGroups.putIfAbsent(r.userId, () => []).add(r);
    }

    // fetch today's meals
    final today = DateTime.now();
    final todayKey =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final mealSnapshot = await _firestore
        .collection('meals')
        .doc(todayKey)
        .collection('meals')
        .get();
    final todaysMeals = mealSnapshot.docs.map((doc) => Meal.fromFirestore(doc)).toList();
    final todaysMealNames = todaysMeals.map((m) => m.name.trim().toLowerCase()).toSet();

    final rows = <TwinComparisonRow>[];
    // --- First up to 3 highlighted recommendation rows: distinct meals twins rated highly today that user has NOT rated ---
    final reviewedMealNamesLower = userReviews.map((r) => r.meal.trim().toLowerCase()).toSet();
    final addedHighlightMealsLower = <String>{};

    for (var twinId in twinIds) {
      if (addedHighlightMealsLower.length >= 3) break; // limit to 3
      final twinReviews = userGroups[twinId] ?? [];
      final todaysTwinReviews = twinReviews
          .where((r) => todaysMealNames.contains(r.meal.trim().toLowerCase()))
          .toList();
      if (todaysTwinReviews.isEmpty) continue;

      // Pick highest rated today's meal for this twin the user has NOT yet rated and not already added
      todaysTwinReviews.sort((a, b) => b.rating.compareTo(a.rating));
      Review? candidate;
      for (var rev in todaysTwinReviews) {
        final mealLower = rev.meal.trim().toLowerCase();
        if (reviewedMealNamesLower.contains(mealLower)) continue; // skip meals user already rated
        if (addedHighlightMealsLower.contains(mealLower)) continue; // enforce distinct top meals
        candidate = rev;
        break;
      }
      if (candidate == null) continue; // no unseen distinct meal for this twin

      final mealLower = candidate.meal.trim().toLowerCase();
      addedHighlightMealsLower.add(mealLower);

      rows.add(TwinComparisonRow(
        foodName: candidate.meal,
        meDisplay: '(?)', // always unknown for highlighted recommendations
        twinRatings: {
          for (var id in twinIds)
            id: (userGroups[id]?.firstWhere(
                      (r) => r.meal == candidate!.meal,
                      orElse: () => Review(
                        id: '',
                        userId: id,
                        meal: candidate!.meal,
                        rating: 0,
                        reviewText: '',
                        timestamp: DateTime.now(),
                      ),
                    ).rating)
                .toString(),
        },
        highlight: true,
      ));
    }

    // --- Overlap rows: foods both me and twins rated similarly ---
    final targetMap = {for (var r in userReviews) r.meal: r.rating};
    for (var twinId in twinIds) {
      final twinMap = {for (var r in userGroups[twinId] ?? []) r.meal: r.rating};
      final commonMeals = targetMap.keys.toSet().intersection(twinMap.keys.toSet());

      for (var meal in commonMeals) {
        final meRating = targetMap[meal]!;
        final twinRating = twinMap[meal]!;
        if ((meRating - twinRating).abs() <= 0.5) {
          // Skip if meal already used in highlighted recommendations
          if (addedHighlightMealsLower.contains(meal.trim().toLowerCase())) continue;
          rows.add(TwinComparisonRow(
            foodName: meal,
            meDisplay: meRating.toString(),
            twinRatings: {
              for (var id in twinIds)
                id: (userGroups[id]?.firstWhere(
                          (r) => r.meal == meal,
                          orElse: () => Review(
                            id: '',
                            userId: id,
                            meal: meal,
                            rating: 0,
                            reviewText: '',
                            timestamp: DateTime.now(),
                          ),
                        ).rating)
                    .toString(),
            },
          ));
        }
      }
    }

    // --- Append similarity score summary row (always) ---
    rows.add(TwinComparisonRow(
      foodName: twinIds.isEmpty ? 'Twin Similarity Scores (None found)' : 'Twin Similarity Scores',
      meDisplay: '',
      twinRatings: {
        for (var id in twinIds)
          id: similarityScores[id] != null
              ? similarityScores[id]!.toStringAsFixed(3)
              : '-',
      },
      highlight: false,
    ));

    return rows;
  }
}