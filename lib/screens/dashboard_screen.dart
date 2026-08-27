import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'admin_dashboard_screen.dart';
import 'drivers/drivers_list_screen.dart';
import 'trips/live_trips_screen.dart';
import 'trips/trips_history_screen.dart';
import 'finance/wallets_screen.dart';
import 'finance/recharge_cards_screen.dart';
import 'support/notifications_screen.dart';
import 'support/complaints_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const DriversListScreen(),
    const LiveTripsScreen(),
    const TripsHistoryScreen(),
    const WalletsScreen(),
    const RechargeCardsScreen(),
    const NotificationsScreen(),
    const ComplaintsScreen(),
  ];

  final List<String> _titles = [
    'نظرة عامة (Overview)',
    'إدارة وتفعيل الكباتن',
    'الرحلات الجارية',
    'سجل الرحلات',
    'محافظ الكباتن',
    'سجل كروت الشحن',
    'إرسال إشعارات',
    'البلاغات والشكاوى',
  ];

  final List<IconData> _icons = [
    Icons.dashboard_rounded,
    Icons.people_alt_rounded,
    Icons.map_rounded,
    Icons.history_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.credit_card_rounded,
    Icons.notifications_active_rounded,
    Icons.report_problem_rounded,
  ];

  Widget _buildSidebarItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: Colors.white.withOpacity(0.3), width: 1) : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        hoverColor: Colors.white.withOpacity(0.05),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100, // Light background for content
        body: Row(
          children: [
            // Modern Sidebar
            Container(
              width: 260,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade900, Colors.blue.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(3, 0)),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  // App Logo & Brand
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'إدارة وياك',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white24, indent: 24, endIndent: 24),
                  const SizedBox(height: 16),
                  
                  // Menu Items
                  Expanded(
                    child: ListView.builder(
                      itemCount: _titles.length,
                      itemBuilder: (context, index) {
                        return _buildSidebarItem(index, _titles[index], _icons[index]);
                      },
                    ),
                  ),
                  
                  const Divider(color: Colors.white24, indent: 24, endIndent: 24),
                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.9),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('تسجيل الخروج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (mounted) context.go('/admin');
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            
            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Modern Top Bar (AppBar inside content)
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _titles[_selectedIndex],
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person, color: Colors.blue.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Admin', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Screen Content
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(24)),
                      child: _screens[_selectedIndex],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
