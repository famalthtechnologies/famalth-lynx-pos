const fs = require('fs');
const path = 'lib/screens/hrms/hrms_masters_screen.dart';
let content = fs.readFileSync(path, 'utf8');

// 1. Add geolocator import
if (!content.includes('package:geolocator/geolocator.dart')) {
  content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:geolocator/geolocator.dart';");
}

// 2. Add _offices list
if (!content.includes('List<Map<String, dynamic>> _offices')) {
  content = content.replace("List<Map<String, dynamic>> _payStructures = [];", "List<Map<String, dynamic>> _payStructures = [];\n  List<Map<String, dynamic>> _offices       = [];");
}

// 3. In _loadAll, fetch ApiEndpoints.hrmsOffices
if (!content.includes('ApiClient.get(ApiEndpoints.hrmsOffices)')) {
  content = content.replace(
`        ApiClient.get(ApiEndpoints.hrmsSalaryComponents),
        ApiClient.get(ApiEndpoints.hrmsPayStructures),
      ]);`,
`        ApiClient.get(ApiEndpoints.hrmsSalaryComponents),
        ApiClient.get(ApiEndpoints.hrmsPayStructures),
        ApiClient.get(ApiEndpoints.hrmsOffices),
      ]);`
  );

  content = content.replace(
`        _salaryComps   = _parseList(results[3]);
        _payStructures = _parseList(results[4]);
        _loading = false;`,
`        _salaryComps   = _parseList(results[3]);
        _payStructures = _parseList(results[4]);
        _offices       = _parseList(results[5]);
        _loading = false;`
  );
}

// 4. In build(), add _buildOffices()
if (!content.includes('_buildOffices(),')) {
  content = content.replace(
`                    children: [
                      _buildDesignations(),`,
`                    children: [
                      _buildOffices(),
                      _buildDesignations(),`
  );
}

