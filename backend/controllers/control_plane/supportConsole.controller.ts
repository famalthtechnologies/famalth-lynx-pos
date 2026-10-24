import { Request, Response } from 'express';
import { Op } from 'sequelize';
import propertyDb from '../../db/propertyDb';
import initMasterModels from '../../models/master';
import DataDoctorService from '../../services/dataDoctor.service';
import { broadcastNewSupportTicket, broadcastTicketMessage } from '../../services/socketHub.service';
import { extractSchemaFromMigrations, extractSchemaFromDatabase } from '../../utils/migrationSchemaExtractor';
import { sendEmail } from '../../modules/emailService';

const {
  MasterTenant,
  MasterOutlet,
  SupportAgent,
  SupportTicket,
  TicketMessage,
  DiagnosticQueryAuditLog,
} = initMasterModels(propertyDb);

export class SupportConsoleController {
  /**
   * 1. Raise a Support Request / Ticket (from Retailer or Restaurant POS terminal)
   */
  public static async createTicket(req: Request, res: Response) {
    try {
      const {
        tenant_id,
        outlet_id,
        outlet_code,
        subject,
        priority,
        initial_message,
        client_telemetry,
        sender_name,
      } = req.body;

      if (!subject) {
        return res.status(400).json({ success: false, message: 'Subject is required.' });
      }

      // Resolve tenant and outlet
      let resolvedTenantId = tenant_id;
      let resolvedOutletId = outlet_id;

      if (!resolvedTenantId && outlet_code) {
        const outlet = await MasterOutlet.findOne({ where: { outlet_code } });
        if (outlet) {
          resolvedTenantId = outlet.tenant_id;
          resolvedOutletId = outlet.id;
        }
      }

      if (!resolvedTenantId) {
        // Fallback to first active tenant
        const firstTenant = await MasterTenant.findOne({ where: { status: 'ACTIVE' } });
        resolvedTenantId = firstTenant?.id;
      }

      if (!resolvedOutletId) {
        resolvedOutletId = 1;
      }

      // Auto-Assignment Engine: Find online support agent with lowest active ticket count
      let assignedAgent = await SupportAgent.findOne({
        where: { is_online: true },
        order: [['active_ticket_count', 'ASC']],
      });

      // If no online agent, pick any agent with lowest active load
      if (!assignedAgent) {
        assignedAgent = await SupportAgent.findOne({
          order: [['active_ticket_count', 'ASC']],
        });
      }

      const ticketNumber = `TCK-${Date.now().toString(36).toUpperCase()}`;

      const ticket = await SupportTicket.create({
        ticket_number: ticketNumber,
        tenant_id: resolvedTenantId,
        outlet_id: Number(resolvedOutletId),
        subject,
        priority: priority || 'MEDIUM',
        status: assignedAgent ? 'ASSIGNED' : 'OPEN',
        assigned_agent_id: assignedAgent?.id || null,
        client_telemetry: client_telemetry || {},
      });

      // Increment agent load if assigned
      if (assignedAgent) {
        assignedAgent.active_ticket_count = (assignedAgent.active_ticket_count || 0) + 1;
        await assignedAgent.save();
      }

      // Create initial conversation message
      const firstMsg = await TicketMessage.create({
        ticket_id: ticket.id,
        sender_type: 'CLIENT_OUTLET',
        sender_name: sender_name || 'POS Terminal Operator',
        message: initial_message || subject,
        diagnostic_payload: client_telemetry || null,
      });

      // Fetch populated ticket for real-time notification
      const populatedTicket = await SupportTicket.findByPk(ticket.id, {
        include: [
          { model: MasterTenant, as: 'tenant', attributes: ['id', 'legal_name', 'client_code'] },
          { model: SupportAgent, as: 'agent', attributes: ['id', 'full_name', 'email', 'role_level'] },
        ],
      });

      // Broadcast real-time sound chime alert to all support staff in control panel
      broadcastNewSupportTicket(populatedTicket);

      return res.status(201).json({
        success: true,
        message: 'Ticket raised successfully.',
        data: populatedTicket,
      });
    } catch (err: any) {
      console.error('createTicket error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * 2. List all Tickets with outlet, tenant, and agent associations
   */
  public static async getTickets(req: Request, res: Response) {
    try {
      const { status, priority, outlet_id, tenant_id, agent_id, search } = req.query;

      const whereClause: any = {};
      if (status) whereClause.status = status;
      if (priority) whereClause.priority = priority;
      if (outlet_id) whereClause.outlet_id = outlet_id;
      if (tenant_id) whereClause.tenant_id = tenant_id;
      if (agent_id) whereClause.assigned_agent_id = agent_id;

      if (search) {
        whereClause[Op.or] = [
          { ticket_number: { [Op.iLike]: `%${search}%` } },
          { subject: { [Op.iLike]: `%${search}%` } },
        ];
      }

      const tickets = await SupportTicket.findAll({
        where: whereClause,
        include: [
          { model: MasterTenant, as: 'tenant', attributes: ['id', 'legal_name', 'client_code', 'contact_email', 'contact_phone'] },
          { model: MasterOutlet, as: 'outlet', attributes: ['id', 'outlet_code', 'outlet_name', 'city', 'state'] },
          { model: SupportAgent, as: 'agent', attributes: ['id', 'full_name', 'email', 'role_level', 'specialization', 'is_online'] },
          {
            model: TicketMessage,
            as: 'messages',
            attributes: ['id', 'sender_type', 'sender_name', 'message', 'is_read_by_support', 'created_at'],
          },
        ],
        order: [['created_at', 'DESC']],
      });

      const enrichedTickets = tickets.map((t: any) => {
        const plain = t.toJSON();
        const msgs = plain.messages || [];
        const lastMsg = msgs.length > 0 ? msgs[msgs.length - 1] : null;

        const isClosed = plain.status === 'RESOLVED' || plain.status === 'CLOSED';

        // Count only unread messages from client that support has NOT yet read
        let unseenCount = 0;
        if (!isClosed) {
          unseenCount = msgs.filter((m: any) => m.sender_type === 'CLIENT_OUTLET' && m.is_read_by_support !== true).length;
        }

        const isUnseen = !isClosed && (unseenCount > 0);

        const resolvedOutletCode = plain.outlet?.outlet_code || plain.client_telemetry?.outletCode || plain.tenant?.client_code || `OUTLET#${plain.outlet_id}`;
        const resolvedEmail = plain.client_email || plain.client_telemetry?.email || plain.tenant?.contact_email || '';
        const resolvedPhone = plain.client_telemetry?.phone || plain.tenant?.contact_phone || '';

        return {
          ...plain,
          outlet_code: resolvedOutletCode,
          contact_email: resolvedEmail,
          contact_phone: resolvedPhone,
          tenant_name: plain.tenant?.legal_name || plain.outlet?.outlet_name || 'Retail Store',
          has_unseen: isUnseen,
          unseen_count: unseenCount,
          last_message: lastMsg,
          total_messages: msgs.length,
        };
      });

      return res.json({ success: true, count: enrichedTickets.length, data: enrichedTickets });
    } catch (err: any) {
      console.error('getTickets error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * 3. Get detailed ticket info with conversation stream and query audit logs
   */
  public static async getTicketDetails(req: Request, res: Response) {
    try {
      const id = String(req.params.id);

      // Automatically mark client messages as read by support
      await TicketMessage.update(
        { is_read_by_support: true },
        { where: { ticket_id: id, sender_type: 'CLIENT_OUTLET', is_read_by_support: false } }
      );
      await SupportTicket.update(
        { last_read_by_support_at: new Date() },
        { where: { id } }
      );

      const ticket = await SupportTicket.findByPk(id, {
        include: [
          { model: MasterTenant, as: 'tenant' },
          { model: MasterOutlet, as: 'outlet' },
          { model: SupportAgent, as: 'agent' },
          {
            model: TicketMessage,
            as: 'messages',
            order: [['created_at', 'ASC']],
          },
          {
            model: DiagnosticQueryAuditLog,
            as: 'query_logs',
            order: [['executed_at', 'DESC']],
          },
        ],
      });

      if (!ticket) {
        return res.status(404).json({ success: false, message: 'Ticket not found.' });
      }

      const plain: any = ticket.toJSON();
      const resolvedOutletCode = plain.outlet?.outlet_code || plain.client_telemetry?.outletCode || plain.tenant?.client_code || `OUTLET#${plain.outlet_id}`;
      const resolvedEmail = plain.client_email || plain.client_telemetry?.email || plain.tenant?.contact_email || '';
      const resolvedPhone = plain.client_telemetry?.phone || plain.tenant?.contact_phone || '';

      return res.json({
        success: true,
        data: {
          ...plain,
          outlet_code: resolvedOutletCode,
          contact_email: resolvedEmail,
          contact_phone: resolvedPhone,
        },
      });
    } catch (err: any) {
      console.error('getTicketDetails error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * 4. Post Message / Reply in Ticket Chat (Real-time stream)
   */
  public static async postMessage(req: Request, res: Response) {
    try {
      const id = String(req.params.id); // ticket_id
      const { sender_type, sender_id, sender_name, message, diagnostic_payload, attachments } = req.body;

      const ticket = await SupportTicket.findByPk(id);
      if (!ticket) {
        return res.status(404).json({ success: false, message: 'Ticket not found.' });
      }

      // If ticket is resolved/closed, conversation is locked!
      if (ticket.status === 'RESOLVED' || ticket.status === 'CLOSED') {
        return res.status(400).json({
          success: false,
          message: 'Ticket is closed. Conversation is locked. Customer must open a new ticket.',
        });
      }

      const isSupportStaff = sender_type === 'SUPPORT_STAFF';

      const newMsg = await TicketMessage.create({
        ticket_id: ticket.id,
        sender_type: sender_type || 'SUPPORT_STAFF',
        sender_id: sender_id || null,
        sender_name: sender_name || (isSupportStaff ? 'Central Support Engineer' : 'Store Cashier / POS Operator'),
        message,
        diagnostic_payload: diagnostic_payload || null,
        attachments: attachments || [],
        is_read_by_support: isSupportStaff ? true : false,
      });

      // Update ticket status to IN_PROGRESS if OPEN
      if (ticket.status === 'OPEN' || ticket.status === 'ASSIGNED') {
        ticket.status = 'IN_PROGRESS';
        await ticket.save();
      }

      // Broadcast live to ticket WebSocket room
      broadcastTicketMessage(ticket.id, newMsg);

      return res.status(201).json({ success: true, data: newMsg });
    } catch (err: any) {
      console.error('postMessage error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * 5. Resolve / Close Ticket Outlet-Wise
   */
  public static async resolveTicket(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const { resolution_summary } = req.body;

      const ticket = await SupportTicket.findByPk(id, {
        include: [
          { model: MasterTenant, as: 'tenant' },
          { model: MasterOutlet, as: 'outlet' },
        ],
      });

      if (!ticket) {
        return res.status(404).json({ success: false, message: 'Ticket not found.' });
      }

      ticket.status = 'CLOSED';
      ticket.resolution_summary = resolution_summary || 'Resolved via Central Control Desk.';
      ticket.resolved_at = new Date();
      await ticket.save();

      // Mark all messages as read
      await TicketMessage.update(
        { is_read_by_support: true },
        { where: { ticket_id: ticket.id } }
      );

      // Decrement agent active ticket load
      if (ticket.assigned_agent_id) {
        const agent = await SupportAgent.findByPk(ticket.assigned_agent_id);
        if (agent && agent.active_ticket_count > 0) {
          agent.active_ticket_count -= 1;
          await agent.save();
        }
      }

      const plain = (ticket as any).toJSON();
      const resolvedOutletCode = plain.outlet?.outlet_code || plain.client_telemetry?.outletCode || plain.tenant?.client_code || `OUTLET#${plain.outlet_id}`;
      const resolvedEmail = plain.client_email || plain.client_telemetry?.email || plain.tenant?.contact_email || '';

      // Add system message
      const closeMsg = await TicketMessage.create({
        ticket_id: ticket.id,
        sender_type: 'SYSTEM_BOT',
        sender_name: 'Famalth Lynx AI Core',
        message: `✅ Ticket #${ticket.ticket_number} marked as CLOSED for Outlet ${resolvedOutletCode}. Summary: ${ticket.resolution_summary}`,
        is_read_by_support: true,
      });

      broadcastTicketMessage(ticket.id, closeMsg);

      // Direct Email dispatch if requested
      if (req.body.send_email) {
        const toEmail = (req.body.recipient_email || resolvedEmail || '').trim();
        if (toEmail) {
          const emailSubject = req.body.email_subject || `[${ticket.ticket_number}] Support Resolved: ${ticket.subject}`;
          const emailBody = req.body.email_body || `Dear Customer (${resolvedOutletCode}),\n\nYour support ticket #${ticket.ticket_number} ("${ticket.subject}") has been marked as RESOLVED by Central Support.\n\nResolution Summary:\n${ticket.resolution_summary}\n\nThank you for choosing Retail POS,\nCentral Enterprise Support Team`;

          const htmlContent = `
            <div style="font-family: Arial, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 8px; background-color: #ffffff;">
              <div style="background-color: #10b981; padding: 16px 20px; border-radius: 6px; color: #ffffff;">
                <h2 style="margin: 0; font-size: 18px; font-weight: 600;">Retail Support - Issue Resolved</h2>
                <p style="margin: 4px 0 0 0; font-size: 13px; color: #dcfce7;">Ticket #${ticket.ticket_number} • Outlet: ${resolvedOutletCode}</p>
              </div>
              <div style="padding: 24px 8px; color: #1e293b; font-size: 14px; line-height: 1.6; white-space: pre-wrap;">${emailBody}</div>
              <div style="border-top: 1px solid #e2e8f0; padding-top: 16px; color: #64748b; font-size: 12px;">
                <p style="margin: 0; font-weight: 600;">Central Support Desk & Control Automation</p>
                <p style="margin: 4px 0 0 0;">This email was sent directly from the Central Support System.</p>
              </div>
            </div>
          `;

          try {
            await sendEmail(toEmail, emailSubject, htmlContent);
            const emailMsg = await TicketMessage.create({
              ticket_id: ticket.id,
              sender_type: 'SYSTEM_BOT',
              sender_name: 'Famalth Lynx AI Core',
              message: `✉ Resolution notice emailed directly to ${toEmail}`,
              is_read_by_support: true,
            });
            broadcastTicketMessage(ticket.id, emailMsg);
          } catch (mailErr: any) {
            console.warn('[EMAIL WARNING] Failed to send resolution email:', mailErr.message);
          }
        }
      }

      return res.json({
        success: true,
        message: 'Ticket closed successfully.',
        data: {
          ...plain,
          outlet_code: resolvedOutletCode,
          contact_email: resolvedEmail,
        },
      });
    } catch (err: any) {
      console.error('resolveTicket error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * 5b. Direct Email Sender (Dispatches directly via Central Mail Service)
   */
  public static async sendTicketEmail(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const { to, subject, message } = req.body;

      if (!to || !to.trim()) {
        return res.status(400).json({ success: false, message: 'Recipient email address is required.' });
      }

      const ticket = await SupportTicket.findByPk(id, {
        include: [
          { model: MasterTenant, as: 'tenant' },
          { model: MasterOutlet, as: 'outlet' },
        ],
      });

      if (!ticket) {
        return res.status(404).json({ success: false, message: 'Ticket not found.' });
      }

      const plain = (ticket as any).toJSON();
      const resolvedOutletCode = plain.outlet?.outlet_code || plain.client_telemetry?.outletCode || plain.tenant?.client_code || `OUTLET#${plain.outlet_id}`;
      const emailSubject = (subject || `[${ticket.ticket_number}] Support Update: ${ticket.subject}`).trim();
      const emailBody = (message || '').trim();

      const htmlContent = `
        <div style="font-family: Arial, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 8px; background-color: #ffffff;">
          <div style="background-color: #0284c7; padding: 16px 20px; border-radius: 6px; color: #ffffff;">
            <h2 style="margin: 0; font-size: 18px; font-weight: 600;">Retail Support Desk</h2>
            <p style="margin: 4px 0 0 0; font-size: 13px; color: #e0f2fe;">Ticket #${ticket.ticket_number} • Outlet: ${resolvedOutletCode}</p>
          </div>
          <div style="padding: 24px 8px; color: #1e293b; font-size: 14px; line-height: 1.6; white-space: pre-wrap;">${emailBody}</div>
          <div style="border-top: 1px solid #e2e8f0; padding-top: 16px; color: #64748b; font-size: 12px;">
            <p style="margin: 0; font-weight: 600;">Central Support Desk & Control Automation</p>
            <p style="margin: 4px 0 0 0;">This email was sent directly from the Central Support System.</p>
          </div>
        </div>
      `;

      await sendEmail(to.trim(), emailSubject, htmlContent);

      const sysMsg = await TicketMessage.create({
        ticket_id: ticket.id,
        sender_type: 'SYSTEM_BOT',
        sender_name: 'Famalth Lynx AI Core',
        message: `✉ Email sent directly to ${to.trim()} with subject "${emailSubject}"`,
        is_read_by_support: true,
      });

      broadcastTicketMessage(ticket.id, sysMsg);

      return res.json({
        success: true,
        message: `Email sent successfully to ${to.trim()}`,
      });
    } catch (err: any) {
      console.error('sendTicketEmail error:', err);
      return res.status(500).json({ success: false, message: `Failed to send email: ${err.message}` });
    }
  }

  /**
   * 6. Automated Diagnostic Error & Query Analyzer (Identify Root Cause & Suggest Solutions)
   */
  public static async analyzeDiagnosticError(req: Request, res: Response) {
    try {
      const { error_text, stack_trace, query_snippet } = req.body;
      const combined = `${error_text || ''}\n${stack_trace || ''}\n${query_snippet || ''}`;

      let identifiedCategory = 'UNKNOWN';
      let rootCause = 'General runtime anomaly.';
      let recommendedResolution = 'Review system logs and verify configuration parameters.';

      if (/column.*does not exist/i.test(combined)) {
        identifiedCategory = 'DATABASE_SCHEMA_DRIFT';
        const colMatch = combined.match(/column ["']?([a-zA-Z0-9_]+)["']? does not exist/i);
        rootCause = `Missing column in PostgreSQL schema: '${colMatch ? colMatch[1] : 'unknown'}'.`;
        recommendedResolution = 'Execute automated database migration or use Data Doctor to verify ALTER TABLE.';
      } else if (/violates foreign key constraint/i.test(combined)) {
        identifiedCategory = 'FOREIGN_KEY_VIOLATION';
        rootCause = 'Referential integrity breach. Parent row does not exist.';
        recommendedResolution = 'Verify parent table record before inserting child items, or check outlet_id mapping.';
      } else if (/deadlock detected|could not obtain lock/i.test(combined)) {
        identifiedCategory = 'TRANSACTION_LOCK_CONTENTION';
        rootCause = 'Concurrent read/write contention on high-frequency tables (e.g. sales_headers, stock_ledger).';
        recommendedResolution = 'Ensure row-level locks are released or configure optimistic concurrency retry.';
      } else if (/connection refused|ECONNREFUSED|getaddrinfo/i.test(combined)) {
        identifiedCategory = 'NETWORK_CONNECTIVITY_FAULT';
        rootCause = 'Socket connection failure to database or external API gateway.';
        recommendedResolution = 'Verify local network routing, firewall rules, and PostgreSQL service status.';
      } else if (/syntax error at or near/i.test(combined)) {
        identifiedCategory = 'SQL_SYNTAX_ERROR';
        rootCause = 'Malformed SQL query structure.';
        recommendedResolution = 'Validate SQL statement syntax against PostgreSQL 15/16 parser.';
      }

      return res.json({
        success: true,
        data: {
          category: identifiedCategory,
          rootCause,
          recommendedResolution,
          confidenceScore: 0.94,
          timestamp: new Date(),
        },
      });
    } catch (err: any) {
      console.error('analyzeDiagnosticError error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * 7. Sandboxed Data Doctor SQL Execution (Tenant-Isolated, Outlet-Scoped, Mandatory WHERE Enforced)
   */
  public static async executeDataDoctorQuery(req: Request, res: Response) {
    try {
      const { sql, ticket_id, tenant_id, outlet_id, agent_id } = req.body;

      if (!sql) {
        return res.status(400).json({ success: false, message: 'SQL query cannot be empty.' });
      }

      let targetTenantId = tenant_id;
      let targetOutletId = Number(outlet_id || 1);

      // If ticket_id provided, lock scope strictly to the ticket's tenant and outlet
      if (ticket_id) {
        const ticket = await SupportTicket.findByPk(ticket_id);
        if (ticket) {
          targetTenantId = ticket.tenant_id;
          targetOutletId = Number(ticket.outlet_id);
        }
      }

      if (!targetTenantId) {
        const firstTenant = await MasterTenant.findOne({ where: { status: 'ACTIVE' } });
        targetTenantId = firstTenant?.id;
      }

      const result = await DataDoctorService.executeScopedDiagnosticQuery({
        rawSql: sql,
        ticketId: ticket_id,
        agentId: agent_id,
        tenantId: targetTenantId,
        outletId: targetOutletId,
      });

      if (!result.success) {
        return res.status(422).json({
          success: false,
          error: result.error,
          enforcedGuard: true,
        });
      }

      return res.json({
        success: true,
        message: `Query executed safely in Data Doctor sandbox (Scoped to Outlet #${targetOutletId}).`,
        data: result,
      });
    } catch (err: any) {
      console.error('executeDataDoctorQuery error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * 8. List Support Agents and toggle online status
   */
  public static async getSupportAgents(req: Request, res: Response) {
    try {
      let agents = await SupportAgent.findAll({
        attributes: ['id', 'full_name', 'email', 'role_level', 'is_online', 'active_ticket_count', 'max_concurrent_tickets', 'specialization'],
        order: [['is_online', 'DESC'], ['active_ticket_count', 'ASC']],
      });

      if (!agents || agents.length === 0) {
        await SupportAgent.create({
          full_name: 'L2 Diagnostic Support Lead',
          email: 'support.lead@famalth.com',
          role_level: 'L2',
          is_online: true,
          active_ticket_count: 0,
          max_concurrent_tickets: 5,
          specialization: 'SQL_DATA_DOCTOR',
        });
        agents = await SupportAgent.findAll({
          attributes: ['id', 'full_name', 'email', 'role_level', 'is_online', 'active_ticket_count', 'max_concurrent_tickets', 'specialization'],
          order: [['is_online', 'DESC'], ['active_ticket_count', 'ASC']],
        });
      }

      // Recalculate live active ticket load for each agent
      const enrichedAgents = await Promise.all(
        agents.map(async (agent: any) => {
          const plain = agent.toJSON();
          const liveActiveCount = await SupportTicket.count({
            where: {
              assigned_agent_id: plain.id,
              status: { [Op.in]: ['OPEN', 'IN_PROGRESS', 'ASSIGNED'] },
            },
          });
          plain.active_ticket_count = liveActiveCount;
          return plain;
        })
      );

      return res.json({ success: true, data: enrichedAgents });
    } catch (err: any) {
      return res.status(500).json({ success: false, message: err.message });
    }
  }

  public static async toggleAgentOnline(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const { is_online } = req.body;

      const agent = await SupportAgent.findByPk(id);
      if (!agent) {
        return res.status(404).json({ success: false, message: 'Agent not found.' });
      }

      agent.is_online = is_online;
      await agent.save();

      return res.json({ success: true, message: `Agent status updated to ${is_online ? 'ONLINE' : 'OFFLINE'}.`, data: agent });
    } catch (err: any) {
      return res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * 9. Get System Database Schema Extracted from Migrations
   * Serves all tables, columns, data types, keys, and business descriptions
   */
  public static async getSystemSchema(req: Request, res: Response) {
    try {
      const activeDb = (req as any).propertyDb || propertyDb;
      const schema = await extractSchemaFromDatabase(activeDb);
      return res.json({
        success: true,
        message: `Database schema successfully extracted (${schema.totalTables} tables, ${schema.totalColumns} columns).`,
        data: schema,
      });
    } catch (err: any) {
      console.error('getSystemSchema error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }
  }
}

export default SupportConsoleController;
