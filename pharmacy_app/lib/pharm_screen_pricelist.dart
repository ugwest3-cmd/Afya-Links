import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';

class PharmPriceListScreen extends StatefulWidget {
  const PharmPriceListScreen({super.key});

  @override
  State<PharmPriceListScreen> createState() => _PharmPriceListScreenState();
}

class _PharmPriceListScreenState extends State<PharmPriceListScreen> {
  PlatformFile? _selectedFile;
  bool _uploading = false;
  bool _uploaded = false;
  String? _resultMessage;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock Management',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload CSV to update pricing & stock levels',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // CSV Format Guide Table
          _buildSectionHeader('Required Data Headers'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your CSV must contain these exact headers in row 1:',
                  style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'sku', 'drug_name', 'brand', 'strength', 'pack_size', 'unit', 'price', 'stock_qty'
                  ].map((h) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                    child: Text(h, style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'RobotoMono')),
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // File Picker Zone
          _buildSectionHeader('Select Document'),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: _selectedFile != null ? primary.withOpacity(0.03) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _selectedFile != null ? primary : Colors.grey.shade200,
                  width: _selectedFile != null ? 2 : 1,
                  style: BorderStyle.solid,
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFile != null ? Icons.file_present_rounded : Icons.add_to_photos_rounded,
                    color: _selectedFile != null ? primary : Colors.grey.shade300,
                    size: 52,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFile != null ? _selectedFile!.name : 'Drop or Tap to Select CSV',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedFile != null ? Colors.black87 : Colors.grey.shade400,
                      fontSize: 15,
                    ),
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB • Ready for sync',
                      style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedFile != null && !_uploading) ? _upload : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: primary,
              ),
              child: _uploading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_selectedFile == null ? 'Selection Required' : 'Sync Inventory Now →', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),

          if (_resultMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _uploaded ? const Color(0xFFF1F8F1) : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _uploaded ? primary.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(_uploaded ? Icons.check_circle_rounded : Icons.error_outline_rounded, 
                    color: _uploaded ? primary : Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _resultMessage!, 
                      style: TextStyle(color: _uploaded ? Colors.black87 : Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500)
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),

          // History Section
          _buildSectionHeader('Recent Submissions'),
          const SizedBox(height: 12),
          _HistoryTile(title: 'inventory_march_07.csv', date: 'Today, 10:45 AM', items: 124, status: 'Success'),
          _HistoryTile(title: 'stock_update_v2.csv', date: 'Yesterday, 04:20 PM', items: 89, status: 'Success'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.black54),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() { _selectedFile = result.files.first; _uploaded = false; _resultMessage = null; });
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null || _selectedFile!.bytes == null) return;
    setState(() => _uploading = true);
    try {
      final res = await ApiService.uploadPriceList('', _selectedFile!.bytes!, _selectedFile!.name);
      final body = jsonDecode(res.body);
      final ok = res.statusCode == 200;
      setState(() {
        _uploading = false;
        _uploaded = ok;
        _resultMessage = ok
            ? 'Success! ${body['items_count'] ?? '?'} items synchronized successfully.'
            : (body['message'] ?? 'Platform rejected the CSV file.');
      });
    } catch (_) {
      setState(() {
        _uploading = false;
        _resultMessage = 'Connection failed. Please check your internet.';
      });
    }
  }
}

class _HistoryTile extends StatelessWidget {
  final String title, date, status;
  final int items;
  const _HistoryTile({required this.title, required this.date, required this.items, required this.status});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: primary.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.description_rounded, color: primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text('$date • $items SKUs', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF1F8F1), borderRadius: BorderRadius.circular(6)),
            child: const Text('SYNCED', style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 9)),
          ),
        ],
      ),
    );
  }
}
