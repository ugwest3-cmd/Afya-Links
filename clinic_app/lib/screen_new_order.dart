import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'screen_price_offers.dart';

// ─── Step 1 & 2: Drug Items + Pharmacy Selection ─────────────────────────────

class NewOrderScreen extends StatefulWidget {
  final VoidCallback? onOrderPlaced;
  const NewOrderScreen({super.key, this.onOrderPlaced});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // --- Drug items list ---
  final List<_DrugItem> _drugs = [_DrugItem()];

  // --- Pharmacy selection ---
  List<Map<String, dynamic>> _pharmacies = [];
  List<String> _selectedPharmacyIds = [];
  bool _loadingPharmacies = true;
  String _deliveryAddress = '';
  final TextEditingController _addressCtrl = TextEditingController();

  static const _primary = Color(0xFF0D47A1);
  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
    _fetchProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _addressCtrl.dispose();
    for (var drug in _drugs) {
      drug.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await ApiService.getProfileStatus();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (data != null && data['address'] != null) {
          setState(() {
            _deliveryAddress = data['address'];
            _addressCtrl.text = _deliveryAddress;
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
    return hasValidDrug && _selectedPharmacyIds.isNotEmpty && _addressCtrl.text.isNotEmpty;
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _goToOffers();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
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
          deliveryAddress: _addressCtrl.text,
          onOrderPlaced: widget.onOrderPlaced,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stepper Progress
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              _stepIndicator(0, 'Items', Icons.medication_rounded),
              _stepConnector(0),
              _stepIndicator(1, 'Pharmacies', Icons.local_pharmacy_rounded),
              _stepConnector(1),
              _stepIndicator(2, 'Review', Icons.fact_check_rounded),
            ],
          ),
        ),
        
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (idx) => setState(() => _currentStep = idx),
            children: [
              _buildStep1(),
              _buildStep2(),
              _buildStep3(),
            ],
          ),
        ),

        // Bottom Navigation
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _prevStep,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: _primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back', style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _canProceedAtStep(_currentStep) ? _nextStep : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: _primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentStep == 2 ? 'View Price Offers →' : 'Continue',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _canProceedAtStep(int step) {
    if (step == 0) return _drugs.any((d) => d.nameCtrl.text.trim().isNotEmpty && d.quantityCtrl.text.trim().isNotEmpty);
    if (step == 1) return _selectedPharmacyIds.isNotEmpty;
    if (step == 2) return _addressCtrl.text.isNotEmpty;
    return false;
  }

  Widget _stepIndicator(int index, String label, IconData icon) {
    bool active = _currentStep >= index;
    bool isCurrent = _currentStep == index;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active ? _primary : Colors.grey.shade200,
              shape: BoxShape.circle,
              border: isCurrent ? Border.all(color: _primary.withOpacity(0.3), width: 4) : null,
            ),
            child: Icon(icon, color: active ? Colors.white : Colors.grey, size: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 10, 
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: active ? _primary : Colors.grey
          )),
        ],
      ),
    );
  }

  Widget _stepConnector(int index) {
    bool active = _currentStep > index;
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: active ? _primary : Colors.grey.shade200,
    );
  }

  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('💊 Drug Items'),
        const SizedBox(height: 10),
        ..._drugs.asMap().entries.map((e) => _DrugRow(
              item: e.value,
              index: e.key,
              canRemove: _drugs.length > 1,
              onRemove: () {
                e.value.dispose();
                setState(() => _drugs.removeAt(e.key));
              },
              onChanged: () => setState(() {}),
            )),
        TextButton.icon(
          onPressed: () => setState(() => _drugs.add(_DrugItem())),
          icon: const Icon(Icons.add_circle_outline, color: _primary, size: 18),
          label: const Text('Add another drug', style: TextStyle(color: _primary, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        const Text('Select up to 2 pharmacies to compare prices.',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        if (_loadingPharmacies)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else
          ..._pharmacies.map((p) {
            final isSelected = _selectedPharmacyIds.contains(p['id']);
            return GestureDetector(
              onTap: () => _togglePharmacy(p['id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? _primary.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? _primary : Colors.grey.shade200, width: isSelected ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Icon(isSelected ? Icons.check_circle_rounded : Icons.local_pharmacy_outlined,
                        color: isSelected ? _primary : Colors.grey, size: 22),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(p['address'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    )),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStep3() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('📍 Delivery Address'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primary.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on_rounded, color: _primary, size: 20),
                  SizedBox(width: 8),
                  Text('Confirm Location', style: TextStyle(fontWeight: FontWeight.bold, color: _primary)),
                ],
              ),
              const SizedBox(height: 12),
              Text(_deliveryAddress, style: const TextStyle(fontSize: 14, color: Colors.black87)),
              const Divider(height: 24),
              TextButton.icon(
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update address in Profile section.')));
                },
                icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                label: const Text('Change default address'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionLabel('📋 Order Summary'),
        const SizedBox(height: 12),
        ..._drugs.where((d) => d.nameCtrl.text.isNotEmpty).map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 6, color: _primary),
              const SizedBox(width: 10),
              Expanded(child: Text(d.nameCtrl.text, style: const TextStyle(fontSize: 13))),
              Text('Qty: ${d.quantityCtrl.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87));
}

// ─── Drug Row Widget ──────────────────────────────────────────────────────────

class _DrugItem {
  final nameCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    quantityCtrl.dispose();
  }
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
            onSelected: (s) {
              item.nameCtrl.text = s;
              onChanged();
            },
            fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
              // Use a PostFrameCallback or a more stable sync to avoid setstate during build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctrl.text != item.nameCtrl.text) {
                  ctrl.text = item.nameCtrl.text;
                }
              });

              return TextField(
                controller: ctrl,
                focusNode: focusNode,
                onChanged: (val) {
                  item.nameCtrl.text = val;
                  onChanged();
                },
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
