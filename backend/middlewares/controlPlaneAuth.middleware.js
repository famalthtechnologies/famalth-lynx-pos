const { verify } = require('../utils/jwt.util');

const requireControlPlaneAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error_code: 'CONTROL_PLANE_UNAUTHORIZED',
        message: 'Access denied: Master Control Plane credentials required. Client tokens not accepted.',
      });
    }

    const token = authHeader.split(' ')[1];
    let decoded;

    try {
      decoded = verify(token);
    } catch (err) {
      return res.status(401).json({
        success: false,
        error_code: 'INVALID_TOKEN',
        message: 'Invalid or expired control plane session token.',
      });
    }

    if (!decoded || !decoded.is_control_plane || !decoded.staff_id) {
      return res.status(403).json({
        success: false,
        error_code: 'FORBIDDEN_CLIENT_TOKEN',
        message: 'Access forbidden: Regular merchant tokens cannot access the Developer & Reseller Control Plane.',
      });
    }

    req.masterStaff = decoded;
    return next();
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Internal control plane authorization failure.',
      error: error.message,
    });
  }
};

const requireStaffRole = (allowedRoles) => {
  return (req, res, next) => {
    if (!req.masterStaff) {
      return res.status(401).json({ success: false, message: 'Unauthorized staff request.' });
    }

    const staffRole = String(req.masterStaff.role || '').toUpperCase();
    const staffUser = String(req.masterStaff.username || '').toLowerCase();
    const isRoot = ['SUPER_ADMIN', 'OWNER', 'ENTERPRISE_ADMIN'].includes(staffRole) || staffUser === 'owner' || staffUser === 'admin';
    if (isRoot) {
      return next();
    }

    if (allowedRoles.map(r => r.toUpperCase()).includes(staffRole)) {
      return next();
    }

    return res.status(403).json({
      success: false,
      message: `Permission denied: Action requires one of roles [${allowedRoles.join(', ')}]`,
    });
  };
};

module.exports = {
  requireControlPlaneAuth,
  requireStaffRole,
};
