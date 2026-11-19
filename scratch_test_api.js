const axios = require('./backend/node_modules/axios');

async function testApi() {
  try {
    // Let's call the controller function getAttendance directly with req mock
    const { getAttendance } = require('./backend/controllers/hrms/hrms.controller');
    const { Sequelize } = require('./backend/node_modules/sequelize');
    const initModels = require('./backend/models/property');
    const seq = new Sequelize('famalth_lynx', 'postgres', 'postgres', {
      host: 'localhost',
      port: 5433,
      dialect: 'postgres',
      logging: false
    });
    const models = initModels(seq);

    const req = {
      user: { id: 1, outlet_id: 1 },
      query: { month: '2026-11' },
      propertyDb: { models }
    };
    const res = {
      json: (d) => {
        console.log('RESPONSE JSON SUCCESS:', d.success);
        console.log('RESPONSE DATA COUNT:', d.data ? d.data.length : 'none');
        if (d.data && d.data.length > 0) {
          console.log('SAMPLE ROW:', d.data[0]);
        }
      },
      status: (code) => {
        console.log('STATUS CODE:', code);
        return {
          json: (d) => console.log('ERROR JSON:', d)
        };
      }
    };

    await getAttendance(req, res);
    await seq.close();
  } catch (err) {
    console.error('TEST ERROR:', err);
  }
}

testApi();
