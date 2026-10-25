const express = require('express');
const router = express.Router();
const auth = require('../middlewares/auth.middleware');
const clinicCtrl = require('../controllers/clinic/clinic.controller');

router.use(auth);

// Appointments
router.get('/appointments', clinicCtrl.getAppointments);
router.post('/appointments', clinicCtrl.createAppointment);
router.patch('/appointments/:id/status', clinicCtrl.updateAppointmentStatus);
router.post('/appointments/:id/prescription', clinicCtrl.savePrescription);
router.post('/appointments/:id/send-to-billing', clinicCtrl.sendToBillingDraft);

// Stock medicines for doctor consultation
router.get('/medicines', clinicCtrl.getAvailableMedicines);

// Clinic reports & analytics
router.get('/analytics', clinicCtrl.getClinicAnalytics);

module.exports = router;
