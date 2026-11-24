import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_utils.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {

  // Function to show a confirmation dialog and remove an ad
  Future<void> _removeAd(String adId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to remove this ad permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('ads').doc(adId).delete();
    }
  }

  // Helper function to format the duration
  String _formatDuration(DateTime date) {
    final duration = DateTime.now().difference(date);
    if (duration.inDays > 0) {
      return '${duration.inDays} day(s) ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour(s) ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute(s) ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Ads Management')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ads')
            .where('paymentStatus', isEqualTo: 'Approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load ads.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No approved ads found.'));
          }

          final ads = sortNewestFirst(snapshot.data!.docs, 'createdAt');

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];
              final adData = ad.data() as Map<String, dynamic>;
              final createdAt = (adData['createdAt'] as Timestamp?)?.toDate();
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: ListTile(
                  title: Text(adData['title'] ?? 'No Title'),
                  subtitle: Text('Posted: ${createdAt != null ? _formatDuration(createdAt) : 'Unknown'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeAd(ad.id),
                    tooltip: 'Remove Ad',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
