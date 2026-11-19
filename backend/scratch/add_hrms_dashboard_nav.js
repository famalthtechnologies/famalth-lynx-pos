const fs = require('fs');
const file = 'lib/screens/dashboard/main_dashboard_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

// 1. Add import
if (!txt.includes("import '../hrms/hrms_dashboard_screen.dart';")) {
  txt = txt.replace(
    "import '../hrms/employee_screen.dart';",
    "import '../hrms/hrms_dashboard_screen.dart';\nimport '../hrms/employee_screen.dart';"
  );
}

// 2. Add HRMS Dashboard to sidebar menu under HR & Payroll using regex
const sidebarEntry = `      // HR & Payroll
      {
        'category': 'HR & Payroll',
        'icon': Icons.dashboard_outlined,
        'label': 'HRMS Dashboard',
        'permission': 'HR_ATTENDANCE',
        'keywords': ['hrms dashboard', 'workforce analytics', 'staff attendance', 'overtime', 'geofence violations'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmsDashboardScreen())),
      },
`;

if (!txt.includes("'label': 'HRMS Dashboard',")) {
  txt = txt.replace(/(\/\/\s*HR\s*&\s*Payroll\s*[\r\n]+\s*\{\s*[\r\n]+\s*'category':\s*'HR & Payroll',\s*[\r\n]+\s*'icon':\s*Icons\.people_outline,\s*[\r\n]+\s*'label':\s*'Employee Management',)/, (match) => {
    return sidebarEntry + match;
  });
}

// 3. Add to command palette / search list
const searchEntry = `      // HR & Payroll
      {
        'category': 'HR & Payroll',
        'icon': Icons.dashboard_outlined,
        'label': 'HRMS & Workforce Dashboard',
        'subLabel': 'HR & Payroll ➜ live workforce attendance, late arrivals, geofence overview',
        'permission': 'HR_ATTENDANCE',
        'keywords': ['hrms dashboard', 'workforce analytics', 'staff attendance overview', 'overtime', 'geofence violations'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmsDashboardScreen())),
      },
`;

if (!txt.includes("'label': 'HRMS & Workforce Dashboard',")) {
  txt = txt.replace(/(\/\/\s*HR\s*&\s*Payroll\s*[\r\n]+\s*\{\s*[\r\n]+\s*'category':\s*'HR & Payroll',\s*[\r\n]+\s*'icon':\s*Icons\.people_outline,\s*[\r\n]+\s*'label':\s*'Staff & Employee Profiles',)/, (match) => {
    return searchEntry + match;
  });
}

fs.writeFileSync(file, txt, 'utf8');
console.log('Successfully patched main_dashboard_screen.dart! Has HRMS Dashboard:', txt.includes("'label': 'HRMS Dashboard',"));
