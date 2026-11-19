const fs = require('fs');
const path = require('path');

const file = path.resolve('lib/screens/hrms/hrms_masters_screen.dart');
let code = fs.readFileSync(file, 'utf8');

// 1. In _editSalaryComponent, declare selectedOfficeId and add selector + payload
code = code.replace(
  /bool\s*isTaxable = c\['is_taxable'\] != false;/,
  `bool isTaxable = c['is_taxable'] != false;\n    String? selectedOfficeId = c['office_id']?.toString();`
);
code = code.replace(
  /'is_active': c\['is_active'\] != false,\s*\}\);/,
  `'is_active': c['is_active'] != false,\n              'office_id': selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null,\n            });`
);
code = code.replace(
  /if \(type != 'Fixed'\) \.\.\.\[[\s\S]*?\],\s*\]\),\s*onSave: \(\) async \{/m,
  (match) => {
    return match.replace(
      '          ]),\n          onSave: () async {',
      '            _buildOfficeSelector(\n              selectedOfficeId: selectedOfficeId,\n              onChanged: (v) => setS(() => selectedOfficeId = v),\n            ),\n          ]),\n          onSave: () async {'
    );
  }
);

// 2. In _addSalaryComponent, add selector + payload
code = code.replace(
  /'frequency' : 'Monthly',\s*\}\);/,
  `'frequency' : 'Monthly',\n              'office_id': selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null,\n            });`
);
code = code.replace(
  /Icons\.functions\)\.copyWith\([\s\S]*?\),\s*\]\),\s*onSave: \(\) async \{/m,
  (match) => {
    return match.replace(
      '          ]),\n          onSave: () async {',
      '            _buildOfficeSelector(\n              selectedOfficeId: selectedOfficeId,\n              onChanged: (v) => setS(() => selectedOfficeId = v),\n            ),\n          ]),\n          onSave: () async {'
    );
  }
);

// 3. In _editPayStructure, declare selectedOfficeId
code = code.replace(
  /final Set<int> selectedIds = pComps\.map\(\(c\) => \(c\['id'\] as num\)\.toInt\(\)\)\.toSet\(\);/,
  `final Set<int> selectedIds = pComps.map((c) => (c['id'] as num).toInt()).toSet();\n    String? selectedOfficeId = p['office_id']?.toString();`
);

// 4. In _addShift, add selector and payload
code = code.replace(
  /'weekly_offs'      : selectedOffs,\s*\}\);/,
  `'weekly_offs'      : selectedOffs,\n                'office_id': selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null,\n              });`
);
code = code.replace(
  /Wrap\([\s\S]*?\}\)\.toList\(\),\s*\),\s*\]\),\s*onSave: \(\) async \{/m,
  (match) => {
    return match.replace(
      '            ]),\n            onSave: () async {',
      '              _buildOfficeSelector(\n                selectedOfficeId: selectedOfficeId,\n                onChanged: (v) => setS(() => selectedOfficeId = v),\n              ),\n            ]),\n            onSave: () async {'
    );
  }
);

// 5. In ListView in build(), ensure _buildOfficeFilterBar() is present
if (!code.includes('_buildOfficeFilterBar(),')) {
  code = code.replace('_buildOffices(),', '_buildOfficeFilterBar(),\n                      _buildOffices(),');
}

fs.writeFileSync(file, code, 'utf8');
console.log('Fixed undefined variables and linked office filter in hrms_masters_screen.dart');
