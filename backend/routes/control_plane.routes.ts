import express from 'express';
import ControlPlaneController from '../controllers/control_plane/controlPlane.controller';
import SupportConsoleController from '../controllers/control_plane/supportConsole.controller';
import StaffManagementController from '../controllers/control_plane/staffManagement.controller';
import { requireControlPlaneAuth, requireStaffRole } from '../middlewares/controlPlaneAuth.middleware';

const router = express.Router();

/* ==========================================================================
   AUTHENTICATION & IAM (Exclusively for Developers, Resellers, and Master Admins)
   ========================================================================== */
// 0. First-Time Installation & Setup Bootstrap (Air-Gapped Setup)
router.get('/auth/setup-status', StaffManagementController.getSetupStatus);
router.post('/auth/request-owner-setup-otp', StaffManagementController.requestOwnerSetupOtp);
router.post('/auth/initialize-master', StaffManagementController.initializeMasterOwner);

// 1. Separate Login for Master Control Plane (Non-client)
router.post('/auth/login', StaffManagementController.login);
router.post('/auth/verify-login-otp', StaffManagementController.verifyLoginOtp);
router.post('/auth/resend-login-otp', StaffManagementController.resendLoginOtp);

// Password recovery & Reset (OTP / Email)
router.post('/auth/recover-username', StaffManagementController.recoverUsername);
router.post('/auth/forgot-password/request-otp', StaffManagementController.requestPasswordResetOtp);
router.post('/auth/forgot-password/verify-and-reset', StaffManagementController.verifyAndResetPassword);
router.post('/auth/change-password', requireControlPlaneAuth, StaffManagementController.changePassword);
router.post('/staff/:id/reset-password', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN']), StaffManagementController.adminResetStaffPassword);

// 2. Current Staff Profile
router.get('/auth/me', requireControlPlaneAuth, StaffManagementController.getProfile);

// 3. Master Staff & Operator IAM Management
router.get('/staff', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN', 'DEVELOPER']), StaffManagementController.listStaff);
router.post('/staff', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN']), StaffManagementController.createStaff);
router.put('/staff/:id', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN']), StaffManagementController.updateStaffRole);
router.patch('/staff/:id/status', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN']), StaffManagementController.toggleStaffStatus);


/* ==========================================================================
   FLEET & TENANT CONTROL ROUTES (Owner, Reseller, Developer)
   ========================================================================== */
// 1. Executive Fleet Overview
router.get('/fleet/overview', requireControlPlaneAuth, ControlPlaneController.getFleetOverview);

// 2. Tenants / Clients
router.get('/tenants', requireControlPlaneAuth, ControlPlaneController.getAllTenants);
router.patch('/tenants/:id/status', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN']), ControlPlaneController.updateTenantStatus);
router.post('/tenants/:tenantId/assign-rm', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN']), ControlPlaneController.assignRelationshipManager);

// 3. Outlets (Granular Kill-Switch & Activation)
router.get('/outlets', requireControlPlaneAuth, ControlPlaneController.getAllOutlets);
router.patch('/outlets/:outletId/status', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN', 'DEVELOPER']), ControlPlaneController.updateOutletStatus);

// 4. License Quota Management
router.post('/tenants/:tenantId/modify-license', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN']), ControlPlaneController.modifyLicenseQuota);

// 5. Dynamic Property Registration Handshake (From POS Terminal)
router.post('/register-property', ControlPlaneController.registerDynamicProperty);

// 6. Relationship Managers
router.get('/relationship-managers', requireControlPlaneAuth, ControlPlaneController.getRelationshipManagers);
router.post('/relationship-managers', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN']), ControlPlaneController.createRelationshipManager);

// 7. Client POS Status Check (License Countdown Banner & RM Profile - Called by Client POS)
router.get('/license-and-rm-status', ControlPlaneController.getLicenseAndRMStatus);

// 8. Invoices, Payments & Bulk Subscriptions
router.post('/licenses/bulk-extend', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN']), ControlPlaneController.bulkExtendSubscriptions);
router.post('/licenses/approve-payment/:tenantId', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN']), ControlPlaneController.approvePaymentAndExtend);
router.get('/invoices/download/:tenantId', ControlPlaneController.downloadInvoicePdf);
router.get('/invoices/download-by-id/:invoiceId', ControlPlaneController.downloadInvoicePdf);
router.get('/invoices/latest/:tenantId', ControlPlaneController.getLatestInvoice);
router.get('/renewals/export', ControlPlaneController.exportRenewalsCsv);

// 9. Announcements & Promotional Offers (Individual or Broadcast)
router.post('/announcements', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'RESELLER_ADMIN', 'DEVELOPER', 'SUPPORT_AGENT']), ControlPlaneController.createAnnouncement);
router.get('/announcements/active', ControlPlaneController.getActiveAnnouncements);


/* ==========================================================================
   SUPPORT CONSOLE & DATA DOCTOR ROUTES (Outlet-Wise Helpdesk & Query Studio)
   ========================================================================== */
// 1. Tickets (Outlet-Wise) - Client POS can create/view tickets; control plane staff view/resolve
router.post('/support/tickets', SupportConsoleController.createTicket);
router.get('/support/tickets', SupportConsoleController.getTickets);
router.get('/support/tickets/:id', SupportConsoleController.getTicketDetails);
router.post('/support/tickets/:id/messages', SupportConsoleController.postMessage);
router.post('/support/tickets/:id/resolve', requireControlPlaneAuth, SupportConsoleController.resolveTicket);

// 2. Automated Diagnostic Error & Query Analyzer
router.post('/support/analyze-error', requireControlPlaneAuth, SupportConsoleController.analyzeDiagnosticError);

// 3. Sandboxed Data Doctor SQL Execution (Mandatory WHERE Clause Scoped to Client & Outlet)
router.post('/support/data-doctor/execute', requireControlPlaneAuth, requireStaffRole(['SUPER_ADMIN', 'DEVELOPER', 'SUPPORT_AGENT']), SupportConsoleController.executeDataDoctorQuery);
router.get('/support/data-doctor/schema', requireControlPlaneAuth, SupportConsoleController.getSystemSchema);

// 4. Support Agents
router.get('/support/agents', requireControlPlaneAuth, SupportConsoleController.getSupportAgents);
router.patch('/support/agents/:id/status', requireControlPlaneAuth, SupportConsoleController.toggleAgentOnline);

module.exports = router;
export default router;
