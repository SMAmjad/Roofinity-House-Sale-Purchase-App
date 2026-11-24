import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/chat_screen.dart';
import '../utils/firestore_utils.dart';

class BuyerChats extends StatelessWidget {
  const BuyerChats({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text("Please log in to view chats."),
        ),
      );
    }

    final buyerId = currentUser.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          "My Chats",
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
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: buyerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Could not load chats."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = sortNewestFirst(snapshot.data!.docs, 'lastMessageTime');

          if (chats.isEmpty) {
            return const Center(
              child: Text(
                "No chats yet.",
                style: TextStyle(fontFamily: 'Poppins', color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              final sellerId = chat['sellerId'] ?? '';
              final sellerName = chat['sellerName'] ?? 'Seller';
              final lastMessage = chat['lastMessage'] ?? '';
              final timestamp = chat['lastMessageTime'] != null
                  ? (chat['lastMessageTime'] as Timestamp).toDate()
                  : null;

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF005D8C),
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                title: Text(
                  sellerName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  lastMessage.isEmpty ? "No messages yet" : lastMessage,
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
                  "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                )
                    : null,
                onTap: () {
                  if (sellerId.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        currentUserId: buyerId,
                        otherUserId: sellerId,
                        otherUserName: sellerName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
