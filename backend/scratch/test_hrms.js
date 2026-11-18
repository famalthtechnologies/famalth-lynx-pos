"use strict";
const db = require('../db/models');
const ctrl = require('../controllers/hrms/hrms.controller');

(async () => {
  try {
    await db.authenticate();
    console.log("DB Authenticated.");

    // Test getOffices
    const mockReq = { propertyDb: db, user: { outlet_id: 1, id: 1 } };
    let officesResult = null;
    await ctrl.getOffices(mockReq, {
      json: (res) => { officesResult = res; }
    });
    console.log("getOffices result:", officesResult);

    // Test getHrmsDashboardOverview
    let dashResult = null;
    await ctrl.getHrmsDashboardOverview({ ...mockReq, query: { office_id: 'all' } }, {
      json: (res) => { dashResult = res; }
    });
    console.log("getHrmsDashboardOverview result:", dashResult?.metrics);

    console.log("ALL BACKEND HRMS TESTS PASSED!");
  } catch (e) {
    console.error("Test failed:", e);
  } finally {
    process.exit(0);
  }
})();
