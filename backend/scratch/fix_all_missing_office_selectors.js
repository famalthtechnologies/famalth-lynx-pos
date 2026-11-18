const fs = require('fs');
const path = require('path');

// -------------------------------------------------------------
// 1. Fix hrms_masters_screen.dart
// -------------------------------------------------------------
const mastersFile = path.resolve('lib/screens/hrms/hrms_masters_screen.dart');
let mCode = fs.readFileSync(mastersFile, 'utf8');

// A. _addShift: insert _buildOfficeSelector inside Column
mCode = mCode.replace(
  /children: weekdayOptions\.map\(\(day\) \{[\s\S]*?\}\)\.toList\(\),\s*\),\s*\]\),\s*onSave: \(\) async \{/,
  `children: weekdayOptions.map((day) {
                  final isSelected = selectedOffs.contains(day);
                  return FilterChip(
                    label: Text(day, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : _navy)),
                    selected: isSelected,
                    selectedColor: _red,
                    backgroundColor: _grey50,
                    checkmarkColor: Colors.white,
                    onSelected: (val) {
                      setS(() {
                        if (val) {
                          selectedOffs.add(day);
                        } else {
                          selectedOffs.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              _buildOfficeSelector(
                selectedOfficeId: selectedOfficeId,
                onChanged: (v) => setS(() => selectedOfficeId = v),
              ),
            ]),
            onSave: () async {`
);

// B. _addLeaveType: insert _buildOfficeSelector inside Column
mCode = mCode.replace(
  /Switch\.adaptive\(\s*value: isPaid,\s*activeColor: _green,\s*onChanged: \(v\) => setS\(\(\) => isPaid = v\),\s*\),\s*\]\),\s*\]\),\s*onSave: \(\) async \{/,
  `Switch.adaptive(
                value: isPaid,
                activeColor: _green,
                onChanged: (v) => setS(() => isPaid = v),
              ),
            ]),
            _buildOfficeSelector(
              selectedOfficeId: selectedOfficeId,
              onChanged: (v) => setS(() => selectedOfficeId = v),
            ),
          ]),
          onSave: () async {`
);

// C. _addSalaryComponent: insert _buildOfficeSelector inside Column
mCode = mCode.replace(
  /child: Icon\(Icons\.info_outline, color: Colors\.blue, size: 18\),\s*\),\s*\) : null,\s*\),\s*\),\s*\]\s*,\s*\]\),\s*onSave: \(\) async \{/,
  `child: Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    ),
                  ) : null,
                ),
              ),
            ],
            _buildOfficeSelector(
              selectedOfficeId: selectedOfficeId,
              onChanged: (v) => setS(() => selectedOfficeId = v),
            ),
          ]),
          onSave: () async {`
);

