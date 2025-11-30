import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh_recommendation/widgets/individual_suggestion_card.dart';
import 'package:async/async.dart';

import '../widgets/individual_review_card.dart';
import 'settings_screen.dart'; // NEW

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _showEditAvgDurationDialog(BuildContext context, int currentValue, String? uid) {
    if (uid == null) return;
    final TextEditingController controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Avg Duration (minutes)'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter minutes (e.g. 45)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return; // no change
                final int? value = int.tryParse(text);
                if (value == null || value < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a non-negative integer.')),
                  );
                  return;
                }
                try {
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                    'average_duration_at_pdh': value,
                  });
                  Navigator.of(ctx).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // --- Settings button (opens without nav bar) --- NEW
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text('Settings'),
                        ),
                      ],
                    ),
                    // --- Profile Info from Firestore ---
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        final data = snapshot.data!.data() as Map<String, dynamic>?;

                        final userName = data?['name'] ?? 'Unnamed User';
                        final userEmail = user?.email ?? '';
                        final dynamic avgRaw = data?['average_duration_at_pdh'];
                        int? avgDurationMinutesRaw;
                        if (avgRaw is int) {
                          avgDurationMinutesRaw = avgRaw;
                        } else if (avgRaw is num) {
                          avgDurationMinutesRaw = avgRaw.round();
                        } else {
                          avgDurationMinutesRaw = null;
                        }
                        final int avgDurationMinutes = (avgDurationMinutesRaw == null || avgDurationMinutesRaw < 0)
                            ? 0
                            : avgDurationMinutesRaw;
                        final averageDurationSeconds = (data?['average_duration_at_pdh'] as num?)?.toDouble() ?? 0.0;

                        return Column(
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userEmail,
                              style: const TextStyle(
                                fontSize: 18,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer_outlined, size: 20, color: Colors.black54),
                                const SizedBox(width: 6),
                                Text(
                                  "Avg Duration at PDH: $avgDurationMinutes min",
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Edit average duration',
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () {
                                    _showEditAvgDurationDialog(context, avgDurationMinutes, user?.uid);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Average Stay Duration Card
                            Card(
                              color: Colors.grey[50], // Light grey background
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Average Stay at PDH',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDurationInMinutes(averageDurationSeconds),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        _showEditDurationDialog(
                                          context, 
                                          user!.uid, 
                                          averageDurationSeconds
                                        );
                                      },
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: Colors.grey[600],
                                      ),
                                      tooltip: 'Edit average stay duration',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Favorite Dishes",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // User favorites first, then nested reviews for highest rated dishes.
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user?.uid)
                          .snapshots(),
                      builder: (context, userSnap) {
                        if (userSnap.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (!userSnap.hasData || !userSnap.data!.exists) {
                          return const Text('User data unavailable.');
                        }
                        final userData = userSnap.data!.data();
                        final favorites = (userData?['favorites'] as List<dynamic>? ?? [])
                            .map((e) => e.toString())
                            .toList();

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('reviews')
                              .where('userId', isEqualTo: user?.uid)
                              .snapshots(),
                          builder: (context, reviewSnap) {
                            if (reviewSnap.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }
                            final docs = reviewSnap.data?.docs ?? [];
                            final Map<String, double> mealToMaxRating = {};
                            for (final doc in docs) {
                              final data = doc.data();
                              final mealName = data['meal']?.toString();
                              final ratingRaw = data['rating'];
                              double rating = 0;
                              if (ratingRaw is int) rating = ratingRaw.toDouble();
                              if (ratingRaw is double) rating = ratingRaw;
                              if (mealName == null || mealName.isEmpty) continue;
                              final current = mealToMaxRating[mealName];
                              if (current == null || rating > current) {
                                mealToMaxRating[mealName] = rating;
                              }
                            }
                            final topRatedEntries = mealToMaxRating.entries
                                .where((e) => !favorites.contains(e.key))
                                .toList()
                              ..sort((a, b) => b.value.compareTo(a.value));
                            final topRatedLimited = topRatedEntries.take(5).toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Manually Favorited',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                if (favorites.isEmpty)
                                  const Text("You haven't marked any favorites yet.")
                                else
                                  Column(
                                    children: favorites.map((meal) {
                                      return ListTile(
                                        dense: true,
                                        title: Text(meal),
                                        leading: const Icon(Icons.favorite, color: Colors.pink),
                                      );
                                    }).toList(),
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  'Highest Rated (Your Reviews)',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                if (topRatedLimited.isEmpty)
                                  const Text('No rated dishes yet.')
                                else
                                  Column(
                                    children: topRatedLimited.map((entry) {
                                      return ListTile(
                                        dense: true,
                                        title: Text(entry.key),
                                        leading: const Icon(Icons.star, color: Colors.amber),
                                        trailing: Text(entry.value.toStringAsFixed(1)),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    
                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Recent Activity",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),

                    StreamBuilder<List<QuerySnapshot>>(
                      stream: StreamZip([
                        FirebaseFirestore.instance
                            .collection('reviews')
                            .where('userId', isEqualTo: user?.uid)
                            .snapshots(),
                        FirebaseFirestore.instance
                            .collection('suggestions')
                            .where('userId', isEqualTo: user?.uid)
                            .snapshots(),
                      ]),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: Text("No recent activity."));
                        }
                        
                        DateTime safeTimestamp(DocumentSnapshot doc) {
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data == null) return DateTime.fromMillisecondsSinceEpoch(0);
                          final raw = data['timestamp'];
                          if (raw is Timestamp) return raw.toDate();
                          if (raw is DateTime) return raw;
                          return DateTime.fromMillisecondsSinceEpoch(0);
                        }

                        final reviews = snapshot.data![0].docs.map((doc) => {
                              'type': 'review',
                              'doc': doc,
                              'timestamp': safeTimestamp(doc),
                            });

                        final suggestions = snapshot.data![1].docs.map((doc) => {
                              'type': 'suggestion',
                              'doc': doc,
                              'timestamp': safeTimestamp(doc),
                            });

                        final allActivities = [...reviews, ...suggestions];
                        allActivities.sort((a, b) =>
                            (b['timestamp'] as DateTime).compareTo(
                                a['timestamp'] as DateTime));

                        final recent = allActivities.take(5).toList();

                        if (recent.isEmpty) {
                          return const Text("No recent activity.");
                        }

                        return Column(
                          children: recent.map((activity) {
                            final doc = activity['doc']
                                as DocumentSnapshot<Map<String, dynamic>>;
                            if (activity['type'] == 'review') {
                              return IndividualReviewCard(doc: doc);
                            } else {
                              return IndividualSuggestionCard(doc: doc);
                            }
                          }).toList(),
                        );
                      },
                    ),     
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper function to format duration in seconds to display in minutes
  String _formatDurationInMinutes(double seconds) {
    final minutes = seconds / 60;
    if (minutes < 1) {
      return '${seconds.toStringAsFixed(0)} seconds';
    } else if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)} minutes';
    } else {
      final hours = minutes / 60;
      if (hours == hours.truncateToDouble()) {
        return '${hours.toInt()} hours';
      } else {
        return '${hours.toStringAsFixed(1)} hours';
      }
    }
  }

  // Convert seconds to minutes for display in edit dialog
  double _secondsToMinutes(double seconds) {
    return seconds / 60;
  }

  // Convert minutes back to seconds for database storage
  double _minutesToSeconds(double minutes) {
    return minutes * 60;
  }

  // Function to show edit duration dialog
  void _showEditDurationDialog(BuildContext context, String userId, double currentDurationSeconds) {
    final currentMinutes = _secondsToMinutes(currentDurationSeconds);
    final TextEditingController controller = TextEditingController(
      text: currentMinutes.toStringAsFixed(0)
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Average Stay',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter your average stay duration in minutes:',
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Minutes',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Examples: 15, 30, 45, 60',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final newMinutes = double.tryParse(controller.text);
                        if (newMinutes != null && newMinutes >= 0) {
                          try {
                            // Convert minutes to seconds for database storage
                            final newDurationSeconds = _minutesToSeconds(newMinutes);
                            
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .update({
                              'average_duration_at_pdh': newDurationSeconds,
                            });
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Average stay duration updated!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating duration: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please enter a valid number of minutes'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}