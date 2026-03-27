import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'Home/dashboard.dart';
import 'Login/login_screen.dart';
// ─── Route Names ─────────────────────────────────────────────────────────────

abstract class AppRoutes {
  static const login = '/login';
  static const dashboard = '/dashboard';

// Add more routes here as you build screens, e.g.:
// static const dashboard = '/dashboard';
// static const home      = '/home';
}

// ─── Route Pages ─────────────────────────────────────────────────────────────

abstract class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardScreen(),
    ),
    // Add more GetPage entries here, e.g.:
    // GetPage(
    //   name: AppRoutes.dashboard,
    //   page: () => const DashboardScreen(),
    // ),
  ];
}