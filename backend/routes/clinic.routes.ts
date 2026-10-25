import express from 'express';
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
router.post('/appointments/:id/accept-and-pay', clinicCtrl.acceptAndPayAppointment);
router.patch('/appointments/:id/billing-complete', clinicCtrl.completeAppointmentBilling);
router.get('/patient-history', clinicCtrl.getClinicPatientHistory);
router.get('/clinical-tests', clinicCtrl.getClinicalTestsMaster);
router.post('/clinical-tests', clinicCtrl.saveClinicalTestMaster);

// Doctors management (Multi-doctor profiles & public display settings)
router.get('/doctors', clinicCtrl.getClinicDoctors);
router.post('/doctors', clinicCtrl.createClinicDoctor);
router.put('/doctors/:id', clinicCtrl.updateClinicDoctor);
router.delete('/doctors/:id', clinicCtrl.deleteClinicDoctor);

// Stock medicines for doctor consultation
router.get('/medicines', clinicCtrl.getAvailableMedicines);

// Clinic reports & analytics
router.get('/analytics', clinicCtrl.getClinicAnalytics);

// Therapy & Service Subscriptions
router.get('/subscriptions', clinicCtrl.getClinicSubscriptions);
router.post('/subscriptions', clinicCtrl.createClinicSubscription);
router.post('/subscriptions/:id/consume', clinicCtrl.consumeClinicSubscriptionSession);
router.get('/subscriptions/:id/ledger', clinicCtrl.getClinicSubscriptionLedger);

module.exports = router;
export default router;
