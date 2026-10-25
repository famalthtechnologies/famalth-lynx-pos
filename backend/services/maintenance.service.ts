import fs from 'fs';
import path from 'path';

const rootDir = (process as any).pkg ? path.dirname(process.execPath) : process.cwd();
const STATE_FILE = path.join(rootDir, 'maintenance_state.json');

export interface MaintenanceStatus {
  isActive: boolean;
  title: string;
  message: string;
  startedAt: string | null;
  durationMinutes: number;
  estimatedEndTime: string | null;
  remainingMinutes: number;
  enabledBy: string;

  // Advance Notice Banner (Render / Vercel / Bank style top banner notice 1-2 days before)
  advanceNoticeActive: boolean;
  scheduledStartTime: string | null;
  scheduledDurationMinutes: number;
  noticeTitle: string;
  noticeMessage: string;
}

class MaintenanceService {
  private static instance: MaintenanceService;
  private state: MaintenanceStatus;

  private constructor() {
    this.state = this.loadState();
  }

  public static getInstance(): MaintenanceService {
    if (!MaintenanceService.instance) {
      MaintenanceService.instance = new MaintenanceService();
    }
    return MaintenanceService.instance;
  }

  private loadState(): MaintenanceStatus {
    try {
      if (fs.existsSync(STATE_FILE)) {
        const raw = fs.readFileSync(STATE_FILE, 'utf8');
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
          advanceNoticeActive: Boolean(parsed.advanceNoticeActive),
          scheduledStartTime: parsed.scheduledStartTime || null,
          scheduledDurationMinutes: Number(parsed.scheduledDurationMinutes || 60),
          noticeTitle: parsed.noticeTitle || 'Scheduled Cloud Maintenance Notice',
          noticeMessage: parsed.noticeMessage || 'Our cloud infrastructure will undergo scheduled maintenance. Store operations may be temporarily paused.',
        };
      }
    } catch (_) {}

    return {
      isActive: false,
      title: 'System Under Scheduled Maintenance',
      message: 'Scheduled system optimization is in progress. Store operations are temporarily paused.',
      startedAt: null,
      durationMinutes: 30,
      estimatedEndTime: null,
      remainingMinutes: 0,
      enabledBy: 'Super Admin',
      advanceNoticeActive: false,
      scheduledStartTime: null,
      scheduledDurationMinutes: 60,
      noticeTitle: 'Scheduled Cloud Maintenance Notice',
      noticeMessage: 'Our cloud infrastructure will undergo scheduled maintenance. Store operations may be temporarily paused.',
    };
  }

  private saveState() {
    try {
      fs.writeFileSync(STATE_FILE, JSON.stringify(this.state, null, 2), 'utf8');
    } catch (e) {
      console.error('[MaintenanceService] Failed to save state:', e);
    }
  }

  public getStatus(): MaintenanceStatus {
    if (this.state.isActive && this.state.estimatedEndTime) {
      const now = Date.now();
      const end = new Date(this.state.estimatedEndTime).getTime();
      const diffMs = end - now;

      if (diffMs <= 0) {
        // Auto-expire maintenance window
        this.state.isActive = false;
        this.saveState();
      } else {
        this.state.remainingMinutes = Math.max(1, Math.ceil(diffMs / (60 * 1000)));
      }
    } else {
      this.state.remainingMinutes = 0;
    }

    return { ...this.state };
  }

  public setMaintenance(
    isActive: boolean,
    title?: string,
    message?: string,
    durationMinutes: number = 30,
    enabledBy: string = 'Super Admin'
  ): MaintenanceStatus {
    const now = new Date();
    const endTime = new Date(now.getTime() + durationMinutes * 60 * 1000);

    this.state = {
      ...this.state,
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

  public setAdvanceNotice(
    advanceNoticeActive: boolean,
    scheduledStartTime?: string | null,
    scheduledDurationMinutes: number = 60,
    noticeTitle?: string,
    noticeMessage?: string
  ): MaintenanceStatus {
    this.state = {
      ...this.state,
      advanceNoticeActive: Boolean(advanceNoticeActive),
      scheduledStartTime: scheduledStartTime || null,
      scheduledDurationMinutes: Number(scheduledDurationMinutes || 60),
      noticeTitle: noticeTitle || this.state.noticeTitle || 'Scheduled Cloud Maintenance Notice',
      noticeMessage: noticeMessage || this.state.noticeMessage || 'Our cloud infrastructure will undergo scheduled maintenance. Store operations may be temporarily paused.',
    };

    this.saveState();
    return { ...this.state };
  }

  public isUnderMaintenance(): boolean {
    return this.getStatus().isActive;
  }
}

export const maintenanceService = MaintenanceService.getInstance();
export default maintenanceService;
