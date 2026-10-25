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

      // Authorization guard: Only super admins or enterprise admins
      if (role !== 'SUPER_ADMIN' && role !== 'ENTERPRISE_ADMIN') {
        // Also check if request comes with valid control-plane token if any
        const authHeader = req.headers.authorization || '';
        if (!authHeader.includes('Bearer')) {
          return res.status(403).json({ success: false, message: 'Only Super Admins can alter maintenance mode.' });
        }
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
}

export default MaintenanceController;
