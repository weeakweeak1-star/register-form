import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> _pendingApps = [];
  List<dynamic> _rejectedApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('driver_applications')
          .select()
          .inFilter('status', ['pending', 'rejected'])
          .order('created_at', ascending: false);
      setState(() {
        _pendingApps = data.where((app) => app['status'] == 'pending').toList();
        _rejectedApps = data.where((app) => app['status'] == 'rejected').toList();
      });
    } catch (e) {
      debugPrint('Error fetching applications: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: TabBar(
                    tabs: [
                      Tab(text: 'الطلبات المعلقة'),
                      Tab(text: 'الطلبات المرفوضة'),
                    ],
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _fetchApplications,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث'),
                ),
              ],
            ),
          ),
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
    );
  }

  Widget _buildList(List<dynamic> apps, {bool isRejected = false}) {
    if (apps.isEmpty) {
      return Center(child: Text(isRejected ? 'لا توجد طلبات مرفوضة' : 'لا توجد طلبات معلقة'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(app['profile_picture_url'] ?? ''),
              onBackgroundImageError: (_, __) {},
            ),
            title: Text(app['full_name'] ?? 'بدون اسم'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app['phone_number'] ?? ''),
                if (isRejected)
                  Text(
                    'السبب: ${app['reject_reason'] ?? 'غير محدد'}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () {
                context.push('/admin/review/${app['id']}').then((_) => _fetchApplications());
              },
              child: const Text('مراجعة'),
            ),
          ),
        );
      },
    );
  }
}
