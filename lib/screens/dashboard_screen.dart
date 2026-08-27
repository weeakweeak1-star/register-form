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
    'الطلبات المعلقة',
    'إدارة وتفعيل الكباتن',
    'الرحلات الجارية',
    'سجل الرحلات',
    'محافظ الكباتن',
    'سجل كروت الشحن',
    'إرسال إشعارات',
    'البلاغات والشكاوى',
  ];

  @override
  Widget build(BuildContext context) {
    // Directionality for Arabic (RTL)
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_selectedIndex]),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) context.go('/admin');
              },
            ),
          ],
        ),
        body: Row(
          children: [
            // Sidebar
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.pending_actions_outlined),
                  selectedIcon: Icon(Icons.pending_actions),
                  label: Text('الطلبات'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('الكباتن'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: Text('الرحلات الجارية'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history),
                  selectedIcon: Icon(Icons.history_toggle_off),
                  label: Text('سجل الرحلات'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: Text('المحافظ'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.credit_card_outlined),
                  selectedIcon: Icon(Icons.credit_card),
                  label: Text('كروت الشحن'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: Text('الإشعارات'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.report_problem_outlined),
                  selectedIcon: Icon(Icons.report_problem),
                  label: Text('الشكاوى'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Main content area
            Expanded(
              child: _screens[_selectedIndex],
            ),
          ],
        ),
      ),
    );
  }
}
