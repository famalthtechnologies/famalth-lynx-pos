const db = require('../db/models');
const ctrl = require('../controllers/hrms/hrms.controller');

(async () => {
  try {
    await db.authenticate();
    const req = {
      propertyDb: db,
      user: { outlet_id: 1, id: 1 },
      query: { month: '2026-11' }
    };
    const testEp = async (name, fn) => {
      let r = null;
      let status = 200;
      await fn(req, {
        json: (res) => { r = res; },
        status: (s) => ({ json: (res) => { status = s; r = res; } })
      });
      console.log(name, 'status:', status, 'success:', r?.success, 'count:', Array.isArray(r?.data) ? r.data.length : typeof r?.data);
    };

    await testEp('getEmployees', ctrl.getEmployees);
    await testEp('getAttendance', ctrl.getAttendance);
    await testEp('getLeaves', ctrl.getLeaves);
    await testEp('getLoans', ctrl.getLoans);
    await testEp('getShifts', ctrl.getShifts);
    await testEp('getHolidays', ctrl.getHolidays);
    await testEp('getLeaveTypes', ctrl.getLeaveTypes);
    await testEp('getOffices', ctrl.getOffices);

  } catch (e) {
    console.error("Test failed:", e);
  } finally {
    process.exit(0);
  }
})();
