import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final titleController = TextEditingController();
  final messageController = TextEditingController();

  Future<void> _sendBulkNotification() async {
    if (titleController.text.isEmpty || messageController.text.isEmpty) return;

    // Here we would typically call a Supabase Edge Function that sends push notifications to all users.
    // For now, we simulate success.
    try {
      // await Supabase.instance.client.functions.invoke('send-bulk-notification', body: {
      //   'title': titleController.text,
      //   'message': messageController.text,
      // });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ميزة الإشعارات قيد التطوير وسيتم تفعيلها لاحقاً.')));
      titleController.clear();
      messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إرسال إشعارات جماعية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'عنوان الإشعار',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: messageController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'نص الإشعار',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _sendBulkNotification,
            icon: const Icon(Icons.send),
            label: const Text('إرسال لجميع الكباتن'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
