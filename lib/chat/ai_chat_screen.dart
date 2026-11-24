import 'package:flutter/material.dart';
import '../services/chatbot_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _messageController = TextEditingController();
  final _chatbotService = ChatbotService();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatbotData();
  }

  Future<void> _loadChatbotData() async {
    await _chatbotService.loadData();
    setState(() {
      _isLoading = false;
      _messages.add({
        'sender': 'bot',
        'text': 'Welcome to the Roofinity AI Assistant! How can I help you with your real estate questions today?'
      });
    });
  }

  void _sendMessage() {
    final query = _messageController.text;
    if (query.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': query});
    });

    final response = _chatbotService.getResponse(query);
    setState(() {
      _messages.add({'sender': 'bot', 'text': response});
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['sender'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        // ✅ WRAPPED bubble in a ConstrainedBox to fix overflow
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUser ? Colors.blue[100] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(message['text']!),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Ask a question...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
