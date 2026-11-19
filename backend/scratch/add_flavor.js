const fs = require('fs');
const file = 'android/app/build.gradle';
let txt = fs.readFileSync(file, 'utf8');

const target = `        clinic {
            dimension "default"
            applicationId "com.retailpos.clinic"
            resValue "string", "app_name", "Clinic"
        }`;

const replacement = `        clinic {
            dimension "default"
            applicationId "com.retailpos.clinic"
            resValue "string", "app_name", "Clinic"
        }
        employee {
            dimension "default"
            applicationId "com.retailpos.employee"
            resValue "string", "app_name", "Staff Attendance"
        }`;

if (!txt.includes('applicationId "com.retailpos.employee"')) {
  if (txt.includes(target)) {
    txt = txt.replace(target, replacement);
  } else {
    txt = txt.replace(target.replace(/\n/g, '\r\n'), replacement.replace(/\n/g, '\r\n'));
  }
}

fs.writeFileSync(file, txt, 'utf8');
console.log('Added employee flavor to build.gradle! Has employee flavor:', txt.includes('applicationId "com.retailpos.employee"'));
