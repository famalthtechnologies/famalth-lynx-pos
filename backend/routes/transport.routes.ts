import { Router } from 'express';
import { TransportController } from '../controllers/inventory/transport.controller';
const auth = require('../middlewares/auth.middleware');

const router = Router();

router.use(auth);

// Vehicle endpoints
router.get('/vehicles', TransportController.listVehicles);
router.post('/vehicles', TransportController.createVehicle);
router.put('/vehicles/:id', TransportController.updateVehicle);
router.delete('/vehicles/:id', TransportController.deleteVehicle);

// Driver endpoints
router.get('/drivers', TransportController.listDrivers);
router.post('/drivers', TransportController.createDriver);
router.put('/drivers/:id', TransportController.updateDriver);
router.delete('/drivers/:id', TransportController.deleteDriver);

// Trip & Delivery Challan Logistics endpoints
router.post('/assign-trip', TransportController.assignTrip);
router.post('/verify-delivery', TransportController.verifyDelivery);
router.post('/release-trip', TransportController.releaseTrip);
router.get('/active-trips', TransportController.getActiveTrips);

module.exports = router;
export default router;
