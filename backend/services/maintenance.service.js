"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.maintenanceService = void 0;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const rootDir = process.pkg ? path_1.default.dirname(process.execPath) : process.cwd();
const STATE_FILE = path_1.default.join(rootDir, 'maintenance_state.json');
class MaintenanceService {
    static instance;
    state;
    constructor() {
        this.state = this.loadState();
    }
    static getInstance() {
        if (!MaintenanceService.instance) {
            MaintenanceService.instance = new MaintenanceService();
        }
        return MaintenanceService.instance;
    }
    loadState() {
        try {
            if (fs_1.default.existsSync(STATE_FILE)) {
                const raw = fs_1.default.readFileSync(STATE_FILE, 'utf8');
                const parsed = JSON.parse(raw);
                return {
                    isActive: Boolean(parsed.isActive),
                    title: parsed.title || 'System Under Scheduled Maintenance',
                    message: parsed.message || 'Scheduled system optimization is in progress. Store operations are temporarily paused.',
                    startedAt: parsed.startedAt || null,
                    durationMinutes: Number(parsed.durationMinutes || 30),
                    estimatedEndTime: parsed.estimatedEndTime || null,
                    remainingMinutes: 0,
                    enabledBy: parsed.enabledBy || 'Super Admin',
                };
            }
        }
        catch (_) { }
        return {
            isActive: false,
            title: 'System Under Scheduled Maintenance',
            message: 'Scheduled system optimization is in progress. Store operations are temporarily paused.',
            startedAt: null,
            durationMinutes: 30,
            estimatedEndTime: null,
            remainingMinutes: 0,
            enabledBy: 'Super Admin',
        };
    }
    saveState() {
        try {
            fs_1.default.writeFileSync(STATE_FILE, JSON.stringify(this.state, null, 2), 'utf8');
        }
        catch (e) {
            console.error('[MaintenanceService] Failed to save state:', e);
        }
    }
    getStatus() {
        if (this.state.isActive && this.state.estimatedEndTime) {
            const now = Date.now();
            const end = new Date(this.state.estimatedEndTime).getTime();
            const diffMs = end - now;
            if (diffMs <= 0) {
                // Auto-expire maintenance window
                this.state.isActive = false;
                this.saveState();
            }
            else {
                this.state.remainingMinutes = Math.max(1, Math.ceil(diffMs / (60 * 1000)));
            }
        }
        else {
            this.state.remainingMinutes = 0;
        }
        return { ...this.state };
    }
    setMaintenance(isActive, title, message, durationMinutes = 30, enabledBy = 'Super Admin') {
        const now = new Date();
        const endTime = new Date(now.getTime() + durationMinutes * 60 * 1000);
        this.state = {
            isActive,
            title: title || 'System Under Scheduled Maintenance',
            message: message || 'Scheduled system optimization is in progress. Store operations are temporarily paused.',
            startedAt: isActive ? now.toISOString() : null,
            durationMinutes: durationMinutes > 0 ? durationMinutes : 30,
            estimatedEndTime: isActive ? endTime.toISOString() : null,
            remainingMinutes: isActive ? durationMinutes : 0,
            enabledBy,
        };
        this.saveState();
        return { ...this.state };
    }
    isUnderMaintenance() {
        return this.getStatus().isActive;
    }
}
exports.maintenanceService = MaintenanceService.getInstance();
exports.default = exports.maintenanceService;
