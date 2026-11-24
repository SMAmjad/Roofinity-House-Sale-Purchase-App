import 'package:flutter/material.dart';
import 'buyer_home.dart';
import 'buyer_chats.dart';
import 'buyer_profile.dart';
import 'favorites_screen.dart';
import '../chat/ai_chat_screen.dart';

class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({super.key});

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  int _selectedIndex = 0;

  // ✅ ADDED FavoritesScreen
  final _pages = const [
    BuyerHome(),
    FavoritesScreen(),
    BuyerChats(),
    BuyerProfile(),
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
            MaterialPageRoute(builder: (context) => const AiChatScreen()),
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
        // ✅ ADDED Favorites tab
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_work), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
