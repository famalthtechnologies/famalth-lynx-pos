import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/item_model.dart';

class MobileItemMasterSheet extends StatefulWidget {
  final List<Item> items;
  final VoidCallback onCatalogUpdated;

  const MobileItemMasterSheet({
    super.key,
    required this.items,
    required this.onCatalogUpdated,
  });

  @override
  State<MobileItemMasterSheet> createState() => _MobileItemMasterSheetState();
}

class _MobileItemMasterSheetState extends State<MobileItemMasterSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Item> _filteredItems = [];
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
    _extractCategories();
    _searchCtrl.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _extractCategories() {
    final cats = <String>{'All'};
    for (final it in widget.items) {
      if (it.itemGroup.trim().isNotEmpty) cats.add(it.itemGroup.trim());
      if (it.subCategory.trim().isNotEmpty) cats.add(it.subCategory.trim());
    }
    _categories = cats.toList();
  }

  void _filterItems() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredItems = widget.items.where((it) {
        final matchCat = _selectedCategory == 'All' ||
            it.itemGroup == _selectedCategory ||
            it.subCategory == _selectedCategory;
        if (!matchCat) return false;
        if (q.isEmpty) return true;
        return it.itemName.toLowerCase().contains(q) ||
            it.barcode.toLowerCase().contains(q) ||
            it.itemCode.toLowerCase().contains(q);
      }).toList();
    });
  }

  void _openEditPriceModal(Item item) {
    final priceCtrl = TextEditingController(text: item.retailSalePrice.toStringAsFixed(2));
    final mrpCtrl = TextEditingController(text: item.mrp.toStringAsFixed(2));
    final barcodeCtrl = TextEditingController(text: item.barcode);
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Edit: ${item.itemName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: textMuted),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Divider(color: borderSubtle),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    decoration: const InputDecoration(
                      labelText: 'Retail Sale Rate (₹)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mrpCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'MRP (₹)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: barcodeCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Barcode Number',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final newPrice = double.tryParse(priceCtrl.text.trim()) ?? item.retailSalePrice;
                              final newMrp = double.tryParse(mrpCtrl.text.trim()) ?? item.mrp;
                              final newBarcode = barcodeCtrl.text.trim();

                              setModalState(() => saving = true);
                              try {
                                final payload = item.toJson();
                                payload['retail_sale_price'] = newPrice;
                                payload['rate'] = newPrice;
                                payload['mrp'] = newMrp;
                                payload['barcode'] = newBarcode;

                                await ApiClient.put('${ApiEndpoints.items}/${item.id}', payload);
                                HapticFeedback.heavyImpact();
                                Navigator.pop(modalCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Updated "${item.itemName}" price to ₹${newPrice.toStringAsFixed(2)}'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                                widget.onCatalogUpdated();
                              } catch (e) {
                                setModalState(() => saving = false);
                                ScaffoldMessenger.of(modalCtx).showSnackBar(
                                  SnackBar(content: Text('Error updating price: $e'), backgroundColor: Colors.redAccent),
                                );
                              }
                            },
                      child: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Price Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddItemModal() {
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    final costRateCtrl = TextEditingController();
    final openingStockCtrl = TextEditingController(text: '0');
    final hsnCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final groupCtrl = TextEditingController(text: 'General');
    final minLevelCtrl = TextEditingController(text: '0');
    String unit = 'Nos';
    String foodType = 'VEG'; // VEG, NON_VEG, EGG, OTHER
    bool isTaxInclusive = false;
    double taxPct = 5.0;
    bool saving = false;

    final unitOptions = ['Nos', 'PCS', 'KG', 'GM', 'LTR', 'ML', 'Box', 'Packet', 'Dozen', 'Meter'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Add New Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      IconButton(
                        icon: const Icon(Icons.close, color: textMuted),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Divider(color: borderSubtle),
                  const SizedBox(height: 8),

                  // Product Name
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Barcode & Brand
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: barcodeCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Barcode (Optional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: brandCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Brand',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Sale Rate & MRP
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                          decoration: const InputDecoration(
                            labelText: 'Sale Rate (₹) *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: mrpCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'MRP (₹)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Purchase Cost & Opening Stock
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costRateCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Purchase / Cost Rate (₹)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: openingStockCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Opening Stock (Qty)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Unit & HSN Code
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: unit,
                          style: const TextStyle(color: textDark, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => unit = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: hsnCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'HSN / SAC Code',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Category & Min Reorder Level
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: groupCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Category / Group',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: minLevelCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Min Reorder Qty',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dietary Tag (Veg, Non-Veg, Egg, Other)
                  const Text('Dietary Tag', style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        {'key': 'VEG', 'label': 'Veg', 'color': Color(0xFF16A34A)},
                        {'key': 'NON_VEG', 'label': 'Non-Veg', 'color': Color(0xFFDC2626)},
                        {'key': 'EGG', 'label': 'Egg', 'color': Color(0xFFD97706)},
                        {'key': 'OTHER', 'label': 'Other', 'color': Color(0xFF64748B)},
                      ].map((item) {
                        final isSel = foodType == item['key'];
                        final c = item['color'] as Color;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: isSel ? Colors.white : c),
                                ),
                                const SizedBox(width: 4),
                                Text(item['label'] as String, style: TextStyle(color: isSel ? Colors.white : textDark, fontSize: 11)),
                              ],
                            ),
                            selected: isSel,
                            selectedColor: c,
                            backgroundColor: Colors.white,
                            side: BorderSide(color: isSel ? c : borderSubtle),
                            onSelected: (val) {
                              if (val) setModalState(() => foodType = item['key'] as String);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // GST Tax % chips
                  const Text('GST Tax %', style: TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [0.0, 5.0, 12.0, 18.0, 28.0].map((t) {
                      final isSel = taxPct == t;
                      return ChoiceChip(
                        label: Text('${t.toInt()}%', style: TextStyle(color: isSel ? Colors.white : textDark, fontSize: 11)),
                        selected: isSel,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderSubtle),
                        onSelected: (val) {
                          if (val) setModalState(() => taxPct = t);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Tax Inclusive / Exclusive toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tax Included in Price', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            Text('MRP / Rate already includes GST', style: TextStyle(color: textMuted, fontSize: 11)),
                          ],
                        ),
                        Switch(
                          value: isTaxInclusive,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (val) => setModalState(() => isTaxInclusive = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                              final mrp = double.tryParse(mrpCtrl.text.trim()) ?? price;
                              final cost = double.tryParse(costRateCtrl.text.trim()) ?? price;
                              final openingStock = double.tryParse(openingStockCtrl.text.trim()) ?? 0.0;
                              final minLevel = int.tryParse(minLevelCtrl.text.trim()) ?? 0;

                              if (name.isEmpty || price <= 0) {
                                ScaffoldMessenger.of(modalCtx).showSnackBar(
                                  const SnackBar(content: Text('Product name and sale rate are required')),
                                );
                                return;
                              }
                              setModalState(() => saving = true);
                              try {
                                final barcode = barcodeCtrl.text.trim();
                                String code = '';
                                try {
                                  final codeRes = await ApiClient.get('/api/inventory/items/next-code');
                                  if (codeRes['data'] != null && codeRes['data'].toString().trim().isNotEmpty) {
                                    code = codeRes['data'].toString().trim();
                                  }
                                } catch (_) {}
                                if (code.isEmpty) {
                                  code = barcode.isNotEmpty ? barcode : 'ITM-${DateTime.now().millisecondsSinceEpoch % 1000000}';
                                }

                                final itemModel = Item(
                                  id: 0,
                                  itemCode: code,
                                  itemName: name,
                                  barcode: barcode,
                                  retailSalePrice: price,
                                  rate: cost,
                                  mrp: mrp,
                                  unit: unit,
                                  itemGroup: groupCtrl.text.trim().isNotEmpty ? groupCtrl.text.trim() : 'General',
                                  subCategory: '',
                                  brand: brandCtrl.text.trim(),
                                  hsnSacCode: hsnCtrl.text.trim(),
                                  openingBalance: openingStock,
                                  packQty: 0,
                                  looseItemCode: '',
                                  minLevel: minLevel,
                                  maxLevel: 1000,
                                  discountApplicable: true,
                                  schemeApplicable: true,
                                  stockable: true,
                                  isSaleable: true,
                                  isModifier: false,
                                  foodType: foodType,
                                  isTaxInclusive: isTaxInclusive,
                                  taxPercent: taxPct,
                                  taxType: 'GST',
                                  isActive: true,
                                );
                                final payload = itemModel.toJson();
                                payload['item_code'] = code;

                                await ApiClient.post(ApiEndpoints.items, payload);
                                HapticFeedback.heavyImpact();
                                Navigator.pop(modalCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Product "$name" (Code: $code) added to catalog successfully!'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                                widget.onCatalogUpdated();
                              } catch (e) {
                                setModalState(() => saving = false);
                                final err = e.toString().replaceAll('Exception: ', '');
                                ScaffoldMessenger.of(modalCtx).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to add product: $err'),
                                    backgroundColor: Colors.redAccent,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            },
                      child: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add Product to Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, color: Color(0xFF2563EB), size: 24),
                    SizedBox(width: 10),
                    Text('Item Master & Pricing', style: TextStyle(color: textDark, fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _openAddItemModal,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close, color: textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search items by name, barcode or code...',
                hintStyle: const TextStyle(color: textMuted, fontSize: 12.5),
                prefixIcon: const Icon(Icons.search, color: textMuted, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => _searchCtrl.clear())
                    : null,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderSubtle)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderSubtle)),
              ),
            ),
          ),

          // Category Chips
          SizedBox(
            height: 34,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                final isSel = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat, style: TextStyle(color: isSel ? Colors.white : textDark, fontSize: 11)),
                  selected: isSel,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: isSel ? const Color(0xFF2563EB) : borderSubtle),
                  onSelected: (val) {
                    setState(() {
                      _selectedCategory = cat;
                      _filterItems();
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Items List
          Expanded(
            child: _filteredItems.isEmpty
                ? const Center(child: Text('No matching items found', style: TextStyle(color: textMuted)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final it = _filteredItems[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        'Rate: ₹${it.retailSalePrice.toStringAsFixed(2)}',
                                        style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      if (it.mrp > it.retailSalePrice) ...[
                                        const SizedBox(width: 6),
                                        Text('MRP: ₹${it.mrp.toStringAsFixed(0)}',
                                            style: const TextStyle(color: textMuted, fontSize: 11, decoration: TextDecoration.lineThrough)),
                                      ],
                                      const SizedBox(width: 8),
                                      Text('${it.taxPercent.toStringAsFixed(0)}% Tax',
                                          style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10.5, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${it.stockable ? 'Stock: ${it.openingBalance.toInt()}' : 'Non-stock'} • Code: ${it.itemCode} ${it.barcode.isNotEmpty ? '• Barcode: ${it.barcode}' : ''}',
                                    style: const TextStyle(color: textMuted, fontSize: 10.5),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () => _openEditPriceModal(it),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