// D. _editSalaryComponent: insert _buildOfficeSelector inside Column
mCode = mCode.replace(
  /child: Icon\(Icons\.info_outline, color: Colors\.blue, size: 18\),\s*\),\s*\) : null,\s*\),\s*\),\s*\]\s*,\s*\]\),\s*onSave: \(\) async \{\s*if \(nameCtrl\.text\.trim\(\)\.isEmpty\) return false;\s*await ApiClient\.put\('\$\{ApiEndpoints\.hrmsSalaryComponents\}\/\$\{c\['id'\]\}'/,
  `child: Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    ),
                  ) : null,
                ),
              ),
            ],
            _buildOfficeSelector(
              selectedOfficeId: selectedOfficeId,
              onChanged: (v) => setS(() => selectedOfficeId = v),
            ),
          ]),
          onSave: () async {
            if (nameCtrl.text.trim().isEmpty) return false;
            await ApiClient.put('\${ApiEndpoints.hrmsSalaryComponents}/\${c['id']}'`
);

// E. _addPayStructure: insert _buildOfficeSelector inside Column
mCode = mCode.replace(
  /TextField\(\s*controller: descCtrl,\s*style: const TextStyle\(fontSize: 13\),\s*decoration: _fieldDecor\(\s*'Description', 'Optional notes', Icons\.notes\),\s*\),\s*if \(_salaryComps\.isNotEmpty\)/,
  `TextField(
              controller: descCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor(
                  'Description', 'Optional notes', Icons.notes),
            ),
            _buildOfficeSelector(
              selectedOfficeId: selectedOfficeId,
              onChanged: (v) => setS(() => selectedOfficeId = v),
            ),
            if (_salaryComps.isNotEmpty)`
);

// F. Make _buildOfficeSelector styling even sharper and more prominent
mCode = mCode.replace(
  /Widget _buildOfficeSelector\(\{[\s\S]*?return Column\([\s\S]*?\}\);\s*\}\s*\n\s*\/\/ ═══ OFFICES & GEOFENCING/,
  `Widget _buildOfficeSelector({
    required String? selectedOfficeId,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_city_rounded, size: 15, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text(
                'COMPANY OFFICE / BRANCH APPLICABILITY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A5F),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedOfficeId,
                isExpanded: true,
                style: const TextStyle(fontSize: 12, color: _navy, fontWeight: FontWeight.w600),
                hint: const Text('🌐 All Offices (Company-wide)', style: TextStyle(fontSize: 12, color: _grey40)),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('🌐 All Offices & Branches (Company-wide)', style: TextStyle(fontSize: 12, color: _navy, fontWeight: FontWeight.w700)),
                  ),
                  ..._offices.map((o) => DropdownMenuItem<String?>(
                    value: o['id'].toString(),
                    child: Text('🏢 \${o['office_code']} - \${o['office_name']}', style: const TextStyle(fontSize: 12, color: _navy)),
                  )),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══ OFFICES & GEOFENCING`
);

fs.writeFileSync(mastersFile, mCode, 'utf8');
console.log('Fixed all 5 masters dialogs with prominent office selectors!');

// -------------------------------------------------------------
// 2. Fix payroll_screen.dart (Bulk Salary Revision & Bulk Bonus)
// -------------------------------------------------------------
const payrollFile = path.resolve('lib/screens/hrms/payroll_screen.dart');
let pCode = fs.readFileSync(payrollFile, 'utf8');

// Add selectedOfficeTargetId to _showBulkRevisionDialog
pCode = pCode.replace(
  /String target = 'All';\s*dynamic selectedGradeId;/,
  `String target = 'All';\n    dynamic selectedGradeId;\n    dynamic selectedOfficeTargetId;`
);

pCode = pCode.replace(
  /const Text\('Target Employees', style: TextStyle\(fontWeight: FontWeight\.bold, fontSize: 13, color: Color\(0xFF4B5563\)\)\),\s*Row\(\s*children: \[\s*Expanded\(\s*child: RadioListTile<String>\(\s*title: const Text\('All', style: TextStyle\(fontSize: 13\)\),\s*value: 'All',\s*groupValue: target,\s*activeColor: const Color\(0xFFE03E2D\),\s*contentPadding: EdgeInsets\.zero,\s*onChanged: \(v\) => setDs\(\(\) => target = v!\),\s*\),\s*\),\s*Expanded\(\s*child: RadioListTile<String>\(\s*title: const Text\('By Grade', style: TextStyle\(fontSize: 13\)\),\s*value: 'Designation',\s*groupValue: target,\s*activeColor: const Color\(0xFFE03E2D\),\s*contentPadding: EdgeInsets\.zero,\s*onChanged: \(v\) => setDs\(\(\) => target = v!\),\s*\),\s*\),\s*\],\s*\),/,
  `const Text('Target Employees', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
                Wrap(
                  spacing: 4,
                  children: [
                    SizedBox(
                      width: 90,
                      child: RadioListTile<String>(
                        title: const Text('All', style: TextStyle(fontSize: 12)),
                        value: 'All',
                        groupValue: target,
                        activeColor: const Color(0xFFE03E2D),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setDs(() {
                          target = v!;
                          selectedGradeId = null;
                          selectedOfficeTargetId = null;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: RadioListTile<String>(
                        title: const Text('By Office', style: TextStyle(fontSize: 12)),
                        value: 'Office',
                        groupValue: target,
                        activeColor: const Color(0xFFE03E2D),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setDs(() {
                          target = v!;
                          if (_offices.isNotEmpty) selectedOfficeTargetId = _offices[0]['id'];
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: RadioListTile<String>(
                        title: const Text('By Grade', style: TextStyle(fontSize: 12)),
                        value: 'Designation',
                        groupValue: target,
                        activeColor: const Color(0xFFE03E2D),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setDs(() {
                          target = v!;
                          if (payStructures.isNotEmpty) selectedGradeId = payStructures[0]['id'];
                        }),
                      ),
                    ),
                  ],
                ),
                if (target == 'Office') ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<dynamic>(
                    value: (_offices.any((o) => o['id'] == selectedOfficeTargetId)) ? selectedOfficeTargetId : null,
                    hint: const Text('Select Company Office / Branch'),
                    items: _offices
                        .map((o) => DropdownMenuItem<dynamic>(
                              value: o['id'],
                              child: Text('🏢 \${o['office_code']} - \${o['office_name']}'),
                            ))
                        .toList(),
                    onChanged: (v) => setDs(() => selectedOfficeTargetId = v),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],`
);

// Payload for bulk revision
pCode = pCode.replace(
  /'target': target == 'Designation' \? 'Designation' : 'All',\s*'target_id': target == 'Designation' \? selectedGradeId : null,/,
  `'target': target,
                        'target_id': target == 'Designation' ? selectedGradeId : (target == 'Office' ? selectedOfficeTargetId : null),
                        'office_id': target == 'Office' ? selectedOfficeTargetId : null,`
);

// Add selectedOfficeTargetId to _showBulkBonusDialog
pCode = pCode.replace(
  /String target = 'All';\s*dynamic selectedGradeId;\s*String? selectedMonth;/m,
  `String target = 'All';\n    dynamic selectedGradeId;\n    dynamic selectedOfficeTargetId;\n    String? selectedMonth;`
);

pCode = pCode.replace(
  /const Text\('Target Employees', style: TextStyle\(fontWeight: FontWeight\.bold, fontSize: 13, color: Color\(0xFF4B5563\)\)\),\s*Row\(\s*children: \[\s*Expanded\(\s*child: RadioListTile<String>\(\s*title: const Text\('All', style: TextStyle\(fontSize: 13\)\),\s*value: 'All',\s*groupValue: target,\s*activeColor: const Color\(0xFFE03E2D\),\s*contentPadding: EdgeInsets\.zero,\s*onChanged: \(v\) => setDs\(\(\) \{[\s\S]*?\}\),\s*\),\s*\),\s*Expanded\(\s*child: RadioListTile<String>\(\s*title: const Text\('By Grade', style: TextStyle\(fontSize: 13\)\),\s*value: 'Designation',\s*groupValue: target,\s*activeColor: const Color\(0xFFE03E2D\),\s*contentPadding: EdgeInsets\.zero,\s*onChanged: \(v\) => setDs\(\(\) \{[\s\S]*?\}\),\s*\),\s*\),\s*\],\s*\),/,
  `const Text('Target Employees', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
                  Wrap(
                    spacing: 4,
                    children: [
                      SizedBox(
                        width: 90,
                        child: RadioListTile<String>(
                          title: const Text('All', style: TextStyle(fontSize: 12)),
                          value: 'All',
                          groupValue: target,
                          activeColor: const Color(0xFFE03E2D),
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setDs(() {
                            target = v!;
                            selectedGradeId = null;
                            selectedOfficeTargetId = null;
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: RadioListTile<String>(
                          title: const Text('By Office', style: TextStyle(fontSize: 12)),
                          value: 'Office',
                          groupValue: target,
                          activeColor: const Color(0xFFE03E2D),
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setDs(() {
                            target = v!;
                            if (_offices.isNotEmpty) selectedOfficeTargetId = _offices[0]['id'];
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: RadioListTile<String>(
                          title: const Text('By Grade', style: TextStyle(fontSize: 12)),
                          value: 'Designation',
                          groupValue: target,
                          activeColor: const Color(0xFFE03E2D),
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setDs(() {
                            target = v!;
                            if (payStructures.isNotEmpty) selectedGradeId = payStructures[0]['id'];
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (target == 'Office') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<dynamic>(
                      value: (_offices.any((o) => o['id'] == selectedOfficeTargetId)) ? selectedOfficeTargetId : null,
                      hint: const Text('Select Company Office / Branch'),
                      items: _offices
                          .map((o) => DropdownMenuItem<dynamic>(
                                value: o['id'],
                                child: Text('🏢 \${o['office_code']} - \${o['office_name']}'),
                              ))
                          .toList(),
                      onChanged: (v) => setDs(() => selectedOfficeTargetId = v),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],`
);

// Payload for bulk bonus
pCode = pCode.replace(
  /'target': target == 'Designation' \? 'Designation' : 'All',\s*'target_id': target == 'Designation' \? selectedGradeId : null,/,
  `'target': target,
                          'target_id': target == 'Designation' ? selectedGradeId : (target == 'Office' ? selectedOfficeTargetId : null),
                          'office_id': target == 'Office' ? selectedOfficeTargetId : null,`
);

fs.writeFileSync(payrollFile, pCode, 'utf8');
console.log('Fixed Bulk Salary Revision & Bulk Bonus with Office target selection!');
