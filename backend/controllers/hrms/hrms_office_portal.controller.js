'use strict';
const { Op } = require('sequelize');
const moment = require('moment');
const bcrypt = require('bcryptjs');
const jwt = require('../../utils/jwt.util');
const { sendMail } = require('../../services/email.service');

function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
  const pLat1 = parseFloat(lat1);
  const pLon1 = parseFloat(lon1);
  const pLat2 = parseFloat(lat2);
  const pLon2 = parseFloat(lon2);

  if (isNaN(pLat1) || isNaN(pLon1) || isNaN(pLat2) || isNaN(pLon2) ||
      (pLat1 === 0 && pLon1 === 0) || (pLat2 === 0 && pLon2 === 0)) {
    return 0;
  }

  const R = 6371000;
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(pLat2 - pLat1);
  const dLon = toRad(pLon2 - pLon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(pLat1)) * Math.cos(toRad(pLat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

exports.getOffices = async (req, res) => {
  try {
    const { hr_offices, hr_employees } = req.propertyDb.models;
    const outlet_id = req.user ? req.user.outlet_id : (req.outlet_id || 1);

    const offices = await hr_offices.findAll({
      where: { outlet_id, is_active: true },
      order: [['id', 'ASC']]
    });

    const result = await Promise.all(offices.map(async (off) => {
      const plain = off.toJSON ? off.toJSON() : off;
      const empCount = await hr_employees.count({
        where: { office_id: off.id, status: 'Active', outlet_id }
      });
      return {
        ...plain,
        employee_count: empCount
      };
    }));

    return res.json({ success: true, data: result });
  } catch (err) {
    console.error('getOffices error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createOffice = async (req, res) => {
  try {
    const { hr_offices } = req.propertyDb.models;
    const outlet_id = req.user ? req.user.outlet_id : (req.outlet_id || 1);
    const { office_code, office_name, address, city, state, pincode, latitude, longitude, radius_meters } = req.body;

    if (!office_name || office_name.trim() === '') {
      return res.status(400).json({ success: false, message: 'Office name is required.' });
    }

    let code = office_code ? office_code.trim() : '';
    if (!code) {
      const count = await hr_offices.count({ where: { outlet_id } });
      code = `HO-${String(count + 1).padStart(2, '0')}`;
    }

    const office = await hr_offices.create({
      outlet_id,
      office_code: code,
      office_name: office_name.trim(),
      address: address || '',
      city: city || '',
      state: state || '',
      pincode: pincode || '',
      latitude: parseFloat(latitude) || 0.0,
      longitude: parseFloat(longitude) || 0.0,
      radius_meters: parseInt(radius_meters) || 150,
      is_active: true
    });

    return res.json({ success: true, data: office, message: 'Office created successfully.' });
  } catch (err) {
    console.error('createOffice error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.updateOffice = async (req, res) => {
  try {
    const { hr_offices } = req.propertyDb.models;
    const outlet_id = req.user ? req.user.outlet_id : (req.outlet_id || 1);
    const office = await hr_offices.findOne({
      where: { id: req.params.id, outlet_id }
    });

    if (!office) {
      return res.status(404).json({ success: false, message: 'Office not found.' });
    }

    const { office_code, office_name, address, city, state, pincode, latitude, longitude, radius_meters, is_active } = req.body;

    await office.update({
      office_code: office_code !== undefined ? office_code.trim() : office.office_code,
      office_name: office_name !== undefined ? office_name.trim() : office.office_name,
      address: address !== undefined ? address : office.address,
      city: city !== undefined ? city : office.city,
      state: state !== undefined ? state : office.state,
      pincode: pincode !== undefined ? pincode : office.pincode,
      latitude: latitude !== undefined ? parseFloat(latitude) : office.latitude,
      longitude: longitude !== undefined ? parseFloat(longitude) : office.longitude,
      radius_meters: radius_meters !== undefined ? parseInt(radius_meters) : office.radius_meters,
      is_active: is_active !== undefined ? is_active : office.is_active
    });

    return res.json({ success: true, data: office, message: 'Office updated successfully.' });
  } catch (err) {
    console.error('updateOffice error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.deleteOffice = async (req, res) => {
  try {
    const { hr_offices, hr_employees } = req.propertyDb.models;
    const outlet_id = req.user ? req.user.outlet_id : (req.outlet_id || 1);
    const office = await hr_offices.findOne({
      where: { id: req.params.id, outlet_id }
    });

    if (!office) {
      return res.status(404).json({ success: false, message: 'Office not found.' });
    }

    const assignedCount = await hr_employees.count({
      where: { office_id: office.id, status: 'Active', outlet_id }
    });

    if (assignedCount > 0) {
      return res.status(400).json({
        success: false,
        message: `Cannot delete office. ${assignedCount} active employees are currently assigned to this office. Reassign them first.`
      });
    }

    await office.update({ is_active: false });
    return res.json({ success: true, message: 'Office deactivated successfully.' });
  } catch (err) {
    console.error('deleteOffice error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.employeeLogin = async (req, res) => {
  try {
    const db = req.propertyDb || require('../../db/models/index');
    const { hr_employees, hr_offices, hr_shifts, hr_designations, outlets } = db.models;
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ success: false, message: 'Employee Code / Email and Password are required.' });
    }

    const cleanUsername = username.trim().toLowerCase();

    const employee = await hr_employees.findOne({
      where: {
        [Op.or]: [
          { employee_code: { [Op.iLike]: cleanUsername } },
          { contact_email: { [Op.iLike]: cleanUsername } }
        ],
        status: 'Active'
      },
      include: [
        { model: hr_offices, as: 'office' },
        { model: hr_shifts, as: 'shift' },
        { model: hr_designations, as: 'designation' },
        { model: outlets, as: 'outlet' }
      ]
    });

    if (!employee) {
      return res.status(401).json({ success: false, message: 'Employee not found or inactive account.' });
    }

    let passwordMatches = false;
    if (employee.password_hash) {
      passwordMatches = await bcrypt.compare(password, employee.password_hash);
    } else {
      if (password === '123456' || password.toLowerCase() === employee.employee_code.toLowerCase()) {
        passwordMatches = true;
        const hashed = await bcrypt.hash(password, 10);
        await employee.update({ password_hash: hashed });
      }
    }

    if (!passwordMatches) {
      return res.status(401).json({ success: false, message: 'Invalid password. Please check and try again.' });
    }

    const tokenPayload = {
      id: employee.id,
      user_id: employee.user_id || employee.id,
      employee_id: employee.id,
      employee_code: employee.employee_code,
      full_name: employee.full_name,
      email: employee.contact_email,
      outlet_id: employee.outlet_id,
      role: 'EMPLOYEE',
      permissions: ['EMPLOYEE_PORTAL']
    };

    const token = jwt.sign(tokenPayload, { expiresIn: '60d' });

    const empData = employee.toJSON ? employee.toJSON() : employee;
    delete empData.password_hash;
    delete empData.reset_otp;

    return res.json({
      success: true,
      token,
      employee: empData,
      message: `Welcome back, ${employee.full_name}!`
    });
  } catch (err) {
    console.error('employeeLogin error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.employeeRequestResetOtp = async (req, res) => {
  try {
    const db = req.propertyDb || require('../../db/models/index');
    const { hr_employees, hr_offices, outlets } = db.models;
    const rawInput = req.body.email_or_code || req.body.login || req.body.email || req.body.employee_code || '';

    if (!rawInput || String(rawInput).trim() === '') {
      return res.status(400).json({ success: false, message: 'Please enter your Employee Code or Registered Email.' });
    }

    const cleanInput = String(rawInput).trim().toLowerCase();

    const employees = await hr_employees.findAll({
      where: {
        [Op.or]: [
          { employee_code: { [Op.iLike]: cleanInput } },
          { contact_email: { [Op.iLike]: cleanInput } }
        ],
        status: 'Active'
      },
      include: [
        { model: hr_offices, as: 'office' },
        { model: outlets, as: 'outlet' }
      ],
      order: [['id', 'DESC']]
    });

    if (!employees || employees.length === 0) {
      return res.status(404).json({ success: false, message: 'No active employee found matching this code or email.' });
    }

    const employee = employees[0];

    if (!employee.contact_email || employee.contact_email.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'No registered email found for your account. Please contact your HR/Admin to update your email.'
      });
    }

    // Generate 6-digit OTP
    const otp = String(Math.floor(100000 + Math.random() * 900000));
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    for (const emp of employees) {
      await emp.update({
        reset_otp: otp,
        reset_otp_expires_at: expiresAt
      });
    }

    const companyName = employee.outlet?.outlet_name || 'Famalth Business Solutions';

    const emailHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto; padding: 24px; border: 1px solid #E2E8F0; border-radius: 12px; background: #ffffff;">
        <div style="text-align: center; margin-bottom: 20px;">
          <h2 style="color: #1E3A8A; margin: 0;">${companyName}</h2>
          <p style="color: #64748B; font-size: 14px; margin-top: 4px;">Employee Self-Service Portal</p>
        </div>
        <div style="background: #F8FAFC; border-radius: 8px; padding: 18px; margin-bottom: 20px;">
          <p style="margin: 0 0 10px 0; color: #1E293B; font-size: 15px;">Hello <strong>${employee.full_name}</strong>,</p>
          <p style="margin: 0; color: #475569; font-size: 14px; line-height: 1.5;">
            You requested to reset your password for the Employee Attendance & Portal App. Use the verification OTP below to complete your password reset:
          </p>
          <div style="text-align: center; margin: 24px 0;">
            <span style="display: inline-block; font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #2563EB; background: #EFF6FF; padding: 12px 28px; border-radius: 8px; border: 1px dashed #3B82F6;">
              ${otp}
            </span>
          </div>
          <p style="margin: 0; color: #64748B; font-size: 12px; text-align: center;">
            This OTP will expire in <strong>15 minutes</strong>. If you did not request this, please ignore this email.
          </p>
        </div>
        <p style="color: #94A3B8; font-size: 11px; text-align: center; margin: 0;">
          Secured by Famalth HRMS & Attendance System
        </p>
      </div>
    `;

    let emailSent = false;
    try {
      emailSent = await sendMail({
        db: db,
        outlet_id: employee.outlet_id,
        to: employee.contact_email,
        subject: `🔑 Password Reset OTP: ${otp} - ${companyName}`,
        html: emailHtml
      });
    } catch (mailErr) {
      console.warn(`[OTP] Email delivery warning: ${mailErr.message}.`);
    }

    if (!emailSent) {
      return res.status(500).json({
        success: false,
        message: 'Could not send verification email. Please check system email settings or contact your administrator.'
      });
    }

    const maskedEmail = employee.contact_email.replace(/(.{2})(.*)(?=@)/, (_gp1, gp2, gp3) => gp2 + '*'.repeat(gp3.length));

    return res.json({
      success: true,
      message: `Verification OTP has been sent to your registered email (${maskedEmail}). Please check your inbox or spam folder.`
    });
  } catch (err) {
    console.error('employeeRequestResetOtp error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.employeeResetPassword = async (req, res) => {
  try {
    const db = req.propertyDb || require('../../db/models/index');
    const { hr_employees } = db.models;
    const rawInput = req.body.email_or_code || req.body.login || req.body.email || req.body.employee_code || '';
    const otp = req.body.otp;
    const new_password = req.body.new_password || req.body.password;

    if (!rawInput || !otp || !new_password) {
      return res.status(400).json({ success: false, message: 'Email/Code, OTP, and New Password are required.' });
    }

    if (String(new_password).length < 6) {
      return res.status(400).json({ success: false, message: 'New password must be at least 6 characters long.' });
    }

    const cleanInput = String(rawInput).trim().toLowerCase();

    const employee = await hr_employees.findOne({
      where: {
        [Op.or]: [
          { employee_code: { [Op.iLike]: cleanInput } },
          { contact_email: { [Op.iLike]: cleanInput } }
        ],
        status: 'Active'
      }
    });

    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee not found.' });
    }

    if (!employee.reset_otp || employee.reset_otp !== otp.trim()) {
      return res.status(400).json({ success: false, message: 'Invalid OTP code. Please check your email.' });
    }

    if (employee.reset_otp_expires_at) {
      const expiresAtMs = new Date(employee.reset_otp_expires_at).getTime();
      // Allow 2 minutes grace period for network latency / clock skew
      if (Date.now() > (expiresAtMs + 120000)) {
        return res.status(400).json({ success: false, message: 'OTP has expired. Please request a new one.' });
      }
    }

    const hashed = await bcrypt.hash(new_password, 10);
    await employee.update({
      password_hash: hashed,
      reset_otp: null,
      reset_otp_expires_at: null
    });

    return res.json({
      success: true,
      message: 'Password reset successful! You can now log in with your new password.'
    });
  } catch (err) {
    console.error('employeeResetPassword error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.employeeChangePassword = async (req, res) => {
  try {
    const { hr_employees } = req.propertyDb.models;
    const employee_id = req.user.employee_id || req.user.id;
    const { current_password, new_password } = req.body;

    if (!current_password || !new_password) {
      return res.status(400).json({ success: false, message: 'Current password and new password are required.' });
    }

    if (new_password.length < 6) {
      return res.status(400).json({ success: false, message: 'New password must be at least 6 characters long.' });
    }

    const employee = await hr_employees.findByPk(employee_id);
    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee not found.' });
    }

    if (employee.password_hash) {
      const match = await bcrypt.compare(current_password, employee.password_hash);
      if (!match) {
        return res.status(400).json({ success: false, message: 'Current password does not match.' });
      }
    }

    const hashed = await bcrypt.hash(new_password, 10);
    await employee.update({ password_hash: hashed });

    return res.json({ success: true, message: 'Password changed successfully!' });
  } catch (err) {
    console.error('employeeChangePassword error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.employeeGeotaggedPunch = async (req, res) => {
  try {
    const { hr_attendance_punches, hr_employees, hr_offices, hr_shifts, hr_payroll_runs } = req.propertyDb.models;
    const { type, latitude, longitude } = req.body;

    if (!type || !['IN', 'OUT'].includes(type.toUpperCase())) {
      return res.status(400).json({ success: false, message: "Punch type must be 'IN' or 'OUT'." });
    }

    const punchType = type.toUpperCase();
    const lat = parseFloat(latitude) || 0.0;
    const lon = parseFloat(longitude) || 0.0;

    let employee_id = req.user.employee_id;
    if (!employee_id) {
      const emp = await hr_employees.findOne({
        where: { user_id: req.user.id, outlet_id: req.user.outlet_id }
      });
      if (emp) employee_id = emp.id;
    }
    if (!employee_id && req.body.employee_id) {
      employee_id = req.body.employee_id;
    }

    if (!employee_id) {
      return res.status(400).json({ success: false, message: 'Employee record not found for your account.' });
    }

    const employee = await hr_employees.findByPk(employee_id, {
      include: [
        { model: hr_offices, as: 'office' },
        { model: hr_shifts, as: 'shift' }
      ]
    });

    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee not found.' });
    }

    let office = employee.office;
    if (!office && employee.office_id) {
      office = await hr_offices.findByPk(employee.office_id);
    }
    if (!office) {
      office = await hr_offices.findOne({
        where: { outlet_id: employee.outlet_id, is_active: true },
        order: [['id', 'ASC']]
      });
    }

    if (!office) {
      return res.status(400).json({
        success: false,
        message: 'No office or branch location configured for attendance geotagging. Please contact HR.'
      });
    }

    const distanceMeters = calculateHaversineDistance(
      lat,
      lon,
      parseFloat(office.latitude || 0),
      parseFloat(office.longitude || 0)
    );

    const allowedRadius = office.radius_meters || 150;
    const isCompliant = lat !== 0 && lon !== 0 && (distanceMeters <= allowedRadius);

    const monthStr = moment().format('YYYY-MM');
    const latestLockedRun = await hr_payroll_runs.findOne({
      where: { status: 'Approved', outlet_id: employee.outlet_id },
      order: [['pay_period', 'DESC']]
    });
    if (latestLockedRun && monthStr <= latestLockedRun.pay_period) {
      return res.status(400).json({
        success: false,
        message: `Attendance is locked. Payroll for ${latestLockedRun.pay_period} has already been approved and paid!`
      });
    }

    const today = moment().format('YYYY-MM-DD');
    const now = new Date();

    if (punchType === 'IN') {
      let punch = await hr_attendance_punches.findOne({
        where: { employee_id: employee.id, punch_date: today, outlet_id: employee.outlet_id }
      });

      if (punch && punch.punch_in) {
        return res.status(400).json({
          success: false,
          message: `Already checked in today at ${moment(punch.punch_in).format('hh:mm A')}.`
        });
      }

      let lateMins = 0;
      let status = 'Present';
      if (employee.shift && employee.shift.start_time) {
        const shiftStart = moment(`${today} ${employee.shift.start_time}`, 'YYYY-MM-DD HH:mm:ss');
        const graceLimit = shiftStart.clone().add(employee.shift.grace_period_mins || 0, 'minutes');
        const punchMoment = moment(now);

        if (punchMoment.isAfter(graceLimit)) {
          lateMins = Math.max(0, punchMoment.diff(shiftStart, 'minutes'));
          status = 'Late';
        }
      }

      if (!punch) {
        punch = await hr_attendance_punches.create({
          outlet_id: employee.outlet_id,
          employee_id: employee.id,
          office_id: office.id,
          punch_date: today,
          punch_in: now,
          checkin_latitude: lat,
          checkin_longitude: lon,
          checkin_distance_meters: distanceMeters,
          is_geofence_compliant: isCompliant,
          lateness_mins: lateMins,
          status,
          punch_source: 'Mobile_GPS',
          updated_by: req.user.id
        });
      } else {
        await punch.update({
          office_id: office.id,
          punch_in: now,
          checkin_latitude: lat,
          checkin_longitude: lon,
          checkin_distance_meters: distanceMeters,
          is_geofence_compliant: isCompliant,
          lateness_mins: lateMins,
          status,
          punch_source: 'Mobile_GPS'
        });
      }

      const distText = distanceMeters > 1000
        ? `${(distanceMeters / 1000).toFixed(1)} km`
        : `${distanceMeters} m`;

      const complianceMsg = isCompliant
        ? `Within geofence (${distText} from ${office.office_name})`
        : `Outside geofence (${distText} from ${office.office_name}, max: ${allowedRadius}m)`;

      return res.json({
        success: true,
        data: punch,
        distance_meters: distanceMeters,
        is_compliant: isCompliant,
        message: `✅ Check-in recorded at ${moment(now).format('hh:mm A')}. ${complianceMsg}. Status: ${status}.`
      });
    } else {
      const punch = await hr_attendance_punches.findOne({
        where: { employee_id: employee.id, punch_date: today, outlet_id: employee.outlet_id }
      });

      if (!punch || !punch.punch_in) {
        return res.status(400).json({ success: false, message: 'You must check-in first before checking out.' });
      }

      if (punch.punch_out) {
        return res.status(400).json({
          success: false,
          message: `Already checked out today at ${moment(punch.punch_out).format('hh:mm A')}.`
        });
      }

      const inMoment = moment(punch.punch_in);
      const outMoment = moment(now);
      const workedMins = outMoment.diff(inMoment, 'minutes');
      const hoursWorked = Math.max(0, parseFloat((workedMins / 60).toFixed(2)));

      let overtimeHours = 0.0;
      let earlyMins = 0;

      if (employee.shift) {
        const shift = employee.shift;
        if (shift.start_time && shift.end_time) {
          const shiftStart = moment(`${today} ${shift.start_time}`, 'YYYY-MM-DD HH:mm:ss');
          const shiftEnd = moment(`${today} ${shift.end_time}`, 'YYYY-MM-DD HH:mm:ss');
          let shiftDurationMins = shiftEnd.diff(shiftStart, 'minutes');
          if (shiftDurationMins < 0) shiftDurationMins += 24 * 60;
          const shiftHours = shiftDurationMins / 60;

          if (hoursWorked > shiftHours) {
            overtimeHours = parseFloat((hoursWorked - shiftHours).toFixed(2));
          }

          if (outMoment.isBefore(shiftEnd)) {
            earlyMins = Math.max(0, shiftEnd.diff(outMoment, 'minutes'));
          }
        }
      }

      const overallCompliant = punch.is_geofence_compliant && isCompliant;

      await punch.update({
        punch_out: now,
        checkout_latitude: lat,
        checkout_longitude: lon,
        checkout_distance_meters: distanceMeters,
        hours_worked: hoursWorked,
        overtime_hours: overtimeHours,
        early_departure_mins: earlyMins,
        is_geofence_compliant: overallCompliant
      });

      const distText = distanceMeters > 1000
        ? `${(distanceMeters / 1000).toFixed(1)} km`
        : `${distanceMeters} m`;

      return res.json({
        success: true,
        data: punch,
        distance_meters: distanceMeters,
        hours_worked: hoursWorked,
        overtime_hours: overtimeHours,
        early_departure_mins: earlyMins,
        is_compliant: isCompliant,
        message: `🏁 Check-out recorded at ${moment(now).format('hh:mm A')}. Worked: ${hoursWorked} hrs (OT: ${overtimeHours} hrs, ${distText} from ${office.office_name}).`
      });
    }
  } catch (err) {
    console.error('employeeGeotaggedPunch error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getMyEmployeeProfile = async (req, res) => {
  try {
    const { hr_employees, hr_offices, hr_shifts, hr_designations, hr_leave_balances, hr_leave_types, hr_leave_applications, hr_attendance_punches, outlets } = req.propertyDb.models;
    const employee_id = req.user.employee_id || req.user.id;

    const employee = await hr_employees.findByPk(employee_id, {
      include: [
        { model: hr_offices, as: 'office' },
        { model: hr_shifts, as: 'shift' },
        { model: hr_designations, as: 'designation' },
        { model: outlets, as: 'outlet' }
      ]
    });

    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee profile not found.' });
    }

    const balances = await hr_leave_balances.findAll({
      where: { employee_id: employee.id },
      include: [{ model: hr_leave_types, as: 'leaveType' }]
    });

    const leaveSummary = balances.map(b => {
      const lt = b.leaveType || {};
      const allocated = parseFloat(b.allocated_quota || 0);
      const used = parseFloat(b.used_quota || 0);
      const remaining = Math.max(0, allocated - used);
      return {
        id: b.id,
        leave_type_id: b.leave_type_id,
        name: lt.name || 'Leave',
        code: lt.code || 'LV',
        allocated,
        used,
        remaining
      };
    });

    let myLeaves = [];
    if (hr_leave_applications) {
      myLeaves = await hr_leave_applications.findAll({
        where: { employee_id: employee.id },
        include: [{ model: hr_leave_types, as: 'leaveType' }],
        order: [['created_at', 'DESC']]
      });
    }

    const currentMonth = moment().format('YYYY-MM');
    const startOfMonth = moment().startOf('month').format('YYYY-MM-DD');
    const endOfMonth = moment().endOf('month').format('YYYY-MM-DD');

    const monthPunches = await hr_attendance_punches.findAll({
      where: {
        employee_id: employee.id,
        punch_date: { [Op.between]: [startOfMonth, endOfMonth] }
      },
      include: [{ model: hr_offices, as: 'office', attributes: ['office_name', 'office_code'] }],
      order: [['punch_date', 'DESC']]
    });

    let totalWorkedHours = 0;
    let totalOvertimeHours = 0;
    let totalLateMins = 0;
    let presentDays = 0;

    for (const p of monthPunches) {
      totalWorkedHours += parseFloat(p.hours_worked || 0);
      totalOvertimeHours += parseFloat(p.overtime_hours || 0);
      totalLateMins += parseInt(p.lateness_mins || 0);
      if (p.status === 'Present' || p.status === 'Late') {
        presentDays++;
      }
    }

    const todayStr = moment().format('YYYY-MM-DD');
    const todayPunch = monthPunches.find(p => p.punch_date === todayStr) || null;

    const empData = employee.toJSON ? employee.toJSON() : employee;
    delete empData.password_hash;
    delete empData.reset_otp;

    return res.json({
      success: true,
      employee: empData,
      leave_balances: leaveSummary,
      my_leaves: myLeaves,
      today_punch: todayPunch,
      month_stats: {
        month: currentMonth,
        present_days: presentDays,
        total_worked_hours: parseFloat(totalWorkedHours.toFixed(2)),
        total_overtime_hours: parseFloat(totalOvertimeHours.toFixed(2)),
        total_late_mins: totalLateMins
      },
      recent_punches: monthPunches.slice(0, 15)
    });
  } catch (err) {
    console.error('getMyEmployeeProfile error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getHrmsDashboardOverview = async (req, res) => {
  try {
    const { hr_offices, hr_employees, hr_attendance_punches, hr_leave_applications } = req.propertyDb.models;
    const outlet_id = req.user ? req.user.outlet_id : (req.outlet_id || 1);
    const officeFilter = req.query.office_id;
    const today = moment().format('YYYY-MM-DD');

    const offices = await hr_offices.findAll({
      where: { outlet_id, is_active: true },
      order: [['id', 'ASC']]
    });

    const empWhere = { outlet_id, status: 'Active' };
    const punchWhere = { outlet_id, punch_date: today };

    if (officeFilter && officeFilter !== 'all' && officeFilter !== '0') {
      const offId = parseInt(officeFilter);
      if (!isNaN(offId)) {
        empWhere.office_id = offId;
        punchWhere.office_id = offId;
      }
    }

    const totalEmployees = await hr_employees.count({ where: empWhere });

    const todayPunches = await hr_attendance_punches.findAll({
      where: punchWhere,
      include: [
        { model: hr_employees, as: 'employee', attributes: ['id', 'employee_code', 'full_name', 'mobile'] },
        { model: hr_offices, as: 'office', attributes: ['id', 'office_code', 'office_name', 'radius_meters'] }
      ],
      order: [['punch_in', 'DESC']]
    });

    let presentToday = 0;
    let lateArrivals = 0;
    let earlyDepartures = 0;
    let overtimeHours = 0;
    let totalHoursWorked = 0;
    let geofenceViolations = 0;

    for (const p of todayPunches) {
      if (p.punch_in) presentToday++;
      if (parseInt(p.lateness_mins || 0) > 0) lateArrivals++;
      if (parseInt(p.early_departure_mins || 0) > 0) earlyDepartures++;
      overtimeHours += parseFloat(p.overtime_hours || 0);
      totalHoursWorked += parseFloat(p.hours_worked || 0);
      if (p.is_geofence_compliant === false) geofenceViolations++;
    }

    const onLeaveToday = await hr_leave_applications.count({
      where: {
        outlet_id,
        status: 'Approved',
        start_date: { [Op.lte]: today },
        end_date: { [Op.gte]: today }
      }
    });

    const absentToday = Math.max(0, totalEmployees - presentToday - onLeaveToday);

    return res.json({
      success: true,
      selected_office_id: officeFilter || 'all',
      offices,
      metrics: {
        today,
        total_employees: totalEmployees,
        present_today: presentToday,
        absent_today: absentToday,
        on_leave_today: onLeaveToday,
        late_arrivals: lateArrivals,
        early_departures: earlyDepartures,
        overtime_hours: parseFloat(overtimeHours.toFixed(2)),
        total_hours_worked: parseFloat(totalHoursWorked.toFixed(2)),
        geofence_violations: geofenceViolations
      },
      recent_punches: todayPunches.slice(0, 30)
    });
  } catch (err) {
    console.error('getHrmsDashboardOverview error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

module.exports = exports;
