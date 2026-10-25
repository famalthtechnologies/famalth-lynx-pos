import { Router } from 'express';
import MaintenanceController from '../controllers/system/maintenance.controller';

const router = Router();

// Public endpoint for clients to query maintenance state
router.get('/maintenance-status', MaintenanceController.getStatus);

// Admin endpoint to toggle and update maintenance window
router.post('/maintenance', MaintenanceController.setMaintenance);

// Admin endpoint to toggle and broadcast advance warning notice banner
router.post('/maintenance/advance-notice', MaintenanceController.setAdvanceNotice);

export default router;
module.exports = router;
