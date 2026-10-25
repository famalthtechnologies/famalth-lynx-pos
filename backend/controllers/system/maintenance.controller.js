"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MaintenanceController = void 0;
const maintenance_service_1 = __importDefault(require("../../services/maintenance.service"));
class MaintenanceController {
    /**
     * GET /api/system/maintenance-status
     * Public endpoint to check live maintenance state
     */
    static async getStatus(req, res) {
        try {
            const status = maintenance_service_1.default.getStatus();
            return res.json({
                success: true,
                data: status,
            });
        }
        catch (e) {
            return res.status(500).json({ success: false, message: e.message });
        }
    }
    /**
     * POST /api/system/maintenance
     * Toggle maintenance on/off and set duration/message
     */
    static async setMaintenance(req, res) {
        try {
            const user = req.user;
            const role = String(user?.role || '').toUpperCase();
            const isConsole = req.headers['x-client-type'] === 'enterprise-console' || req.headers['x-control-plane'] === 'true';
            const authHeader = req.headers.authorization || '';
            const allowedRoles = ['SUPER_ADMIN', 'ENTERPRISE_ADMIN', 'OWNER', 'DEVELOPER'];
            if (!isConsole && !allowedRoles.includes(role) && !authHeader.includes('Bearer')) {
                return res.status(403).json({ success: false, message: 'Only Super Admins and Owners can alter maintenance mode.' });
            }
            const { isActive, title, message, durationMinutes } = req.body;
            const updated = maintenance_service_1.default.setMaintenance(Boolean(isActive), title, message, Number(durationMinutes || 30), user?.username || 'Super Admin');
            return res.json({
                success: true,
                message: updated.isActive
                    ? `System maintenance activated for ${updated.durationMinutes} minutes. All store terminals paused.`
                    : 'System maintenance disabled. All store terminals resumed.',
                data: updated,
            });
        }
        catch (e) {
            return res.status(500).json({ success: false, message: e.message });
        }
    }
    /**
     * POST /api/system/maintenance/advance-notice
     * Toggle advance notice warning banner on/off (Render / Vercel / Bank style)
     */
    static async setAdvanceNotice(req, res) {
        try {
            const user = req.user;
            const role = String(user?.role || '').toUpperCase();
            const isConsole = req.headers['x-client-type'] === 'enterprise-console' || req.headers['x-control-plane'] === 'true';
            const authHeader = req.headers.authorization || '';
            const allowedRoles = ['SUPER_ADMIN', 'ENTERPRISE_ADMIN', 'OWNER', 'DEVELOPER'];
            if (!isConsole && !allowedRoles.includes(role) && !authHeader.includes('Bearer')) {
                return res.status(403).json({ success: false, message: 'Only Super Admins and Owners can alter maintenance notices.' });
            }
            const { advanceNoticeActive, scheduledStartTime, scheduledDurationMinutes, noticeTitle, noticeMessage } = req.body;
            const updated = maintenance_service_1.default.setAdvanceNotice(Boolean(advanceNoticeActive), scheduledStartTime, Number(scheduledDurationMinutes || 60), noticeTitle, noticeMessage);
            return res.json({
                success: true,
                message: updated.advanceNoticeActive
                    ? 'Scheduled maintenance advance notice banner broadcasted to all client dashboards.'
                    : 'Scheduled maintenance notice banner cleared from client dashboards.',
                data: updated,
            });
        }
        catch (e) {
            return res.status(500).json({ success: false, message: e.message });
        }
    }
}
exports.MaintenanceController = MaintenanceController;
exports.default = MaintenanceController;
module.exports = MaintenanceController;
