const fs = require('fs');
const path = require('path');

const modelsDir = path.resolve(__dirname, '../models/property');
console.log('modelsDir:', modelsDir);

function patchFile(fileName) {
  for (const ext of ['.ts', '.js']) {
    const filePath = path.join(modelsDir, fileName + '.model' + ext);
    if (!fs.existsSync(filePath)) {
      console.log('Not found:', filePath);
      continue;
    }
    let content = fs.readFileSync(filePath, 'utf8');

    // Add field if not present
    if (!content.includes('office_id:')) {
      content = content.replace(/(outlet_id:\s*\{[^}]+\},)/, '$1\n        office_id: { type: DataTypes.INTEGER, allowNull: true },');
    }

    // Add association if not present
    if (!content.includes("as: 'office'")) {
      content = content.replace(/(Hr[A-Za-z]+\.belongsTo\(models\.outlets[^\n]+\n)/, `$1        if (models.hr_offices) {\n            $1`.replace(/models\.outlets/g, 'models.hr_offices').replace(/outlet_id/g, 'office_id').replace(/'outlet'/g, "'office'") + '        }\n');
    }

    fs.writeFileSync(filePath, content, 'utf8');
    console.log(`Patched ${fileName}${ext}`);
  }
}

patchFile('hrDesignation');
patchFile('hrShift');
patchFile('hrLeaveType');
patchFile('hrSalaryComponent');
patchFile('hrPayStructure');
patchFile('hrPayrollRun');
