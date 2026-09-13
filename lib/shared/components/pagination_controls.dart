import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int itemsPerPage;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.itemsPerPage,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    final int totalPages = (totalItems / itemsPerPage).ceil();
    final int displayPage = totalPages == 0 ? 0 : currentPage + 1;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: (currentPage + 1) < totalPages ? onNext : null,
            icon: const Icon(Icons.arrow_back_ios, size: 14),
            label: const Text('التالي'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade50,
              foregroundColor: Colors.indigo,
              elevation: 0,
            ),
          ),
          Text(
            'صفحة $displayPage من $totalPages',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          ElevatedButton(
            onPressed: currentPage > 0 ? onPrevious : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade50,
              foregroundColor: Colors.indigo,
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('السابق'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
