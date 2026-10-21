import { Sequelize } from 'sequelize';
import defineReseller from './resellers.model';
import defineRelationshipManager from './relationshipManagers.model';
import defineTenant from './tenants.model';
import defineOutlet from './outlets.model';
import defineLicense from './licenses.model';
import defineSupportAgent from './supportAgents.model';
import defineSupportTicket from './supportTickets.model';
import defineTicketMessage from './ticketMessages.model';
import defineDiagnosticQueryAuditLog from './diagnosticQueryAuditLogs.model';
import defineMasterStaffUser from './masterStaffUsers.model';
import defineMasterInvoice from './invoices.model';
import defineMasterAnnouncement from './announcements.model';

export function initMasterModels(sequelize: Sequelize) {
  const MasterReseller = defineReseller(sequelize);
  const MasterRelationshipManager = defineRelationshipManager(sequelize);
  const MasterTenant = defineTenant(sequelize);
  const MasterOutlet = defineOutlet(sequelize);
  const MasterLicense = defineLicense(sequelize);
  const SupportAgent = defineSupportAgent(sequelize);
  const SupportTicket = defineSupportTicket(sequelize);
  const TicketMessage = defineTicketMessage(sequelize);
  const DiagnosticQueryAuditLog = defineDiagnosticQueryAuditLog(sequelize);
  const MasterStaffUser = defineMasterStaffUser(sequelize);
  const MasterInvoice = defineMasterInvoice(sequelize);
  const MasterAnnouncement = defineMasterAnnouncement(sequelize);

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

(initMasterModels as any).default = initMasterModels;
module.exports = initMasterModels;
export default initMasterModels;

