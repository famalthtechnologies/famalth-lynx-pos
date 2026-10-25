import { Request, Response, NextFunction } from 'express';
import maintenanceService from '../services/maintenance.service';

export function maintenanceMiddleware(req: Request, res: Response, next: NextFunction) {
  // Always allow health checks, static assets, maintenance API, and control-plane management
  const path = req.path || '';
  if (
    path.startsWith('/api/system/maintenance') ||
    path.startsWith('/api/control-plane') ||
    path.startsWith('/api/v1/control-plane') ||
    path.startsWith('/api/backup') ||
    path.startsWith('/api/auth/login') ||
    path.startsWith('/health') ||
    path.startsWith('/canvaskit') ||
    path.startsWith('/assets') ||
    req.method === 'OPTIONS'
  ) {
    return next();
  }

  // Allow Super Admins / Enterprise Admins bypass (from decoded user or incoming bearer token)
  const user = (req as any).user;
  const role = String(user?.role || '').toUpperCase();
  if (role === 'SUPER_ADMIN' || role === 'ENTERPRISE_ADMIN') {
    return next();
  }

  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    try {
      const jwt = require('../utils/jwt.util');
      const decoded = jwt.verify(authHeader.split(' ')[1]);
      const tokenRole = String(decoded?.role || '').toUpperCase();
      if (tokenRole === 'SUPER_ADMIN' || tokenRole === 'ENTERPRISE_ADMIN') {
        return next();
      }
    } catch (_) {}
  }

  // Check if system is in maintenance mode
  if (maintenanceService.isUnderMaintenance()) {
    const status = maintenanceService.getStatus();
    return res.status(503).json({
      success: false,
      maintenance: true,
      title: status.title,
      message: status.message,
      startedAt: status.startedAt,
      estimatedEndTime: status.estimatedEndTime,
      remainingMinutes: status.remainingMinutes,
    });
  }

  return next();
}

export default maintenanceMiddleware;
