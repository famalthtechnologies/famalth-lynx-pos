import { Request, Response, NextFunction } from 'express';
import maintenanceService from '../services/maintenance.service';

export function maintenanceMiddleware(req: Request, res: Response, next: NextFunction) {
  // Always allow health checks, static assets, maintenance API, and ALL control-plane / admin console management
  const fullPath = (req.originalUrl || req.baseUrl + req.path || req.path || '').toLowerCase();
  if (
    fullPath.includes('/control-plane') ||
    fullPath.includes('/api/system/maintenance') ||
    fullPath.includes('/api/backup') ||
    fullPath.includes('/api/auth/login') ||
    fullPath.includes('/health') ||
    fullPath.includes('/canvaskit') ||
    fullPath.includes('/assets') ||
    req.headers['x-client-type'] === 'enterprise-console' ||
    req.headers['x-control-plane'] === 'true' ||
    req.method === 'OPTIONS'
  ) {
    return next();
  }

  // Allow Super Admins / Enterprise Admins / Control Plane Staff bypass
  const user = (req as any).user;
  const role = String(user?.role || '').toUpperCase();
  if (
    role === 'SUPER_ADMIN' ||
    role === 'ENTERPRISE_ADMIN' ||
    role === 'OWNER' ||
    role === 'DEVELOPER' ||
    role === 'RESELLER_ADMIN' ||
    role === 'RESELLER' ||
    role === 'SUPPORT_AGENT' ||
    role === 'RM'
  ) {
    return next();
  }

  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    try {
      const jwt = require('../utils/jwt.util');
      const decoded = jwt.verify(authHeader.split(' ')[1]);
      const tokenRole = String(decoded?.role || '').toUpperCase();
      if (
        decoded?.is_control_plane === true ||
        tokenRole === 'SUPER_ADMIN' ||
        tokenRole === 'ENTERPRISE_ADMIN' ||
        tokenRole === 'OWNER' ||
        tokenRole === 'DEVELOPER' ||
        tokenRole === 'RESELLER_ADMIN' ||
        tokenRole === 'RESELLER' ||
        tokenRole === 'SUPPORT_AGENT' ||
        tokenRole === 'RM'
      ) {
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
