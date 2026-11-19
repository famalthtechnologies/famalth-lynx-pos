const fs = require('fs');
const file = 'lib/screens/hrms/employee_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

// 1. Render office badge in employee card
const oldShift = `                        if (shiftStr.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE6F4F1),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(shiftStr,
                                style: const TextStyle(
                                    color: Color(0xFF0D9488),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                        ],`;

const newShift = `                        if (shiftStr.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE6F4F1),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(shiftStr,
                                style: const TextStyle(
                                    color: Color(0xFF0D9488),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (officeName.toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text('📍 \${officeName}',
                                style: const TextStyle(
                                    color: Color(0xFF15803D),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                        ],`;

if (!txt.includes("child: Text('📍 ${officeName}'")) {
  txt = txt.replace(oldShift, newShift);
  if (!txt.includes("child: Text('📍 ${officeName}'")) {
    txt = txt.replace(oldShift.replace(/\n/g, '\r\n'), newShift.replace(/\n/g, '\r\n'));
  }
}

// 2. Render Office dropdown and initial password in _buildWorkStep
const oldWork = `        _sectionLabel('Work Details'),
        _dateTile(
          label: 'Hire Date *',`;

const newWork = `        _sectionLabel('Work Details'),
        _dropdownField<int>(
          label: 'Office / Branch *',
          icon: Icons.location_city_rounded,
          value: _officeId,
          items: _offices.map((o) => DropdownMenuItem<int>(
            value: o['id'] as int?,
            child: Text('\${o['office_code']} • \${o['office_name']}'),
          )).toList(),
          onChanged: (v) => setState(() => _officeId = v),
        ),
        const SizedBox(height: 12),
        if (widget.employee == null) ...[
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Initial Login Password *',
              helperText: 'Temporary password sent to employee via welcome email',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _dateTile(
          label: 'Hire Date *',`;

if (!txt.includes("label: 'Office / Branch *',")) {
  txt = txt.replace(oldWork, newWork);
  if (!txt.includes("label: 'Office / Branch *',")) {
    txt = txt.replace(oldWork.replace(/\n/g, '\r\n'), newWork.replace(/\n/g, '\r\n'));
  }
}

fs.writeFileSync(file, txt, 'utf8');
console.log('Fixed UI in employee_screen.dart!');
