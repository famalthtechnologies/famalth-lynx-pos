import { Router } from 'express';
import MaintenanceController from '../controllers/system/maintenance.controller';

const router = Router();

// Public endpoint for clients to query maintenance state
router.get('/maintenance-status', MaintenanceController.getStatus);

// Admin endpoint to toggle and update maintenance window
router.post('/maintenance', MaintenanceController.setMaintenance);

export default router;
module.exports = router;
