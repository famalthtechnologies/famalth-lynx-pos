"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.initMasterModels = initMasterModels;
const resellers_model_1 = __importDefault(require("./resellers.model"));
const relationshipManagers_model_1 = __importDefault(require("./relationshipManagers.model"));
const tenants_model_1 = __importDefault(require("./tenants.model"));
const outlets_model_1 = __importDefault(require("./outlets.model"));
const licenses_model_1 = __importDefault(require("./licenses.model"));
const supportAgents_model_1 = __importDefault(require("./supportAgents.model"));
const supportTickets_model_1 = __importDefault(require("./supportTickets.model"));
const ticketMessages_model_1 = __importDefault(require("./ticketMessages.model"));
const diagnosticQueryAuditLogs_model_1 = __importDefault(require("./diagnosticQueryAuditLogs.model"));
const masterStaffUsers_model_1 = __importDefault(require("./masterStaffUsers.model"));
const invoices_model_1 = __importDefault(require("./invoices.model"));
const announcements_model_1 = __importDefault(require("./announcements.model"));
function initMasterModels(sequelize) {
    const MasterReseller = (0, resellers_model_1.default)(sequelize);
    const MasterRelationshipManager = (0, relationshipManagers_model_1.default)(sequelize);
    const MasterTenant = (0, tenants_model_1.default)(sequelize);
    const MasterOutlet = (0, outlets_model_1.default)(sequelize);
    const MasterLicense = (0, licenses_model_1.default)(sequelize);
    const SupportAgent = (0, supportAgents_model_1.default)(sequelize);
    const SupportTicket = (0, supportTickets_model_1.default)(sequelize);
    const TicketMessage = (0, ticketMessages_model_1.default)(sequelize);
    const DiagnosticQueryAuditLog = (0, diagnosticQueryAuditLogs_model_1.default)(sequelize);
    const MasterStaffUser = (0, masterStaffUsers_model_1.default)(sequelize);
    const MasterInvoice = (0, invoices_model_1.default)(sequelize);
    const MasterAnnouncement = (0, announcements_model_1.default)(sequelize);
    // Tenant Relationships
    MasterTenant.belongsTo(MasterReseller, { foreignKey: 'reseller_id', as: 'reseller' });
    MasterReseller.hasMany(MasterTenant, { foreignKey: 'reseller_id', as: 'tenants' });
    // Invoices & Announcements
    MasterTenant.hasMany(MasterInvoice, { foreignKey: 'tenant_id', as: 'invoices' });
    MasterInvoice.belongsTo(MasterTenant, { foreignKey: 'tenant_id', as: 'tenant' });
    MasterTenant.hasMany(MasterAnnouncement, { foreignKey: 'target_tenant_id', as: 'announcements' });
    MasterAnnouncement.belongsTo(MasterTenant, { foreignKey: 'target_tenant_id', as: 'tenant' });
    // Staff User Relationships
    MasterStaffUser.belongsTo(MasterReseller, { foreignKey: 'reseller_id', as: 'reseller' });
    MasterReseller.hasMany(MasterStaffUser, { foreignKey: 'reseller_id', as: 'staff_members' });
    MasterTenant.belongsTo(MasterRelationshipManager, { foreignKey: 'rm_id', as: 'relationship_manager' });
    MasterRelationshipManager.hasMany(MasterTenant, { foreignKey: 'rm_id', as: 'tenants' });
    MasterTenant.hasMany(MasterOutlet, { foreignKey: 'tenant_id', as: 'outlets' });
    MasterOutlet.belongsTo(MasterTenant, { foreignKey: 'tenant_id', as: 'tenant' });
    MasterTenant.hasMany(MasterLicense, { foreignKey: 'tenant_id', as: 'licenses' });
    MasterLicense.belongsTo(MasterTenant, { foreignKey: 'tenant_id', as: 'tenant' });
    // Support Ticket Relationships
    MasterTenant.hasMany(SupportTicket, { foreignKey: 'tenant_id', as: 'tickets' });
    SupportTicket.belongsTo(MasterTenant, { foreignKey: 'tenant_id', as: 'tenant' });
    SupportAgent.hasMany(SupportTicket, { foreignKey: 'assigned_agent_id', as: 'assigned_tickets' });
    SupportTicket.belongsTo(SupportAgent, { foreignKey: 'assigned_agent_id', as: 'agent' });
    SupportTicket.hasMany(TicketMessage, { foreignKey: 'ticket_id', as: 'messages' });
    TicketMessage.belongsTo(SupportTicket, { foreignKey: 'ticket_id', as: 'ticket' });
    SupportTicket.hasMany(DiagnosticQueryAuditLog, { foreignKey: 'ticket_id', as: 'query_logs' });
    DiagnosticQueryAuditLog.belongsTo(SupportTicket, { foreignKey: 'ticket_id', as: 'ticket' });
    return {
        MasterReseller,
        MasterRelationshipManager,
        MasterTenant,
        MasterOutlet,
        MasterLicense,
        SupportAgent,
        SupportTicket,
        TicketMessage,
        DiagnosticQueryAuditLog,
        MasterStaffUser,
        MasterInvoice,
        MasterAnnouncement,
    };
}
initMasterModels.default = initMasterModels;
module.exports = initMasterModels;
exports.default = initMasterModels;
