const fs = require('fs');
const file = 'lib/screens/hrms/employee_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

if (!txt.includes('int? _officeId;')) {
  txt = txt.replace('  int? _designationId;', '  List<Map<String, dynamic>> _offices = [];\n  int? _officeId;\n  final _passwordCtrl = TextEditingController(text: \'123456\');\n  bool _obscurePassword = true;\n  int? _designationId;');
}

fs.writeFileSync(file, txt, 'utf8');
console.log('Fixed _officeId field in _AddEmployeeFormState: contains int? _officeId;', txt.includes('int? _officeId;'));
