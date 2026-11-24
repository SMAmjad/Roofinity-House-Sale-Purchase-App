import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/chat_screen.dart';
import '../utils/firestore_utils.dart';

class SellerChats extends StatelessWidget {
  const SellerChats({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view chats.")),
      );
    }

    final sellerId = currentUser.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          "Buyer Chats",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ CORRECT QUERY: Find chats where the seller is a participant
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: sellerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Could not load chats."));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No buyer chats yet.",
                style: TextStyle(fontFamily: 'Poppins', color: Colors.black54),
              ),
            );
          }

          final chats = sortNewestFirst(snapshot.data!.docs, 'lastMessageTime');

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chatData = chats[index].data() as Map<String, dynamic>;
              
              // Find the other user's ID from the participants list
              final participants = List<String>.from(chatData['participants'] ?? []);
              final buyerId = participants.firstWhere((id) => id != sellerId, orElse: () => '');

              if (buyerId.isEmpty) return const SizedBox.shrink(); // Skip if buyer not found

              final buyerName = chatData['buyerName'] ?? "Buyer";
              final lastMessage = chatData['lastMessage'] ?? '';
              final timestamp = chatData['lastMessageTime'] as Timestamp?;

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF005D8C),
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                title: Text(
                  buyerName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                trailing: timestamp != null
                    ? Text(
                        TimeOfDay.fromDateTime(timestamp.toDate()).format(context),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      )
                    : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      currentUserId: sellerId,
                      otherUserId: buyerId,
                      otherUserName: buyerName,
                    ),
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
