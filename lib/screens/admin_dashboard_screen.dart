import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  
  List<dynamic> _pendingApps = [];
  List<dynamic> _rejectedApps = [];
  bool _isLoading = true;
  
  // Stats
  int _activeDrivers = 0;
  int _liveTrips = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Applications
      final data = await _supabase
          .from('driver_applications')
          .select()
          .inFilter('status', ['pending', 'rejected'])
          .order('created_at', ascending: false);
          
      // 2. Fetch Active Drivers Count
      final driversResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('is_driver', true);
          
      // 3. Fetch Live Trips Count
      final tripsResponse = await _supabase
          .from('trips')
          .select('id')
          .eq('status', 'ongoing');
          
      setState(() {
        _pendingApps = data.where((app) => app['status'] == 'pending').toList();
        _rejectedApps = data.where((app) => app['status'] == 'rejected').toList();
        _activeDrivers = driversResponse.length;
        _liveTrips = tripsResponse.length;
      });
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatCard(String title, String count, IconData icon, List<Color> gradientColors) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: gradientColors[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(count, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Stats
          Row(
            children: [
              _buildStatCard(
                'الطلبات المعلقة',
                _isLoading ? '...' : '${_pendingApps.length}',
                Icons.pending_actions_rounded,
                [Colors.orange.shade400, Colors.deepOrange.shade600],
              ),
              _buildStatCard(
                'الكباتن النشطين',
                _isLoading ? '...' : '$_activeDrivers',
                Icons.people_alt_rounded,
                [Colors.blue.shade400, Colors.indigo.shade600],
              ),
              _buildStatCard(
                'الرحلات الجارية',
                _isLoading ? '...' : '$_liveTrips',
                Icons.map_rounded,
                [Colors.green.shade400, Colors.teal.shade600],
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Tabs Area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: TabBar(
                              indicatorSize: TabBarIndicatorSize.label,
                              indicatorColor: Colors.indigo.shade600,
                              labelColor: Colors.indigo.shade800,
                              unselectedLabelColor: Colors.grey.shade500,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              tabs: const [
                                Tab(text: 'الطلبات المعلقة'),
                                Tab(text: 'الطلبات المرفوضة'),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade50,
                              foregroundColor: Colors.indigo.shade700,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _fetchDashboardData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('تحديث'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : TabBarView(
                              children: [
                                _buildList(_pendingApps),
                                _buildList(_rejectedApps, isRejected: true),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<dynamic> apps, {bool isRejected = false}) {
    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              isRejected ? 'لا توجد طلبات مرفوضة' : 'لا توجد طلبات معلقة',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 5, offset: const Offset(0, 2))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.indigo.shade50,
              backgroundImage: NetworkImage(app['profile_picture_url'] ?? ''),
              onBackgroundImageError: (_, __) {},
              child: app['profile_picture_url'] == null || app['profile_picture_url'].isEmpty
                  ? Icon(Icons.person, color: Colors.indigo.shade300)
                  : null,
            ),
            title: Text(app['full_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(app['phone_number'] ?? '', style: TextStyle(color: Colors.grey.shade600)),
                  if (isRejected) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.error_outline, size: 14, color: Colors.red.shade400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'السبب: ${app['reject_reason'] ?? 'غير محدد'}',
                        style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRejected ? Colors.grey.shade200 : Colors.indigo.shade600,
                foregroundColor: isRejected ? Colors.grey.shade700 : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () {
                context.push('/admin/review/${app['id']}').then((_) => _fetchDashboardData());
              },
              child: const Text('مراجعة الملف'),
            ),
          ),
        );
      },
    );
  }
}
