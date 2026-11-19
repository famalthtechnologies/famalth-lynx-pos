const { Sequelize } = require('sequelize');
const sequelize = new Sequelize('famalth_lynx', 'postgres', 'postgres', {
  host: '127.0.0.1',
  port: 5433,
  dialect: 'postgres',
  logging: false
});

async function run() {
  const [users] = await sequelize.query('SELECT usename FROM pg_user;');
  console.log('USERS:', users.map(u => u.usename));
  const [dbs] = await sequelize.query('SELECT datname FROM pg_database;');
  console.log('ALL DATABASES:', dbs.map(d => d.datname));
}

run().then(() => process.exit(0)).catch(err => {
  console.error(err);
  process.exit(1);
});
