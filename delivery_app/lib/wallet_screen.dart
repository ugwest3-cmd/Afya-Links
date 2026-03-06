import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  double _walletBalance = 0;
  double _totalEarned = 0;
  List<dynamic> _payoutHistory = [];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getDriverWallet();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _walletBalance = (data['wallet_balance'] ?? 0).toDouble();
          _totalEarned = (data['total_earned'] ?? 0).toDouble();
          _payoutHistory = data['payouts'] ?? [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load wallet data')));
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestPayout() async {
    if (_walletBalance < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum payout is UGX 10,000')));
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.requestPayout();
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout requested successfully')));
        _loadWallet();
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Failed to request payout';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadWallet,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Top Balances
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF1E40AF).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                    ]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('UGX ${_walletBalance.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Earned', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              Text('UGX ${_totalEarned.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _requestPayout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1E40AF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        ],
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                const Text('Payout History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const SizedBox(height: 16),
                
                if (_payoutHistory.isEmpty)
                  _buildEmptyHistory()
                else
                  ..._payoutHistory.map((p) => _buildPayoutCard(p)),
              ],
            ),
          ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: const Color(0xFF9CA3AF).withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No payout requests yet', style: TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _buildPayoutCard(dynamic payout) {
    Color statusColor;
    IconData statusIcon;
    switch (payout['status']) {
      case 'PAID':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'REJECTED':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending_actions_rounded;
    }

    // Format date string safely
    String dateStr = 'Unknown Date';
    if (payout['created_at'] != null) {
      try {
        final d = DateTime.parse(payout['created_at']).toLocal();
        dateStr = '${d.day}/${d.month}/${d.year}';
      } catch (e) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UGX ${payout['amount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                const SizedBox(height: 4),
                Text(dateStr, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          ),
          Text(
            payout['status']?.toString() ?? 'PENDING',
            style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
