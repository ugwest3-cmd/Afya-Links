import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class PharmPayoutsScreen extends StatefulWidget {
  const PharmPayoutsScreen({super.key});

  @override
  State<PharmPayoutsScreen> createState() => _PharmPayoutsScreenState();
}

class _PharmPayoutsScreenState extends State<PharmPayoutsScreen> {
  static const _primary = Color(0xFF1B5E20);
  
  bool _isLoading = true;
  double _availableBalance = 0;
  List<dynamic> _history = [];
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _fetchPayoutData();
  }

  Future<void> _fetchPayoutData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getPayoutHistory();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success']) {
          setState(() {
            _availableBalance = (data['available_balance'] ?? 0).toDouble();
            _history = data['data'] ?? [];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _requestPayout() async {
    if (_availableBalance < 500000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum withdrawal is UGX 500,000')));
      return;
    }

    setState(() => _isRequesting = true);
    try {
      final res = await ApiService.requestPayout();
      final data = jsonDecode(res.body);
      
      if (res.statusCode == 200 && data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout requested successfully!')));
        _fetchPayoutData(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to request payout'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error requesting payout')));
    } finally {
      setState(() => _isRequesting = false);
    }
  }

  Future<void> _showPayoutConfigSheet() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _primary)),
    );
    
    Map<String, dynamic>? profileData;
    try {
      final res = await ApiService.getProfileStatus();
      if (res.statusCode == 200) profileData = jsonDecode(res.body)['data'];
    } catch (_) {}
    
    if (mounted) Navigator.pop(context); // close loading

    if (profileData == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load payout settings.')));
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payout Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: selectedMethod,
                decoration: const InputDecoration(labelText: 'Preferred Payout Method'),
                items: ['Mobile Money', 'Bank Transfer', 'Cash Collection']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedMethod = val);
                },
              ),
              const SizedBox(height: 16),
              
              if (selectedMethod == 'Mobile Money') ...[
                TextField(
                  controller: accountNameCtrl,
                  decoration: const InputDecoration(labelText: 'Registered Name (e.g., John Doe)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountNoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Money Number (e.g., 077...)'),
                ),
              ] else if (selectedMethod == 'Bank Transfer') ...[
                TextField(
                  controller: bankNameCtrl,
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountNameCtrl,
                  decoration: const InputDecoration(labelText: 'Account Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountNoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Account Number'),
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('You will collect your payouts in person at the AfyaLinks head office.', style: TextStyle(color: Colors.grey)),
                )
              ],
              
              const SizedBox(height: 24),
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
                        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Payout config saved!')));
                      } else {
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed: ${jsonDecode(res.body)['message']}')));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Network Error')));
                    } finally {
                      setModalState(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Configuration', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  String _formatCurrency(double val) {
    String s = val.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    s = s.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return 'UGX $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Wallet & Payouts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Payout Settings',
            onPressed: _showPayoutConfigSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _primary))
        : RefreshIndicator(
            onRefresh: _fetchPayoutData,
            color: _primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balance Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_primary, Color(0xFF2E7D32)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(_formatCurrency(_availableBalance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_availableBalance >= 500000 && !_isRequesting) ? _requestPayout : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            disabledBackgroundColor: Colors.white.withOpacity(0.5),
                          ),
                          child: _isRequesting 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Request Payout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (_availableBalance < 500000)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('Minimum withdrawal is UGX 500,000', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        )
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // History List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payout History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_history.isNotEmpty)
                      Text('${_history.length} requests', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (_history.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No payout history found.', style: TextStyle(color: Colors.grey.shade600)),
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
                      final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : 'Unknown date';
                      final status = item['status'] as String? ?? 'UNKNOWN';
                      
                      Color statusColor = Colors.orange;
                      if (status == 'PAID') statusColor = Colors.green;
                      else if (status == 'FAILED') statusColor = Colors.red;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.account_balance_wallet, color: statusColor, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('${item['payment_method']} · $dateStr', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          )
    );
  }
}
