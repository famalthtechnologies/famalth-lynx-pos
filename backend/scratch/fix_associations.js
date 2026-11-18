const fs = require('fs');
const path = require('path');

const modelsDir = path.resolve(__dirname, '../models/property');
const models = ['hrDesignation', 'hrShift', 'hrLeaveType', 'hrSalaryComponent', 'hrPayStructure', 'hrPayrollRun'];

for (const model of models) {
  for (const ext of ['.model.ts', '.model.js']) {
    const filePath = path.join(modelsDir, model + ext);
    if (!fs.existsSync(filePath)) continue;
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Fix association
    content = content.replace(/if\s*\(models\.hr_offices\)\s*\{\s*([A-Za-z]+)\.belongsTo\([^;]+;\s*\}/g, 
      "if (models.hr_offices) {\n            $1.belongsTo(models.hr_offices, { foreignKey: 'office_id', as: 'office' });\n        }");

    fs.writeFileSync(filePath, content, 'utf8');
    console.log('Fixed association in:', model + ext);
  }
}
