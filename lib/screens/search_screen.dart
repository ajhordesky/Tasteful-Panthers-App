import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/individual_review_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Filters
  String searchQuery = '';
  List<String> selectedTags = [];
  String? selectedUserId;
  double minRating = 0.0;
  double maxRating = 5.0;
  bool _filtersExpanded = false;

  // Populated dynamically
  List<String> availableTags = [];
  List<Map<String, dynamic>> availableUsers = [];
  Map<String, String> userIdToName = {};

  // Firestore reference
  final CollectionReference reviewsRef =
      FirebaseFirestore.instance.collection('reviews');

  final CollectionReference usersRef =
      FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  // Load all unique users and tags
  Future<void> _loadFilterOptions() async {
    final snapshot = await reviewsRef.get();
    final userSnapshots = await usersRef.get();
    final tagsSet = <String>{};
    final usersList = <Map<String, dynamic>>[];

    // Build userId to username mapping
    for (var userDoc in userSnapshots.docs) {
      final userData = userDoc.data() as Map<String, dynamic>;
      userIdToName[userDoc.id] = userData['username'] ?? userData['name'] ?? 'Unknown User';
    }

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['tags'] != null) {
        tagsSet.addAll(List<String>.from(data['tags']));
      }
    }

    // Create list of users with id and username
    for (var userDoc in userSnapshots.docs) {
      final userData = userDoc.data() as Map<String, dynamic>;
      usersList.add({
        'id': userDoc.id,
        'username': userData['username'] ?? userData['name'] ?? 'Unknown User',
      });
    }

    setState(() {
      availableTags = tagsSet.toList()..sort();
      availableUsers = usersList..sort((a, b) => a['username'].compareTo(b['username']));
    });
  }

  // Stream with Firestore filtering
  Stream<QuerySnapshot> getFilteredStream() {
    Query query = reviewsRef;

    // Filter by userId if selected
    if (selectedUserId != null) {
      query = query.where('userId', isEqualTo: selectedUserId);
    }

    // Filter by rating range (Firestore supports numeric filters)
    query = query
        .where('rating', isGreaterThanOrEqualTo: minRating)
        .where('rating', isLessThanOrEqualTo: maxRating);

    return query.snapshots();
  }

  // Clear all filters
  void clearFilters() {
    setState(() {
      selectedTags.clear();
      selectedUserId = null;
      minRating = 0.0;
      maxRating = 5.0;
      searchQuery = '';
    });
  }

  // Clear only tags
  void clearTags() {
    setState(() {
      selectedTags.clear();
    });
  }

  // Check if any filters are active
  bool get _hasActiveFilters {
    return selectedTags.isNotEmpty || 
           selectedUserId != null || 
           minRating > 0.0 || 
           maxRating < 5.0 ||
           searchQuery.isNotEmpty;
  }

  // Local filter check (runs after Firestore fetch)
  bool _matchesFilters(Map<String, dynamic> review) {
    final title = review['title']?.toString().toLowerCase() ?? '';
    final meal = review['meal']?.toString().toLowerCase() ?? '';
    final description = review['description']?.toString().toLowerCase() ?? '';
    final reviewText = review['reviewText']?.toString().toLowerCase() ?? '';
    final tags = List<String>.from(review['tags'] ?? []);
    final rating = (review['rating'] ?? 0.0).toDouble();

    final matchesSearch = searchQuery.isEmpty || 
        title.contains(searchQuery.toLowerCase()) ||
        meal.contains(searchQuery.toLowerCase()) ||
        description.contains(searchQuery.toLowerCase()) ||
        reviewText.contains(searchQuery.toLowerCase());
    final matchesTags = selectedTags.isEmpty ||
        selectedTags.every((t) => tags.contains(t));
    final matchesRating =
        rating >= minRating && rating <= maxRating;

    return matchesSearch && matchesTags && matchesRating;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.white, // Changed to white background
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // 🔍 Search bar - ALWAYS VISIBLE
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  hintText: 'Search reviews...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                onChanged: (value) => setState(() => searchQuery = value),
              ),
            ),

            // 🎛️ COLLAPSIBLE FILTERS SECTION
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              child: ExpansionTile(
                title: Row(
                  children: [
                    const Icon(Icons.filter_list, color: Colors.black87),
                    const SizedBox(width: 12),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (_hasActiveFilters)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Active',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                initiallyExpanded: _filtersExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _filtersExpanded = expanded;
                  });
                },
                children: [
                  // 🏷️ Tag filters
                  _buildTagFilterSection(colorScheme),
                  
                  // 👤 User filter
                  _buildUserFilterSection(colorScheme),
                  
                  // ⭐ Rating filter
                  _buildRatingFilterSection(colorScheme),
                  
                  // Clear all filters button
                  _buildClearFiltersButton(colorScheme),
                  
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // 🧾 Results list
            Expanded(
              child: Container(
                color: Colors.white, // White background for results
                child: StreamBuilder<QuerySnapshot>(
                  stream: getFilteredStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No reviews found.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    // Apply client-side tag and search filtering
                    final filteredDocs = snapshot.data!.docs.where((doc) {
                      final review = doc.data() as Map<String, dynamic>;
                      return _matchesFilters(review);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No matching reviews.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: filteredDocs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12.0),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        return IndividualReviewCard(doc: doc);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagFilterSection(ColorScheme colorScheme) {
    return ExpansionTile(
      title: Row(
        children: [
          const Icon(Icons.local_offer, color: Colors.black87, size: 20),
          const SizedBox(width: 12),
          const Text(
            'Filter by Tags',
            style: TextStyle(color: Colors.black87),
          ),
          const Spacer(),
          if (selectedTags.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18, color: Colors.black87),
              onPressed: clearTags,
              tooltip: 'Clear selected tags',
            ),
        ],
      ),
      children: [
        Container(
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: availableTags.map((tag) {
                final isSelected = selectedTags.contains(tag);
                return CheckboxListTile(
                  title: Text(
                    tag,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  value: isSelected,
                  activeColor: colorScheme.primary,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        selectedTags.add(tag);
                      } else {
                        selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildUserFilterSection(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Colors.black87, size: 20),
              const SizedBox(width: 12),
              const Text(
                'Filter by User',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedUserId,
                  decoration: InputDecoration(
                    hintText: 'Select user...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black87),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'All Users',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                    ...availableUsers.map((user) => DropdownMenuItem<String>(
                          value: user['id'],
                          child: Text(
                            user['username'],
                            style: const TextStyle(color: Colors.black87),
                          ),
                        )),
                  ],
                  onChanged: (value) => setState(() => selectedUserId = value),
                ),
              ),
              const SizedBox(width: 8),
              if (selectedUserId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      selectedUserId = null;
                    });
                  },
                  tooltip: 'Clear user filter',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingFilterSection(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.black87, size: 20),
              const SizedBox(width: 12),
              const Text(
                'Filter by Rating',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (minRating > 0.0 || maxRating < 5.0)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      minRating = 0.0;
                      maxRating = 5.0;
                    });
                  },
                  tooltip: 'Reset rating filter',
                ),
            ],
          ),
          const SizedBox(height: 16),
          RangeSlider(
            values: RangeValues(minRating, maxRating),
            min: 0.0,
            max: 5.0,
            divisions: 10,
            activeColor: colorScheme.primary,
            inactiveColor: Colors.grey[300],
            labels: RangeLabels(
              '${minRating.toStringAsFixed(1)}★',
              '${maxRating.toStringAsFixed(1)}★',
            ),
            onChanged: (RangeValues values) {
              setState(() {
                minRating = values.start;
                maxRating = values.end;
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${minRating.toStringAsFixed(1)}★',
                style: const TextStyle(color: Colors.black54),
              ),
              Text(
                '${maxRating.toStringAsFixed(1)}★',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClearFiltersButton(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ElevatedButton.icon(
          icon: Icon(Icons.clear_all, color: colorScheme.onPrimary),
          label: Text(
            'Clear All Filters',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          onPressed: clearFilters,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 2,
          ),
        ),
      ),
    );
  }
}