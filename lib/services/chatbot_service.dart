import 'dart:convert';
import 'package:flutter/services.dart';

class ChatbotService {
  List<Map<String, String>> _qaData = [];

  // Load the Q&A data from the JSON file
  Future<void> loadData() async {
    final String response = await rootBundle.loadString('assets/data/chatbot_data.json');
    final List<dynamic> data = json.decode(response);
    _qaData = data.map((item) => {
      'question': item['question'] as String,
      'answer': item['answer'] as String,
    }).toList();
  }

  // Find the best answer based on keyword matching
  String getResponse(String query) {
    if (_qaData.isEmpty) {
      return "I'm still learning. Please try again in a moment.";
    }

    final queryWords = query.toLowerCase().split(' ');
    Map<String, int> matchScores = {};

    for (var qa in _qaData) {
      int score = 0;
      final questionWords = qa['question']!.toLowerCase().split(' ');
      for (var qWord in queryWords) {
        if (questionWords.contains(qWord)) {
          score++;
        }
      }
      if (score > 0) {
        matchScores[qa['answer']!] = score;
      }
    }

    if (matchScores.isEmpty) {
      return "Sorry, I don't have an answer for that. Please ask another question about real estate.";
    }

    // Return the answer with the highest score
    final bestMatch = matchScores.entries.reduce((a, b) => a.value > b.value ? a : b);
    return bestMatch.key;
  }
}
