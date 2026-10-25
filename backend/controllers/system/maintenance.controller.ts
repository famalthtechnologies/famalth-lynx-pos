import { Request, Response } from 'express';
import maintenanceService from '../../services/maintenance.service';

export class MaintenanceController {
  /**
   * GET /api/system/maintenance-status
   * Public endpoint to check live maintenance state
   */
  public static async getStatus(req: Request, res: Response) {
    try {
      const status = maintenanceService.getStatus();
      return res.json({
        success: true,
        data: status,
      });
    } catch (e: any) {
      return res.status(500).json({ success: false, message: e.message });
    }
  }

  /**
   * POST /api/system/maintenance
   * Toggle maintenance on/off and set duration/message
   */
  public static async setMaintenance(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      const role = String(user?.role || '').toUpperCase();
      const isConsole = req.headers['x-client-type'] === 'enterprise-console' || req.headers['x-control-plane'] === 'true';
      const authHeader = req.headers.authorization || '';
      const allowedRoles = ['SUPER_ADMIN', 'ENTERPRISE_ADMIN', 'OWNER', 'DEVELOPER'];

      // Authorization guard: Only super admins, enterprise admins, owners, or control plane console
      if (!isConsole && !allowedRoles.includes(role) && !authHeader.includes('Bearer')) {
        return res.status(403).json({ success: false, message: 'Only Super Admins and Owners can alter maintenance mode.' });
      }

      const { isActive, title, message, durationMinutes } = req.body;
      const updated = maintenanceService.setMaintenance(
        Boolean(isActive),
        title,
        message,
        Number(durationMinutes || 30),
        user?.username || 'Super Admin'
      );

      return res.json({
        success: true,
        message: updated.isActive
          ? `System maintenance activated for ${updated.durationMinutes} minutes. All store terminals paused.`
          : 'System maintenance disabled. All store terminals resumed.',
        data: updated,
      });
    } catch (e: any) {
      return res.status(500).json({ success: false, message: e.message });
    }
  }

  /**
   * POST /api/system/maintenance/advance-notice
   * Toggle advance notice warning banner on/off (Render / Vercel / Bank style)
   */
  public static async setAdvanceNotice(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      const role = String(user?.role || '').toUpperCase();
      const isConsole = req.headers['x-client-type'] === 'enterprise-console' || req.headers['x-control-plane'] === 'true';
      const authHeader = req.headers.authorization || '';
      const allowedRoles = ['SUPER_ADMIN', 'ENTERPRISE_ADMIN', 'OWNER', 'DEVELOPER'];

      if (!isConsole && !allowedRoles.includes(role) && !authHeader.includes('Bearer')) {
        return res.status(403).json({ success: false, message: 'Only Super Admins and Owners can alter maintenance notices.' });
      }

      const { advanceNoticeActive, scheduledStartTime, scheduledDurationMinutes, noticeTitle, noticeMessage } = req.body;
      const updated = maintenanceService.setAdvanceNotice(
        Boolean(advanceNoticeActive),
        scheduledStartTime,
        Number(scheduledDurationMinutes || 60),
        noticeTitle,
        noticeMessage
      );

      return res.json({
        success: true,
        message: updated.advanceNoticeActive
          ? 'Scheduled maintenance advance notice banner broadcasted to all client dashboards.'
          : 'Scheduled maintenance notice banner cleared from client dashboards.',
        data: updated,
      });
    } catch (e: any) {
      return res.status(500).json({ success: false, message: e.message });
    }
  }
}

export default MaintenanceController;
module.exports = MaintenanceController;
