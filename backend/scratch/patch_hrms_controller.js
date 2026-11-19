const fs = require('fs');
const path = require('path');

const tsFile = path.resolve(__dirname, '../controllers/hrms/hrms.controller.ts');
const jsFile = path.resolve(__dirname, '../controllers/hrms/hrms.controller.js');

function patchController(filePath) {
  if (!fs.existsSync(filePath)) return;
  let code = fs.readFileSync(filePath, 'utf8');

  // 1. getSalaryComponents
  code = code.replace(
    /exports\.getSalaryComponents\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?const data = await hr_salary_components\.findAll\(\{[^}]*\}\);/,
    `exports.getSalaryComponents = async (req, res) => {
  try {
    const { hr_salary_components, hr_offices } = req.propertyDb.models;
    const { office_id } = req.query;
    const where = { outlet_id: req.user.outlet_id };
    if (office_id && office_id !== 'all' && office_id !== '0') {
      where[Op.or] = [{ office_id: office_id }, { office_id: null }];
    }
    const data = await hr_salary_components.findAll({
      where,
      include: hr_offices ? [{ model: hr_offices, as: 'office', attributes: ['id', 'office_code', 'office_name'] }] : [],
      order: [['id', 'ASC']]
    });`
  );

  // 2. createSalaryComponent
  code = code.replace(
    /exports\.createSalaryComponent\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?const data = await hr_salary_components\.create\(\{([\s\S]*?)\}\);/,
    `exports.createSalaryComponent = async (req, res) => {
  try {
    const { hr_salary_components } = req.propertyDb.models;
    const office_id = req.body.office_id && req.body.office_id !== 'all' && req.body.office_id !== '0' ? parseInt(req.body.office_id) : null;
    const data = await hr_salary_components.create({
      ...req.body,
      office_id,
      outlet_id: req.user.outlet_id,
      created_by: req.user.id
    });`
  );

  // 3. getPayStructures
  code = code.replace(
    /exports\.getPayStructures\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?const data = await hr_pay_structures\.findAll\(\{[\s\S]*?\}\);/,
    `exports.getPayStructures = async (req, res) => {
  try {
    const { hr_pay_structures, hr_salary_components, hr_offices } = req.propertyDb.models;
    const { office_id } = req.query;
    const where = { outlet_id: req.user.outlet_id };
    if (office_id && office_id !== 'all' && office_id !== '0') {
      where[Op.or] = [{ office_id: office_id }, { office_id: null }];
    }
    const data = await hr_pay_structures.findAll({
      where,
      include: [
        {
          model: hr_salary_components,
          as: 'components',
          through: { attributes: [] }
        },
        ...(hr_offices ? [{ model: hr_offices, as: 'office', attributes: ['id', 'office_code', 'office_name'] }] : [])
      ],
      order: [['id', 'ASC']]
    });`
  );

  // 4. createPayStructure
  code = code.replace(
    /exports\.createPayStructure\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?const structure = await hr_pay_structures\.create\(\{[\s\S]*?\}\);/,
    `exports.createPayStructure = async (req, res) => {
  try {
    const { hr_pay_structures, hr_pay_structure_components } = req.propertyDb.models;
    const { name, description, is_active, componentIds, office_id } = req.body;
    const structure = await hr_pay_structures.create({
      name,
      description: description || null,
      is_active: is_active !== false,
      office_id: office_id && office_id !== 'all' && office_id !== '0' ? parseInt(office_id) : null,
      outlet_id: req.user.outlet_id
    });`
  );

  // 5. getLeaveTypes
  code = code.replace(
    /exports\.getLeaveTypes\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?const data = await hr_leave_types\.findAll\(\{[^}]*\}\);/,
    `exports.getLeaveTypes = async (req, res) => {
  try {
    const { hr_leave_types, hr_offices } = req.propertyDb.models;
    const { office_id } = req.query;
    const where = { outlet_id: req.user.outlet_id };
    if (office_id && office_id !== 'all' && office_id !== '0') {
      where[Op.or] = [{ office_id: office_id }, { office_id: null }];
    }
    const data = await hr_leave_types.findAll({
      where,
      include: hr_offices ? [{ model: hr_offices, as: 'office', attributes: ['id', 'office_code', 'office_name'] }] : [],
      order: [['id', 'ASC']]
    });`
  );

  // 6. createLeaveType
  code = code.replace(
    /exports\.createLeaveType\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?const data = await hr_leave_types\.create\(\{([\s\S]*?)\}\);/,
    `exports.createLeaveType = async (req, res) => {
  try {
    const { hr_leave_types } = req.propertyDb.models;
    const office_id = req.body.office_id && req.body.office_id !== 'all' && req.body.office_id !== '0' ? parseInt(req.body.office_id) : null;
    const data = await hr_leave_types.create({
      ...req.body,
      office_id,
      outlet_id: req.user.outlet_id,
      created_by: req.user.id
    });`
  );

  // 7. getShifts
  code = code.replace(
    /exports\.getShifts\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?const data = await hr_shifts\.findAll\(\{[^}]*\}\);/,
    `exports.getShifts = async (req, res) => {
  try {
    const { hr_shifts, hr_offices } = req.propertyDb.models;
    const { office_id } = req.query;
    const where = { outlet_id: req.user.outlet_id };
    if (office_id && office_id !== 'all' && office_id !== '0') {
      where[Op.or] = [{ office_id: office_id }, { office_id: null }];
    }
    const data = await hr_shifts.findAll({
      where,
      include: hr_offices ? [{ model: hr_offices, as: 'office', attributes: ['id', 'office_code', 'office_name'] }] : [],
      order: [['id', 'ASC']]
    });`
  );

  // 8. createShift
  code = code.replace(
    /exports\.createShift\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?const data = await hr_shifts\.create\(\{([\s\S]*?)\}\);/,
    `exports.createShift = async (req, res) => {
  try {
    const { hr_shifts } = req.propertyDb.models;
    const office_id = req.body.office_id && req.body.office_id !== 'all' && req.body.office_id !== '0' ? parseInt(req.body.office_id) : null;
    const data = await hr_shifts.create({
      name: req.body.name,
      start_time: req.body.start_time,
      end_time: req.body.end_time,
      grace_period_mins: req.body.grace_period_mins ?? 15,
      weekly_offs: req.body.weekly_offs ?? ["Sunday"],
      office_id,
      outlet_id: req.user.outlet_id
    });`
  );

  // 9. getDesignations
  code = code.replace(
    /exports\.getDesignations\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?const data = await hr_designations\.findAll\(\{[^}]*\}\);/,
    `exports.getDesignations = async (req, res) => {
  try {
    const { hr_designations, hr_offices } = req.propertyDb.models;
    const { office_id } = req.query;
    const where = { outlet_id: req.user.outlet_id };
    if (office_id && office_id !== 'all' && office_id !== '0') {
      where[Op.or] = [{ office_id: office_id }, { office_id: null }];
    }
    const data = await hr_designations.findAll({
      where,
      include: hr_offices ? [{ model: hr_offices, as: 'office', attributes: ['id', 'office_code', 'office_name'] }] : [],
      order: [['id', 'ASC']]
    });`
  );

  // 10. createDesignation
  code = code.replace(
    /exports\.createDesignation\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?const data = await hr_designations\.create\(\{([\s\S]*?)\}\);/,
    `exports.createDesignation = async (req, res) => {
  try {
    const { hr_designations } = req.propertyDb.models;
    const office_id = req.body.office_id && req.body.office_id !== 'all' && req.body.office_id !== '0' ? parseInt(req.body.office_id) : null;
    const data = await hr_designations.create({
      name: req.body.name,
      office_id,
      outlet_id: req.user.outlet_id
    });`
  );

  // 11. updateDesignation
  code = code.replace(
    /exports\.updateDesignation\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?await item\.update\(\{ name, is_active: is_active !== false \}\);/,
    `exports.updateDesignation = async (req, res) => {
  try {
    const { hr_designations } = req.propertyDb.models;
    const { id } = req.params;
    const { name, is_active } = req.body;
    const item = await hr_designations.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Designation not found' });
    const payload = { name, is_active: is_active !== false };
    if ('office_id' in req.body) {
      payload.office_id = req.body.office_id && req.body.office_id !== 'all' && req.body.office_id !== '0' ? parseInt(req.body.office_id) : null;
    }
    await item.update(payload);`
  );

  // 12. updateShift
  code = code.replace(
    /exports\.updateShift\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?await item\.update\(\{ name, start_time, end_time, grace_period_mins, weekly_offs, is_active: is_active !== false \}\);/,
    `exports.updateShift = async (req, res) => {
  try {
    const { hr_shifts } = req.propertyDb.models;
    const { id } = req.params;
    const { name, start_time, end_time, grace_period_mins, weekly_offs, is_active } = req.body;
    const item = await hr_shifts.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Shift not found' });
    const payload = { name, start_time, end_time, grace_period_mins, weekly_offs, is_active: is_active !== false };
    if ('office_id' in req.body) {
      payload.office_id = req.body.office_id && req.body.office_id !== 'all' && req.body.office_id !== '0' ? parseInt(req.body.office_id) : null;
    }
    await item.update(payload);`
  );

  // 13. updateLeaveType
  code = code.replace(
    /exports\.updateLeaveType\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?await item\.update\(\{ name, annual_quota, is_paid, is_active: is_active !== false \}\);/,
    `exports.updateLeaveType = async (req, res) => {
  try {
    const { hr_leave_types } = req.propertyDb.models;
    const { id } = req.params;
    const { name, annual_quota, is_paid, is_active } = req.body;
    const item = await hr_leave_types.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Leave type not found' });
    const payload = { name, annual_quota, is_paid, is_active: is_active !== false };
    if ('office_id' in req.body) {
      payload.office_id = req.body.office_id && req.body.office_id !== 'all' && req.body.office_id !== '0' ? parseInt(req.body.office_id) : null;
    }
    await item.update(payload);`
  );

  // 14. updatePayStructure
  code = code.replace(
    /await item\.update\(\{ name, description: description \|\| null, is_active: is_active !== false \}\);/,
    `const updatePayload = { name, description: description || null, is_active: is_active !== false };
    if ('office_id' in req.body) {
      updatePayload.office_id = req.body.office_id && req.body.office_id !== 'all' && req.body.office_id !== '0' ? parseInt(req.body.office_id) : null;
    }
    await item.update(updatePayload);`
  );

  // 15. previewPayroll office filtering
  code = code.replace(
    /const employees = await hr_employees\.findAll\(\{\s*where:\s*\{\s*status:\s*'Active',\s*outlet_id:\s*req\.user\.outlet_id\s*\},/,
    `const { office_id } = req.body || {};
    const empWhere = { status: 'Active', outlet_id: req.user.outlet_id };
    if (office_id && office_id !== 'all' && office_id !== '0') {
      empWhere.office_id = office_id;
    }
    const employees = await hr_employees.findAll({
      where: empWhere,`
  );

  // 16. getLeaves office filtering
  code = code.replace(
    /exports\.getLeaves\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{[\s\S]*?const \{ employee_id, status \} = req\.query;/,
    `exports.getLeaves = async (req, res) => {
  try {
    const { hr_leave_applications, hr_employees, hr_leave_types, hr_offices } = req.propertyDb.models;
    const { employee_id, status, office_id } = req.query;`
  );
  code = code.replace(
    /include:\s*\[\s*\{\s*model:\s*hr_employees,\s*as:\s*'employee'\s*\},/,
    `include: [
        {
          model: hr_employees,
          as: 'employee',
          where: (office_id && office_id !== 'all' && office_id !== '0') ? { office_id } : undefined,
          include: hr_offices ? [{ model: hr_offices, as: 'office' }] : []
        },`
  );

  fs.writeFileSync(filePath, code, 'utf8');
  console.log('Patched controller:', filePath);
}

patchController(tsFile);
patchController(jsFile);
