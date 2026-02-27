import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class PharmInvoicesScreen extends StatefulWidget {
  const PharmInvoicesScreen({super.key});

  @override
  State<PharmInvoicesScreen> createState() => _PharmInvoicesScreenState();
}

class _PharmInvoicesScreenState extends State<PharmInvoicesScreen> {
  bool _isLoading = true;
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    try {
      final res = await ApiService.getInvoices();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _invoices = data['invoices'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showError('Failed to load invoices');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error connecting to server.');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Invoices', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final inv = _invoices[index];
                    return _InvoiceCard(invoice: inv);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No Invoices Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            'You do not have any invoices yet.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final statusColor = invoice['status'] == 'PAID'
        ? Colors.green
        : invoice['status'] == 'PENDING_VERIFICATION'
            ? Colors.orange
            : Colors.red;

    final date = DateTime.tryParse(invoice['created_at'] ?? '');
    final formattedDate = date != null ? DateFormat('MMM dd, yyyy').format(date) : 'Unknown Date';
    final orderCode = invoice['order']?['order_code'] ?? 'Unknown Order';
    final amount = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0).format(invoice['amount'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order $orderCode',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  invoice['status']?.toString().replaceAll('_', ' ') ?? 'UNKNOWN',
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Amount', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B5E20))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Date Generated', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
