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

  static const _primary = Color(0xFF1B5E20);
  static const _green = Color(0xFF2E7D32);

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
            ? 'Uploaded! ${body['items_count'] ?? '?'} items · Valid for 48hrs'
            : (body['message'] ?? 'Upload failed');
      });
    } catch (_) {
      setState(() {
        _uploading = false;
        _resultMessage = 'Network error. Is the server running?';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _primary.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: const Row(children: [
              Icon(Icons.upload_file_rounded, color: Colors.white, size: 30),
              SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Upload Price List', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                Text('CSV format · Valid for 48 hours', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // CSV Format Guide
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.info_outline_rounded, color: _primary, size: 18),
                SizedBox(width: 8),
                Text('Required CSV Format', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF1F8F1), borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  'sku,drug_name,brand,strength,pack_size,unit,price,stock_qty',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF1B5E20)),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Example row:', style: TextStyle(color: Colors.grey, fontSize: 11)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF1F8F1), borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  'AMX001,Amoxicillin 500mg,Generic,500mg,Strip 10,tabs,450,200',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black54),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // File picker area
          GestureDetector(
            onTap: _pickFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: _selectedFile != null ? const Color(0xFFF1F8F1) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedFile != null ? _primary : Colors.grey.shade300,
                  width: _selectedFile != null ? 2 : 1,
                  style: BorderStyle.solid,
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  _selectedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                  color: _selectedFile != null ? _green : Colors.grey.shade400,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedFile != null ? _selectedFile!.name : 'Tap to select CSV file',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _selectedFile != null ? _primary : Colors.grey,
                    fontSize: 14,
                  ),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB · Tap to change',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  const Text('.csv files only', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Result message
          if (_resultMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _uploaded ? const Color(0xFFE8F5E9) : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _uploaded ? _green : Colors.red.shade200),
              ),
              child: Row(children: [
                Icon(_uploaded ? Icons.check_circle : Icons.error_outline,
                    color: _uploaded ? _green : Colors.red, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_resultMessage!, style: TextStyle(color: _uploaded ? _green : Colors.red.shade700, fontSize: 13))),
              ]),
            ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_selectedFile != null && !_uploading) ? _upload : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _uploading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _selectedFile == null ? 'Select a CSV file first' : 'Upload Price List',
                        style: TextStyle(
                          color: _selectedFile == null ? Colors.grey.shade500 : Colors.white,
                          fontSize: 16, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ]),
            ),
          ),

          // Active price lists
          const SizedBox(height: 28),
          const Text('Current Price Lists', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _PriceListTile(name: 'Price List #3', items: 48, expiresIn: '36 hrs', active: true),
          _PriceListTile(name: 'Price List #2', items: 52, expiresIn: 'Expired', active: false),
        ],
      ),
    );
  }
}

class _PriceListTile extends StatelessWidget {
  final String name, expiresIn;
  final int items;
  final bool active;
  const _PriceListTile({required this.name, required this.items, required this.expiresIn, required this.active});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1B5E20).withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.list_alt_rounded, color: active ? const Color(0xFF1B5E20) : Colors.grey, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text('$items items · Expires: $expiresIn', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1B5E20).withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            active ? 'ACTIVE' : 'EXPIRED',
            style: TextStyle(
              color: active ? const Color(0xFF1B5E20) : Colors.grey,
              fontWeight: FontWeight.bold, fontSize: 11,
            ),
          ),
        ),
      ]),
    );
  }
}
