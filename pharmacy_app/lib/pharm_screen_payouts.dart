import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class PharmPayoutsScreen extends StatefulWidget {
  const PharmPayoutsScreen({super.key});

  @override
  State<PharmPayoutsScreen> createState() => _PharmPayoutsScreenState();
}

class _PharmPayoutsScreenState extends State<PharmPayoutsScreen> {
  bool _isLoading = true;
  double _availableBalance = 0;
  List<dynamic> _history = [];
  bool _isRequesting = false;
  Map<String, dynamic> _stats = {'total_earnings': 0, 'pending_balance': 0};

  @override
  void initState() {
    super.initState();
    _fetchPayoutData();
  }

  Future<void> _fetchPayoutData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getPayoutHistory();
      final statsRes = await ApiService.getDashboardStats();

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success']) {
          _availableBalance = (data['available_balance'] ?? 0).toDouble();
          _history = data['data'] ?? [];
        }
      }

      if (statsRes.statusCode == 200) {
        final sData = jsonDecode(statsRes.body);
        if (sData['success']) {
          _stats = Map<String, dynamic>.from(sData['stats']);
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _requestPayout() async {
    if (_availableBalance < 500000) {
      _showSnack('Minimum withdrawal is UGX 500,000', isError: true);
      return;
    }

    setState(() => _isRequesting = true);
    try {
      final res = await ApiService.requestPayout();
      final data = jsonDecode(res.body);
      
      if (res.statusCode == 200 && data['success']) {
        _showSnack('Payout requested successfully!');
        _fetchPayoutData(); 
      } else {
        _showSnack(data['message'] ?? 'Failed to request payout', isError: true);
      }
    } catch (e) {
      _showSnack('Network error requesting payout', isError: true);
    } finally {
      setState(() => _isRequesting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF1B5E20),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatCurrency(double val) {
    String s = val.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    s = s.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return 'UGX $s';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primary))
        : RefreshIndicator(
            onRefresh: _fetchPayoutData,
            color: primary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Premium Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, const Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Available for Payout', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                                SizedBox(height: 4),
                                Text('Wallet Balance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(_formatCurrency(_availableBalance), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.black, letterSpacing: -1)),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_availableBalance >= 500000 && !_isRequesting) ? _requestPayout : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                            child: _isRequesting 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Request Settlement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        if (_availableBalance < 500000)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text('Next payout at UGX 500,000 threshold', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w500)),
                          )
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Stats Row
                  Row(
                    children: [
                      _StatItem(label: 'Total Earnings', value: _stats['total_earnings']?.toString() ?? '0', color: primary, icon: Icons.trending_up_rounded),
                      const SizedBox(width: 12),
                      _StatItem(label: 'Pending', value: _stats['pending_balance']?.toString() ?? '0', color: Colors.orange, icon: Icons.hourglass_top_rounded),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // History List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Settlements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: _showPayoutConfigSheet,
                        icon: Icon(Icons.settings_suggest_rounded, color: primary, size: 22),
                        tooltip: 'Payout Settings',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (_history.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade200),
                            const SizedBox(height: 16),
                            Text('No payout records found yet.', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        final amount = item['amount'] is num ? (item['amount'] as num).toDouble() : double.tryParse(item['amount'].toString()) ?? 0;
                        final date = DateTime.tryParse(item['created_at'] ?? '')?.toLocal();
                        final status = item['status'] as String? ?? 'UNKNOWN';
                        
                        Color statusColor = Colors.orange;
                        if (status == 'PAID') statusColor = primary;
                        else if (status == 'FAILED') statusColor = Colors.red;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                                child: Icon(Icons.account_balance_wallet_rounded, color: statusColor, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text('${item['payment_method']} • ${date?.day}/${date?.month}/${date?.year}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          )
    );
  }

  Future<void> _showPayoutConfigSheet() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    Map<String, dynamic>? profileData;
    try {
      final res = await ApiService.getProfileStatus();
      if (res.statusCode == 200) profileData = jsonDecode(res.body)['data'];
    } catch (_) {}
    
    if (mounted) Navigator.pop(context); // close loading

    if (profileData == null) {
      if (mounted) _showSnack('Failed to load payout settings.', isError: true);
      return;
    }

    String selectedMethod = profileData['preferred_payout_method'] ?? 'Mobile Money';
    final Map<String, dynamic> existingDetails = profileData['payout_details'] ?? {};
    
    final TextEditingController accountNameCtrl = TextEditingController(text: existingDetails['accountName'] ?? '');
    final TextEditingController accountNoCtrl = TextEditingController(text: existingDetails['accountNumber'] ?? '');
    final TextEditingController bankNameCtrl = TextEditingController(text: existingDetails['bankName'] ?? '');
    
    bool isSaving = false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4, 
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const Text('Payout Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: const InputDecoration(labelText: 'Preferred Method'),
                  items: ['Mobile Money', 'Bank Transfer', 'Cash Collection']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedMethod = val);
                  },
                ),
                const SizedBox(height: 20),
                
                if (selectedMethod == 'Mobile Money') ...[
                  TextField(
                    controller: accountNameCtrl,
                    decoration: const InputDecoration(labelText: 'Registered Account Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: accountNoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile Number'),
                  ),
                ] else if (selectedMethod == 'Bank Transfer') ...[
                  TextField(
                    controller: bankNameCtrl,
                    decoration: const InputDecoration(labelText: 'Bank Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: accountNameCtrl,
                    decoration: const InputDecoration(labelText: 'Account Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: accountNoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Account Number'),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Cash collection details will be coordinated via support.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  )
                ],
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      setModalState(() => isSaving = true);
                      
                      Map<String, dynamic> details = {};
                      if (selectedMethod == 'Mobile Money') {
                        details = {'accountName': accountNameCtrl.text, 'accountNumber': accountNoCtrl.text};
                      } else if (selectedMethod == 'Bank Transfer') {
                        details = {'bankName': bankNameCtrl.text, 'accountName': accountNameCtrl.text, 'accountNumber': accountNoCtrl.text};
                      }
                      
                      try {
                        final res = await ApiService.updateProfilePreferences({
                          'preferred_payout_method': selectedMethod,
                          'payout_details': details,
                        });
                        if (res.statusCode == 200) {
                          if (mounted) Navigator.pop(ctx);
                          _showSnack('Configuration updated');
                        } else {
                          _showSnack('Failed to update settings', isError: true);
                        }
                      } catch (e) {
                        _showSnack('Network error', isError: true);
                      } finally {
                        setModalState(() => isSaving = false);
                      }
                    },
                    child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save and Apply Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value, colorLabel = '';
  final Color color;
  final IconData icon;

  const _StatItem({required this.label, required this.value, required this.color, required this.icon});

  String _formatCurrency(String val) {
    try {
      double d = double.parse(val);
      String s = d.toStringAsFixed(0);
      RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      s = s.replaceAllMapped(reg, (Match m) => '${m[1]},');
      return 'UGX $s';
    } catch (_) {
      return 'UGX $val';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 16),
            Text(_formatCurrency(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
