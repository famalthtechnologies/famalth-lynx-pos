import { Request, Response, NextFunction } from 'express';
import { verify } from '../utils/jwt.util';

export interface ControlPlaneStaffJwtPayload {
  staff_id: string;
  username: string;
  email: string;
  role: 'SUPER_ADMIN' | 'RESELLER_ADMIN' | 'DEVELOPER' | 'SUPPORT_AGENT' | 'RM';
  reseller_id: string | null;
  permissions: string[];
  is_control_plane: boolean;
}

declare global {
  namespace Express {
    interface Request {
      masterStaff?: ControlPlaneStaffJwtPayload;
    }
  }
}

/**
 * Control Plane Staff Authentication Middleware
 * Strictly enforces that callers possess a valid Control Plane Staff JWT.
 * Normal merchant POS cashier/admin tokens are completely rejected.
 */
export const requireControlPlaneAuth = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<any> => {
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
    let decoded: any;

    try {
      decoded = verify(token);
    } catch (err: any) {
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
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: 'Internal control plane authorization failure.',
      error: error.message,
    });
  }
};

/**
 * Require specific role or super admin
 */
export const requireStaffRole = (allowedRoles: string[]) => {
  return (req: Request, res: Response, next: NextFunction): any => {
    if (!req.masterStaff) {
      return res.status(401).json({ success: false, message: 'Unauthorized staff request.' });
    }

    if (req.masterStaff.role === 'SUPER_ADMIN') {
      return next();
    }

    if (allowedRoles.includes(req.masterStaff.role)) {
      return next();
    }

    return res.status(403).json({
      success: false,
      message: `Permission denied: Action requires one of roles [${allowedRoles.join(', ')}]`,
    });
  };
};

export default {
  requireControlPlaneAuth,
  requireStaffRole,
};