// 5. Add _buildOffices, _officeTile, and _showOfficeDialog before // ═══ DESIGNATIONS ════════════════════════════════════
const officeCode = `  // ═══ OFFICES & GEOFENCING ═══════════════════════════════
  Widget _buildOffices() {
    return _sectionCard(
      title: 'Offices & Geofenced Locations',
      icon: Icons.location_city_rounded,
      iconColor: const Color(0xFF0D9488),
      iconBg: const Color(0xFFCCFBF1),
      onAdd: () => _showOfficeDialog(),
      body: _offices.isEmpty
          ? _emptyRow('No offices configured yet. Tap Add →')
          : Column(
              children: _offices.asMap().entries.map((e) => Column(children: [
                _officeTile(e.value),
                if (e.key < _offices.length - 1) _rowDivider(),
              ])).toList(),
            ),
    );
  }

  Widget _officeTile(Map<String, dynamic> o) {
    final code = (o['office_code'] ?? '').toString();
    final name = (o['office_name'] ?? '').toString();
    final address = [
      o['address'],
      o['city'],
      o['state'],
      o['pincode'],
    ].where((part) => part != null && part.toString().trim().isNotEmpty).join(', ');
    final lat = o['latitude']?.toString() ?? '—';
    final lng = o['longitude']?.toString() ?? '—';
    final radius = o['geofence_radius_meters']?.toString() ?? '100';
    final active = o['is_active'] != false;
    final staffCount = o['employee_count'] ?? o['staff_count'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.business_rounded, color: Color(0xFF0D9488), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      code.isNotEmpty ? '$code • $name' : name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy),
                    ),
                    const SizedBox(width: 8),
                    _badge(active ? 'Active' : 'Inactive',
                        active ? const Color(0xFFECFDF5) : _grey10,
                        active ? _green : _grey40),
                  ],
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    address,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '📍 Lat: $lat, Lng: $lng',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '📏 Radius: \${radius}m',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                    if (staffCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          border: Border.all(color: const Color(0xFFE9D5FF)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '👥 $staffCount Staff',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: _blue),
            tooltip: 'Edit Office',
            onPressed: () => _showOfficeDialog(o),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: _red),
            tooltip: 'Delete Office',
            onPressed: () => _deleteMaster(ApiEndpoints.hrmsOffices, o['id'] as int, 'Office'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Future<void> _showOfficeDialog([Map<String, dynamic>? office]) async {
    final isEdit = office != null;
    final codeCtrl = TextEditingController(text: office?['office_code']?.toString() ?? '');
    final nameCtrl = TextEditingController(text: office?['office_name']?.toString() ?? '');
    final addrCtrl = TextEditingController(text: office?['address']?.toString() ?? '');
    final cityCtrl = TextEditingController(text: office?['city']?.toString() ?? 'Dehradun');
    final stateCtrl = TextEditingController(text: office?['state']?.toString() ?? 'Uttarakhand');
    final pinCtrl = TextEditingController(text: office?['pincode']?.toString() ?? '');
    final latCtrl = TextEditingController(text: office?['latitude']?.toString() ?? '30.316495');
    final lngCtrl = TextEditingController(text: office?['longitude']?.toString() ?? '78.032192');
    final radCtrl = TextEditingController(text: office?['geofence_radius_meters']?.toString() ?? '100');
    bool isActive = office?['is_active'] != false;
    bool isFetchingGps = false;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_city_rounded, color: Color(0xFF0D9488), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Edit Office / Branch' : 'Add Office / Branch',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _fieldDecor('Office Code *', 'e.g. HO-01', Icons.tag),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: _fieldDecor('Office Name *', 'e.g. Head Office', Icons.business),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addrCtrl,
                    decoration: _fieldDecor('Street Address', 'e.g. Rajpur Road', Icons.home_work_outlined),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cityCtrl,
                          decoration: _fieldDecor('City', 'City', Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: stateCtrl,
                          decoration: _fieldDecor('State', 'State', Icons.map_outlined),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: pinCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecor('PIN Code', 'PIN', Icons.pin_drop_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xFF15803D)),
                                SizedBox(width: 6),
                                Text(
                                  'GPS Geotagging & Geofence',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF15803D),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: isFetchingGps
                                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.my_location_rounded, size: 14),
                              label: const Text('Detect Current GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: isFetchingGps
                                  ? null
                                  : () async {
                                      setDlgState(() => isFetchingGps = true);
                                      try {
                                        LocationPermission perm = await Geolocator.checkPermission();
                                        if (perm == LocationPermission.denied) {
                                          perm = await Geolocator.requestPermission();
                                        }
                                        final pos = await Geolocator.getCurrentPosition(
                                          desiredAccuracy: LocationAccuracy.high,
                                          timeLimit: const Duration(seconds: 10),
                                        );
                                        latCtrl.text = pos.latitude.toString();
                                        lngCtrl.text = pos.longitude.toString();
                                      } catch (err) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Could not get GPS: $err'), backgroundColor: _red),
                                          );
                                        }
                                      } finally {
                                        setDlgState(() => isFetchingGps = false);
                                      }
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: latCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _fieldDecor('Latitude *', 'e.g. 30.316495', Icons.explore_outlined),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: lngCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _fieldDecor('Longitude *', 'e.g. 78.032192', Icons.explore_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: radCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecor('Geofence Radius (meters) *', 'e.g. 100 (allowed distance for punch)', Icons.radar_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Office is Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: isActive,
                    activeColor: _green,
                    onChanged: (v) => setDlgState(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              onPressed: () async {
                final code = codeCtrl.text.trim();
                final name = nameCtrl.text.trim();
                final lat = double.tryParse(latCtrl.text.trim());
                final lng = double.tryParse(lngCtrl.text.trim());
                final rad = int.tryParse(radCtrl.text.trim()) ?? 100;

                if (code.isEmpty || name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Office code and name are required'), backgroundColor: _red),
                  );
                  return;
                }
                if (lat == null || lng == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Valid GPS latitude and longitude are required'), backgroundColor: _red),
                  );
                  return;
                }

                final payload = {
                  'office_code': code,
                  'office_name': name,
                  'address': addrCtrl.text.trim(),
                  'city': cityCtrl.text.trim(),
                  'state': stateCtrl.text.trim(),
                  'pincode': pinCtrl.text.trim(),
                  'latitude': lat,
                  'longitude': lng,
                  'geofence_radius_meters': rad,
                  'is_active': isActive,
                };

                try {
                  if (isEdit) {
                    await ApiClient.put('\${ApiEndpoints.hrmsOffices}/\${office['id']}', payload);
                  } else {
                    await ApiClient.post(ApiEndpoints.hrmsOffices, payload);
                  }
                  Navigator.pop(dlgCtx);
                  _loadAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Office \${isEdit ? "updated" : "created"} successfully'), backgroundColor: _green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: _red),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Save Changes' : 'Create Office'),
            ),
          ],
        ),
      ),
    );
  }

`;

if (!content.includes('// ═══ OFFICES & GEOFENCING')) {
  content = content.replace('  // ═══ DESIGNATIONS ════════════════════════════════════', officeCode + '  // ═══ DESIGNATIONS ════════════════════════════════════');
}

fs.writeFileSync(path, content, 'utf8');
console.log('Successfully patched hrms_masters_screen.dart!');
