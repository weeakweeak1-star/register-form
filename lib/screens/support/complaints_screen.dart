import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/components/pagination_controls.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> complaints = [];
  bool isLoading = true;

  // Pagination State
  int currentPage = 0;
  final int itemsPerPage = 25;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() {
      isLoading = true;
      currentPage = 0;
    });
    try {
      final response = await supabase
          .from('complaints')
          .select('*, trips(id)')
          .order('created_at', ascending: false);
      setState(() {
        complaints = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _markAsProcessed(String id) async {
    try {
      await supabase.from('complaints').update({'status': 'processed'}).eq('id', id);
      _fetchComplaints();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginatedComplaints = complaints.skip(currentPage * itemsPerPage).take(itemsPerPage).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('البلاغات والشكاوى', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : complaints.isEmpty
                    ? const Center(child: Text('لا توجد شكاوى جديدة'))
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: paginatedComplaints.length,
                              itemBuilder: (context, index) {
                                final complaint = paginatedComplaints[index];
                                final status = complaint['status'] ?? 'pending';
                                return Card(
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.report,
                                      color: status == 'processed' ? Colors.green : Colors.orange,
                                    ),
                                    title: Text(complaint['message'] ?? 'بدون نص'),
                                    subtitle: Text('رقم الرحلة: ${complaint['trip_id']} | الحالة: $status'),
                                    trailing: status != 'processed'
                                        ? ElevatedButton(
                                            onPressed: () => _markAsProcessed(complaint['id']),
                                            child: const Text('تمت المعالجة'),
                                          )
                                        : const Icon(Icons.check_circle, color: Colors.green),
                                  ),
                                );
                              },
                            ),
                          ),
                          PaginationControls(
                            currentPage: currentPage,
                            totalItems: complaints.length,
                            itemsPerPage: itemsPerPage,
                            onNext: () {
                              setState(() {
                                currentPage++;
                              });
                            },
                            onPrevious: () {
                              setState(() {
                                currentPage--;
                              });
                            },
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
