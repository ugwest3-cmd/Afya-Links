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
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestPayout() async {
    if (_walletBalance < 10000) {
      _showInfo('Minimum withdrawal is UGX 10,000');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.requestPayout();
      if (res.statusCode == 200) {
        _showSuccess('Settlement request sent to Admin');
        _loadWallet();
      } else {
        _showError('Request failed. Try again later.');
      }
    } catch (e) {
      _showError('Network error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade800, behavior: SnackBarBehavior.floating));
  }
  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF312E81), behavior: SnackBarBehavior.floating));
  }
  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF312E81);
    const accentCyan = Color(0xFF0891B2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('WALLET & SETTLEMENTS')),
      body: RefreshIndicator(
        onRefresh: _loadWallet,
        color: primaryIndigo,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Premium Balance Card
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryIndigo, Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: primaryIndigo.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available for Withdrawal', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          SizedBox(height: 4),
                          Text('Personal Wallet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text('UGX ${_walletBalance.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      _buildMiniEarn('LIFETIME EARNINGS', 'UGX ${_totalEarned.toInt()}'),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _loading ? null : _requestPayout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryIndigo,
                          minimumSize: const Size(120, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('WITHDRAW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                      ),
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            _buildHeader('TRANSACTION HISTORY'),
            if (_loading && _payoutHistory.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()))
            else if (_payoutHistory.isEmpty)
              _buildEmptyHistory()
            else
              ..._payoutHistory.map((p) => _buildPayoutCard(p, primaryIndigo)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniEarn(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          const Text('No previous settlements found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPayoutCard(dynamic payout, Color indigo) {
    String status = payout['status']?.toString().toUpperCase() ?? 'PENDING';
    Color statusColor = status == 'PAID' ? const Color(0xFF059669) : (status == 'REJECTED' ? Colors.red.shade700 : const Color(0xFFD97706));
    
    DateTime date = payout['created_at'] != null ? DateTime.parse(payout['created_at']).toLocal() : DateTime.now();
    String formattedDate = '${date.day} ${_getMonth(date.month)} ${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(status == 'PAID' ? Icons.check_rounded : Icons.schedule_rounded, color: statusColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UGX ${payout['amount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(formattedDate, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  String _getMonth(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m - 1];
  }
}
