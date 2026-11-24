import 'package:flutter/material.dart';

/// Small chip shown on ads whose images passed the on-device AI check.
class AiVerifiedBadge extends StatelessWidget {
  final bool compact;

  const AiVerifiedBadge({super.key, this.compact = false});

  /// True when the ad document says its images passed the AI check.
  static bool isVerified(Map<String, dynamic> ad) => ad['aiVerified'] == true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF34A853)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: compact ? 14 : 16, color: const Color(0xFF1E8E3E)),
          const SizedBox(width: 4),
          Text(
            'AI Verified Images',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E8E3E),
            ),
          ),
        ],
      ),
    );
  }
}
