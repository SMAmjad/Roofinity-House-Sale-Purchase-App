import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/ai_verified_badge.dart';
import 'property_details_screen.dart';

class BuyerHome extends StatefulWidget {
  const BuyerHome({super.key});

  @override
  State<BuyerHome> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends State<BuyerHome> {
  String _searchQuery = '';
  double? _minPrice;
  double? _maxPrice;

  Future<void> _showFilterDialog() async {
    final minPriceController = TextEditingController(text: _minPrice?.toString() ?? '');
    final maxPriceController = TextEditingController(text: _maxPrice?.toString() ?? '');

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter by Price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: minPriceController,
                decoration: const InputDecoration(labelText: 'Min Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: maxPriceController,
                decoration: const InputDecoration(labelText: 'Max Price'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Clear'),
              onPressed: () {
                setState(() {
                  _minPrice = null;
                  _maxPrice = null;
                });
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Apply'),
              onPressed: () {
                setState(() {
                  _minPrice = double.tryParse(minPriceController.text);
                  _maxPrice = double.tryParse(maxPriceController.text);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: null,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Image.asset('assets/images/splash_logo.png', height: 100),
                    const SizedBox(height: 0.5),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "Search properties...",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.filter_list),
                          onPressed: _showFilterDialog,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ads')
                  .where('paymentStatus', isEqualTo: 'Approved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "No properties available at the moment.",
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                      ),
                    ),
                  );
                }

                var ads = snapshot.data!.docs.where((doc) {
                  final adData = doc.data() as Map<String, dynamic>;
                  final title = (adData['title'] as String? ?? '').toLowerCase();
                  final priceString = adData['price'] as String? ?? '0';
                  final price = double.tryParse(priceString) ?? 0.0;

                  final matchesSearch = title.contains(_searchQuery);
                  final matchesMinPrice = _minPrice == null || price >= _minPrice!;
                  final matchesMaxPrice = _maxPrice == null || price <= _maxPrice!;

                  return matchesSearch && matchesMinPrice && matchesMaxPrice;
                }).toList();

                if (ads.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "No properties match your search/filter.",
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ad = ads[index].data() as Map<String, dynamic>;
                        final adId = ads[index].id;
                        final imageUrls = ad['imageUrls'] as List?;

                        return GestureDetector(
                          onTap: () {
                            final adWithId = {...ad, 'id': adId};
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PropertyDetailsScreen(ad: adWithId),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: (imageUrls != null && imageUrls.isNotEmpty)
                                      ? Image.network(
                                          imageUrls.first,
                                          width: double.infinity,
                                          height: 180,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Container(
                                            height: 180,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image_not_supported, size: 60),
                                          ),
                                        )
                                      : Container(
                                          height: 180,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.home_work, size: 60, color: Color(0xFF005D8C)),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ad['title'] ?? 'No Title',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (AiVerifiedBadge.isVerified(ad)) ...[
                                        const SizedBox(height: 6),
                                        const AiVerifiedBadge(compact: true),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        ad['description'] ?? '',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Price: ${ad['price'] ?? 'N/A'} PKR",
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: ads.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
