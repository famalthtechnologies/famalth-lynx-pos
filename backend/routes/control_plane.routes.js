"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const controlPlane_controller_1 = __importDefault(require("../controllers/control_plane/controlPlane.controller"));
const supportConsole_controller_1 = __importDefault(require("../controllers/control_plane/supportConsole.controller"));
const staffManagement_controller_1 = __importDefault(require("../controllers/control_plane/staffManagement.controller"));
const maintenance_controller_1 = __importDefault(require("../controllers/system/maintenance.controller"));
const controlPlaneAuth_middleware_1 = require("../middlewares/controlPlaneAuth.middleware");
const router = express_1.default.Router();
/* ==========================================================================
   AUTHENTICATION & IAM (Exclusively for Developers, Resellers, and Master Admins)
   ========================================================================== */
// 0. First-Time Installation & Setup Bootstrap (Air-Gapped Setup)
router.get('/auth/setup-status', staffManagement_controller_1.default.getSetupStatus);
router.post('/auth/request-owner-setup-otp', staffManagement_controller_1.default.requestOwnerSetupOtp);
router.post('/auth/initialize-master', staffManagement_controller_1.default.initializeMasterOwner);
// 1. Separate Login for Master Control Plane (Non-client)
router.post('/auth/login', staffManagement_controller_1.default.login);
router.post('/auth/verify-login-otp', staffManagement_controller_1.default.verifyLoginOtp);
router.post('/auth/resend-login-otp', staffManagement_controller_1.default.resendLoginOtp);
// Password recovery & Reset (OTP / Email)
router.post('/auth/recover-username', staffManagement_controller_1.default.recoverUsername);
router.post('/auth/forgot-password/request-otp', staffManagement_controller_1.default.requestPasswordResetOtp);
router.post('/auth/forgot-password/verify-and-reset', staffManagement_controller_1.default.verifyAndResetPassword);
router.post('/auth/change-password', controlPlaneAuth_middleware_1.requireControlPlaneAuth, staffManagement_controller_1.default.changePassword);
router.post('/staff/:id/reset-password', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN']), staffManagement_controller_1.default.adminResetStaffPassword);
// 2. Current Staff Profile
router.get('/auth/me', controlPlaneAuth_middleware_1.requireControlPlaneAuth, staffManagement_controller_1.default.getProfile);
// 3. Master Staff & Operator IAM Management
router.get('/staff', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN', 'DEVELOPER']), staffManagement_controller_1.default.listStaff);
router.post('/staff', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN']), staffManagement_controller_1.default.createStaff);
router.put('/staff/:id', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN']), staffManagement_controller_1.default.updateStaffRole);
router.patch('/staff/:id/status', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN']), staffManagement_controller_1.default.toggleStaffStatus);
/* ==========================================================================
   FLEET & TENANT CONTROL ROUTES (Owner, Reseller, Developer)
   ========================================================================== */
// 1. Executive Fleet Overview
router.get('/fleet/overview', controlPlaneAuth_middleware_1.requireControlPlaneAuth, controlPlane_controller_1.default.getFleetOverview);
// 2. Tenants / Clients
router.get('/tenants', controlPlaneAuth_middleware_1.requireControlPlaneAuth, controlPlane_controller_1.default.getAllTenants);
router.patch('/tenants/:id/status', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN']), controlPlane_controller_1.default.updateTenantStatus);
router.post('/tenants/:tenantId/assign-rm', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN']), controlPlane_controller_1.default.assignRelationshipManager);
// 3. Outlets (Granular Kill-Switch & Activation)
router.get('/outlets', controlPlaneAuth_middleware_1.requireControlPlaneAuth, controlPlane_controller_1.default.getAllOutlets);
router.patch('/outlets/:outletId/status', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN', 'DEVELOPER']), controlPlane_controller_1.default.updateOutletStatus);
// 4. License Quota Management
router.post('/tenants/:tenantId/modify-license', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN']), controlPlane_controller_1.default.modifyLicenseQuota);
// 5. Dynamic Property Registration Handshake (From POS Terminal)
router.post('/register-property', controlPlane_controller_1.default.registerDynamicProperty);
// 6. Relationship Managers
router.get('/relationship-managers', controlPlaneAuth_middleware_1.requireControlPlaneAuth, controlPlane_controller_1.default.getRelationshipManagers);
router.post('/relationship-managers', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN']), controlPlane_controller_1.default.createRelationshipManager);
// 7. Client POS Status Check (License Countdown Banner & RM Profile - Called by Client POS)
router.get('/license-and-rm-status', controlPlane_controller_1.default.getLicenseAndRMStatus);
// 8. Invoices, Payments & Bulk Subscriptions
router.post('/check-expiry-notices', controlPlaneAuth_middleware_1.requireControlPlaneAuth, controlPlane_controller_1.default.triggerExpiryAndRenewalNotices);
router.post('/licenses/bulk-extend', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN']), controlPlane_controller_1.default.bulkExtendSubscriptions);
router.post('/licenses/approve-payment/:tenantId', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'RESELLER_ADMIN']), controlPlane_controller_1.default.approvePaymentAndExtend);
router.get('/invoices/download/:tenantId', controlPlane_controller_1.default.downloadInvoicePdf);
router.get('/invoices/download-by-id/:invoiceId', controlPlane_controller_1.default.downloadInvoicePdf);
router.get('/invoices/latest/:tenantId', controlPlane_controller_1.default.getLatestInvoice);
router.get('/renewals/export', controlPlane_controller_1.default.exportRenewalsCsv);
// 9. Announcements & Promotional Offers (Individual or Broadcast)
router.post('/announcements', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'OWNER', 'ENTERPRISE_ADMIN', 'RESELLER_ADMIN', 'DEVELOPER', 'SUPPORT_AGENT']), controlPlane_controller_1.default.createAnnouncement);
router.get('/announcements/active', controlPlane_controller_1.default.getActiveAnnouncements);
// 10. System Maintenance & Downtime Broadcast Aliases
router.get('/maintenance-status', maintenance_controller_1.default.getStatus);
router.post('/maintenance', maintenance_controller_1.default.setMaintenance);
router.post('/maintenance/advance-notice', maintenance_controller_1.default.setAdvanceNotice);
/* ==========================================================================
   SUPPORT CONSOLE & DATA DOCTOR ROUTES (Outlet-Wise Helpdesk & Query Studio)
   ========================================================================== */
// 1. Tickets (Outlet-Wise) - Client POS can create/view tickets; control plane staff view/resolve
router.post('/support/tickets', supportConsole_controller_1.default.createTicket);
router.get('/support/tickets', supportConsole_controller_1.default.getTickets);
router.get('/support/tickets/:id', supportConsole_controller_1.default.getTicketDetails);
router.post('/support/tickets/:id/messages', supportConsole_controller_1.default.postMessage);
router.post('/support/tickets/:id/resolve', controlPlaneAuth_middleware_1.requireControlPlaneAuth, supportConsole_controller_1.default.resolveTicket);
router.post('/support/tickets/:id/send-email', controlPlaneAuth_middleware_1.requireControlPlaneAuth, supportConsole_controller_1.default.sendTicketEmail);
// 2. Automated Diagnostic Error & Query Analyzer
router.post('/support/analyze-error', controlPlaneAuth_middleware_1.requireControlPlaneAuth, supportConsole_controller_1.default.analyzeDiagnosticError);
// 3. Sandboxed Data Doctor SQL Execution (Mandatory WHERE Clause Scoped to Client & Outlet)
router.post('/support/data-doctor/execute', controlPlaneAuth_middleware_1.requireControlPlaneAuth, (0, controlPlaneAuth_middleware_1.requireStaffRole)(['SUPER_ADMIN', 'DEVELOPER', 'SUPPORT_AGENT']), supportConsole_controller_1.default.executeDataDoctorQuery);
router.get('/support/data-doctor/schema', controlPlaneAuth_middleware_1.requireControlPlaneAuth, supportConsole_controller_1.default.getSystemSchema);
// 4. Support Agents (Public read for client helpdesk & master console; status changes staff authenticated)
router.get('/support/agents', supportConsole_controller_1.default.getSupportAgents);
router.patch('/support/agents/:id/status', controlPlaneAuth_middleware_1.requireControlPlaneAuth, supportConsole_controller_1.default.toggleAgentOnline);
module.exports = router;
exports.default = router;
