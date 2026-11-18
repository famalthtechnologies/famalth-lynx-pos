const fs = require('fs');
const file = 'lib/screens/mobile_billing/mobile_billing_app_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

const target = `            // Quick HRMS Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, size: 18),
                    label: const Text('Mark Staff Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                      ).then((_) => _loadHrmsData());
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E293B),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFF4F46E5)),
                  label: const Text('+ Add Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmployeeScreen()),
                    ).then((_) => _loadHrmsData());
                  },
                ),
              ],
            ),`;

const replacement = `            // Quick HRMS Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.person_pin_circle_rounded, size: 18),
                    label: const Text('Employee App (GPS Punch)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmployeePortalScreen()),
                      ).then((_) => _loadHrmsData());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFC7D2FE)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, size: 18),
                    label: const Text('Admin Attendance Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                      ).then((_) => _loadHrmsData());
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E293B),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFF4F46E5)),
                  label: const Text('+ Add Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmployeeScreen()),
                    ).then((_) => _loadHrmsData());
                  },
                ),
              ],
            ),`;

if (txt.includes(target)) {
  txt = txt.replace(target, replacement);
} else {
  txt = txt.replace(target.replace(/\n/g, '\r\n'), replacement.replace(/\n/g, '\r\n'));
}

fs.writeFileSync(file, txt, 'utf8');
console.log('Fixed HRMS Action Buttons! Has EmployeePortalScreen:', txt.includes('EmployeePortalScreen'));
