"use strict";
const db = require('../db/models');
console.log("hr_offices model registered:", Boolean(db.models && db.models.hr_offices));
process.exit(0);
