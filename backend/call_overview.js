const jwt = require('./node_modules/jsonwebtoken');
const token = jwt.sign({ id: 1, email: "admin@retail.com", role_id: 1, outlet_id: 1, is_admin: true }, "secret_key_12345");
console.log(token);
