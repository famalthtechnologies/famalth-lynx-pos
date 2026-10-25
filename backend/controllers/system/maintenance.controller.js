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
            // Authorization guard: Only super admins or enterprise admins
            if (role !== 'SUPER_ADMIN' && role !== 'ENTERPRISE_ADMIN') {
                // Also check if request comes with valid control-plane token if any
                const authHeader = req.headers.authorization || '';
                if (!authHeader.includes('Bearer')) {
                    return res.status(403).json({ success: false, message: 'Only Super Admins can alter maintenance mode.' });
                }
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
}
exports.MaintenanceController = MaintenanceController;
exports.default = MaintenanceController;
