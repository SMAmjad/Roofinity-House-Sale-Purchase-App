import 'package:flutter/material.dart';
import 'seller_home.dart';
import 'seller_upload_ad.dart';
import 'seller_chats.dart';
import 'seller_profile.dart';
import '../chat/ai_chat_screen.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  int _selectedIndex = 0;

  final _pages = const [
    SellerHome(),
    SellerUploadAd(),
    SellerChats(),
    SellerProfile(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AiChatScreen()),
          );
        },
        backgroundColor: const Color(0xFF005D8C),
        child: const Icon(Icons.support_agent, color: Colors.white),
        tooltip: 'Chat with AI Assistant',
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF005D8C),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_work), label: 'My Ads'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Upload Ad'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
