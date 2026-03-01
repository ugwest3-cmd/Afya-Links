import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'screen_price_offers.dart';

// ─── Step 1 & 2: Drug Items + Pharmacy Selection ─────────────────────────────

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  // --- Drug items list ---
  final List<_DrugItem> _drugs = [_DrugItem()];

  // --- Pharmacy selection ---
  List<Map<String, dynamic>> _pharmacies = [];
  List<String> _selectedPharmacyIds = [];
  bool _loadingPharmacies = true;
  String _deliveryAddress = '';

  static const _primary = Color(0xFF0D47A1);
  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await ApiService.getProfileStatus();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (data != null && data['address'] != null) {
          setState(() {
            _deliveryAddress = data['address'];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPharmacies() async {
    try {
      final res = await ApiService.getPharmacies();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _pharmacies = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _loadingPharmacies = false;
        });
      } else {
        setState(() { _pharmacies = _mockPharmacies; _loadingPharmacies = false; });
      }
    } catch (_) {
      setState(() { _pharmacies = _mockPharmacies; _loadingPharmacies = false; });
    }
  }

  List<Map<String, dynamic>> get _mockPharmacies => [
    {'id': 'pharm-001', 'name': 'City Pharmacy', 'address': 'Kampala Road, Kampala', 'phone': '+256 700 111 222'},
    {'id': 'pharm-002', 'name': 'Nakasero Drug Shop', 'address': 'Nakasero, Kampala', 'phone': '+256 700 333 444'},
    {'id': 'pharm-003', 'name': 'Mulago Pharmacy Plus', 'address': 'Mulago Hill, Kampala', 'phone': '+256 700 555 666'},
  ];

  void _togglePharmacy(String id) {
    setState(() {
      if (_selectedPharmacyIds.contains(id)) {
        _selectedPharmacyIds.remove(id);
      } else if (_selectedPharmacyIds.length < 2) {
        _selectedPharmacyIds.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You can select up to 2 pharmacies'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });
  }

  bool get _canProceed {
    final hasValidDrug = _drugs.any((d) => d.nameCtrl.text.trim().isNotEmpty && d.quantityCtrl.text.trim().isNotEmpty);
    return hasValidDrug && _selectedPharmacyIds.isNotEmpty && _deliveryAddress.isNotEmpty;
  }

  void _goToOffers() {
    final validDrugs = _drugs
        .where((d) => d.nameCtrl.text.trim().isNotEmpty && d.quantityCtrl.text.trim().isNotEmpty)
        .map((d) => {'drug_name': d.nameCtrl.text.trim(), 'quantity': int.tryParse(d.quantityCtrl.text.trim()) ?? 1})
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PriceOffersScreen(
          drugs: validDrugs,
          pharmacyIds: _selectedPharmacyIds,
          pharmacies: _pharmacies.where((p) => _selectedPharmacyIds.contains(p['id'])).toList(),
          deliveryAddress: _deliveryAddress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _HeaderCard(
            step: 1,
            totalSteps: 3,
            icon: Icons.medication_rounded,
            title: 'What do you need?',
            subtitle: 'Add drugs and select pharmacies',
          ),
          const SizedBox(height: 22),

          // ─── STEP 1: Drug Items ──────────────────────────────────────────
          _sectionLabel('💊 Drug Items'),
          const SizedBox(height: 10),
          ..._drugs.asMap().entries.map((e) => _DrugRow(
                item: e.value,
                index: e.key,
                canRemove: _drugs.length > 1,
                onRemove: () => setState(() => _drugs.removeAt(e.key)),
                onChanged: () => setState(() {}),
              )),
          TextButton.icon(
            onPressed: () => setState(() => _drugs.add(_DrugItem())),
            icon: const Icon(Icons.add_circle_outline, color: _primary, size: 18),
            label: const Text('Add another drug', style: TextStyle(color: _primary, fontSize: 13)),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 14),

          // ─── STEP 2: Pharmacy Selection ──────────────────────────────────
          Row(children: [
            _sectionLabel('🏪 Select Pharmacies'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('${_selectedPharmacyIds.length}/2 selected',
                  style: const TextStyle(color: _primary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('We show you hidden prices from your selected pharmacies. Max 2.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),

          _loadingPharmacies
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: _primary),
                ))
              : Column(
                  children: _pharmacies.map((p) {
                    final isSelected = _selectedPharmacyIds.contains(p['id']);
                    return GestureDetector(
                      onTap: () => _togglePharmacy(p['id']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? _primary : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSelected ? _primary : Colors.grey.shade200, width: isSelected ? 2 : 1),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            Icon(isSelected ? Icons.check_circle_rounded : Icons.local_pharmacy_outlined,
                                color: isSelected ? Colors.white : _primary, size: 22),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name'] ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                    )),
                                Text(p['address'] ?? '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected ? Colors.white70 : Colors.grey,
                                    )),
                              ],
                            )),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                child: const Text('Selected', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),

          // ─── Delivery Address ────────────────────────────────────────────
          _sectionLabel('📍 Delivery Address'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: TextEditingController(text: _deliveryAddress),
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Loading address...',
                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                prefixIcon: const Icon(Icons.location_on_rounded, color: _primary, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: _primary),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please go to your Profile to update your default delivery address.')),
                    );
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // CTA
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _canProceed ? _goToOffers : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _canProceed ? 'View Price Offers →' : 'Fill in all fields',
                    style: TextStyle(
                      color: _canProceed ? Colors.white : Colors.grey.shade500,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87));
}

// ─── Drug Row Widget ──────────────────────────────────────────────────────────

class _DrugItem {
  final nameCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();
}

class _DrugRow extends StatelessWidget {
  final _DrugItem item;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _DrugRow({required this.item, required this.index, required this.canRemove, required this.onRemove, required this.onChanged});

  static const _primary = Color(0xFF0D47A1);

  // Common drug suggestions for autocomplete
  static const _suggestions = [
    'Amoxicillin 500mg', 'Paracetamol 500mg', 'Paracetamol 1g', 'Metformin 500mg',
    'Metronidazole 400mg', 'Ciprofloxacin 500mg', 'Ibuprofen 400mg', 'ORS Sachets',
    'IV Normal Saline 500ml', 'IV Dextrose 5%', 'Amoxicillin 250mg Syrup',
    'Cotrimoxazole 480mg', 'Doxycycline 100mg', 'Artemether/Lumefantrine',
    'Glibenclamide 5mg', 'Aspirin 75mg', 'Omeprazole 20mg', 'Salbutamol Inhaler',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            const Text('Drug', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            if (canRemove)
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
              ),
          ]),
          const SizedBox(height: 10),
          // Autocomplete Drug Name
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
              return _suggestions.where((s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (s) { item.nameCtrl.text = s; onChanged(); },
            fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
              // Sync the autocomplete's internal controller with our item controller
              ctrl.text = item.nameCtrl.text;
              ctrl.addListener(() { item.nameCtrl.text = ctrl.text; onChanged(); });
              return TextField(
                controller: ctrl,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Search drug name...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: _primary, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF0F4FF),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              );
            },
            optionsViewBuilder: (ctx, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: options.map((o) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.medication_outlined, size: 16, color: _primary),
                      title: Text(o, style: const TextStyle(fontSize: 13)),
                      onTap: () => onSelected(o),
                    )).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.quantityCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: 'Quantity (e.g. 50)',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: const Icon(Icons.format_list_numbered_rounded, color: _primary, size: 18),
              filled: true,
              fillColor: const Color(0xFFF0F4FF),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Header Card ───────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final int step, totalSteps;
  final IconData icon;
  final String title, subtitle;

  const _HeaderCard({required this.step, required this.totalSteps, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step $step of $totalSteps', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          )),
        ],
      ),
    );
  }
}
