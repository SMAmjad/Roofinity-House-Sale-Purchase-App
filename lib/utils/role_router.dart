import 'package:flutter/material.dart';

import '../admin/admin_dashboard.dart';
import '../buyer/buyer_dashboard.dart';
import '../seller/seller_dashboard.dart';

/// Home screen for a user role, or null if the role is unknown.
Widget? homeForRole(String? role) {
  switch (role) {
    case 'Admin':
      return const AdminDashboard();
    case 'Seller':
      return const SellerDashboard();
    case 'Buyer':
      return const BuyerDashboard();
  }
  return null;
}

/// Replaces the whole navigation stack with [screen].
void goToRoot(BuildContext context, Widget screen) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => screen),
    (_) => false,
  );
}
