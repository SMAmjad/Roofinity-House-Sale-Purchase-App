import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../buyer/gallery_screen.dart';
import '../utils/firestore_utils.dart';
import '../widgets/ai_verified_badge.dart';

/// Admin review queue: each ad's payment slip, images and AI check result.
/// Approving the payment makes the ad visible to buyers.
class VerifyPayments extends StatelessWidget {
  const VerifyPayments({super.key});

  static const _statuses = ['Pending', 'Approved', 'Rejected'];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _statuses.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Verify Ads & Payments"),
          automaticallyImplyLeading: false,
          bottom: TabBar(tabs: [for (final s in _statuses) Tab(text: s)]),
        ),
        body: TabBarView(
          children: [for (final s in _statuses) _AdQueue(status: s)],
        ),
      ),
    );
  }
}

class _AdQueue extends StatelessWidget {
  final String status;

  const _AdQueue({required this.status});

  Future<void> _setStatus(BuildContext context, String adId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('ads').doc(adId).update({
        'paymentStatus': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ad marked as $newStatus.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the ad. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .where('paymentStatus', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load ads.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final ads = sortNewestFirst(snapshot.data!.docs, 'createdAt');

        if (ads.isEmpty) {
          return Center(child: Text("No ${status.toLowerCase()} ads."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: ads.length,
          itemBuilder: (context, index) {
            final ad = ads[index].data() as Map<String, dynamic>;
            return _AdReviewCard(
              ad: ad,
              onApprove: status == 'Approved'
                  ? null
                  : () => _setStatus(context, ads[index].id, 'Approved'),
              onReject: status == 'Rejected'
                  ? null
                  : () => _setStatus(context, ads[index].id, 'Rejected'),
            );
          },
        );
      },
    );
  }
}

class _AdReviewCard extends StatelessWidget {
  final Map<String, dynamic> ad;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _AdReviewCard({required this.ad, this.onApprove, this.onReject});

  void _openGallery(BuildContext context, List<dynamic> urls, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryScreen(imageUrls: urls, initialIndex: index),
      ),
    );
  }

  Widget _aiSummary() {
    final aiCheck = ad['aiCheck'] as Map<String, dynamic>?;
    if (aiCheck == null) {
      return const Text(
        'AI check: not available (ad posted before AI check was added)',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      );
    }
    final score = (aiCheck['maxFakeScore'] as num?)?.toDouble() ?? 0;
    return Row(
      children: [
        if (AiVerifiedBadge.isVerified(ad)) const AiVerifiedBadge(compact: true),
        const SizedBox(width: 8),
        Text(
          'Highest fake score: ${(score * 100).toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = ad['imageUrls'] as List? ?? [];
    final slipUrl = ad['paymentSlipUrl'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ad['title'] ?? 'Untitled',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              'By ${ad['sellerName'] ?? 'Agent'}  •  ${ad['price'] ?? 'N/A'} PKR',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            _aiSummary(),
            const SizedBox(height: 10),
            if (imageUrls.isNotEmpty) ...[
              const Text('Property images', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _openGallery(context, imageUrls, i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        imageUrls[i].toString(),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const Text('Payment slip', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (slipUrl != null)
              GestureDetector(
                onTap: () => _openGallery(context, [slipUrl], 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    slipUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80,
                      color: Colors.grey[300],
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              )
            else
              const Text('No slip uploaded.', style: TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReject != null)
                  OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                const SizedBox(width: 10),
                if (onApprove != null)
                  ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
