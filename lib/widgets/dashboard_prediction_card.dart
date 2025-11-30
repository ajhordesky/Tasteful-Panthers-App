import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardPredictionsCard extends StatefulWidget {
  const DashboardPredictionsCard({super.key});

  @override
  State<DashboardPredictionsCard> createState() => _DashboardPredictionsCardState();
}

class _DashboardPredictionsCardState extends State<DashboardPredictionsCard> {
  late Future<_PredictionsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_PredictionsData> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final usersCol = FirebaseFirestore.instance.collection('users');

    // Read current user's points (default 0)
    int myPoints = 0;
    String myName = 'You';
    if (uid != null) {
      try {
        final meSnap = await usersCol.doc(uid).get();
        final me = meSnap.data() ?? {};
        final rawPts = me['predictionPoints'];
        myPoints = rawPts is int ? rawPts : (rawPts is num ? rawPts.toInt() : 0);
        myName = (me['username'] ?? me['name'] ?? 'You').toString();
      } catch (_) {
        // ignore, keep defaults
      }
    }

    // Compute rank and totals using count() if available; fall back gracefully
    int totalUsers = 0;
    int betterCount = 0;
    try {
      final totalAgg = await usersCol.count().get();
      totalUsers = (totalAgg.count ?? 0);
    } catch (_) {
      try {
        final all = await usersCol.limit(1000).get();
        totalUsers = all.docs.length;
      } catch (_) {
        totalUsers = 0;
      }
    }

    if (uid != null) {
      try {
        final betterAgg = await usersCol.where('predictionPoints', isGreaterThan: myPoints).count().get();
        betterCount = (betterAgg.count ?? 0);
      } catch (_) {
        try {
          final better = await usersCol
              .where('predictionPoints', isGreaterThan: myPoints)
              .limit(1000)
              .get();
          betterCount = better.docs.length;
        } catch (_) {
          betterCount = 0;
        }
      }
    }

    final rank = (uid == null) ? 0 : (betterCount + 1);
    final placement = (totalUsers == 0)
      ? 'No predictors yet'
      : (uid == null ? 'Sign in to see your rank' : "You're $rank out of $totalUsers");

    // Compute accuracy across all dates via collection group on 'users'
    String accuracyText = '—';
    if (uid == null) {
      accuracyText = 'Sign in to track accuracy';
    } else {
      try {
        // Prefer querying by a stored 'uid' field to avoid documentId() issues on collectionGroup.
        final cg = FirebaseFirestore.instance.collectionGroup('users');
        final totalAgg = await cg.where('uid', isEqualTo: uid).count().get();
        final int totalPreds = (totalAgg.count ?? 0);
        if (totalPreds > 0) {
          final correctAgg = await cg
              .where('uid', isEqualTo: uid)
              .where('correct', isEqualTo: true)
              .count()
              .get();
          final int correct = (correctAgg.count ?? 0);
          final pct = ((correct / totalPreds) * 100).round();
          accuracyText = '$pct% accuracy ($correct/$totalPreds)';
        } else {
          accuracyText = 'No predictions yet';
        }
      } catch (_) {
        // Fallback when collectionGroup or indices are not available
        accuracyText = '$myPoints pts';
      }
    }

    // Leaderboard: top 10 by predictionPoints desc
    final rows = <Widget>[];
    try {
      final topSnap = await usersCol.orderBy('predictionPoints', descending: true).limit(10).get();
      final topDocs = topSnap.docs;
      for (int i = 0; i < topDocs.length; i++) {
        final d = topDocs[i];
        final data = d.data();
        final uname = (data['username'] ?? data['name'] ?? d.id).toString();
        final ptsRaw = data['predictionPoints'];
        final pts = ptsRaw is int ? ptsRaw : (ptsRaw is num ? ptsRaw.toInt() : 0);
        final isMe = d.id == uid;
        rows.add(_leaderboardRow(i + 1, uname, pts, isMe));
      }

      // If current user not in top 10, append their row
      if (uid != null && topDocs.indexWhere((d) => d.id == uid) == -1 && myPoints >= 0 && rank > 0) {
        rows.add(const Divider());
        rows.add(_leaderboardRow(rank, myName, myPoints, true));
      }
    } catch (_) {
      // ignore; show empty leaderboard
    }

    return _PredictionsData(
      placement: placement,
      accuracy: accuracyText,
      rows: rows,
    );
  }

  static Widget _leaderboardRow(int rank, String name, int points, bool isMe) {
    final style = TextStyle(
      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
      color: isMe ? Colors.blueAccent : Colors.black87,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('#$rank', style: style),
          Expanded(child: Text(name, textAlign: TextAlign.center, style: style)),
          Text('$points pts', style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PredictionsData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCard('Loading…', '—', const []);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildCard('Predictions unavailable', '—', const []);
        }
        final data = snapshot.data!;
        return InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Top Guessers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      if (data.rows.isEmpty)
                        const Text('No predictors yet. Be the first!')
                      else
                        ...data.rows,
                    ],
                  ),
                ),
              ),
            );
          },
          child: _buildCard(data.placement, data.accuracy, data.rows),
        );
      },
    );
  }

  Widget _buildCard(String placement, String accuracy, List<Widget> rows) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Predictions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.0,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            placement,
            style: const TextStyle(
              fontSize: 13.0,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            accuracy,
            style: const TextStyle(
              fontSize: 13.0,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionsData {
  final String placement;
  final String accuracy;
  final List<Widget> rows;
  _PredictionsData({required this.placement, required this.accuracy, required this.rows});
}