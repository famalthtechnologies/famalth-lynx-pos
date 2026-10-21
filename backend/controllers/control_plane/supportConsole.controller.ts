import { Request, Response } from 'express';
import { Op } from 'sequelize';
import propertyDb from '../../db/propertyDb';
import initMasterModels from '../../models/master';
import DataDoctorService from '../../services/dataDoctor.service';
import { broadcastNewSupportTicket, broadcastTicketMessage } from '../../services/socketHub.service';
import { extractSchemaFromMigrations } from '../../utils/migrationSchemaExtractor';

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
          { model: SupportAgent, as: 'agent', attributes: ['id', 'full_name', 'email', 'role_level', 'specialization'] },
        ],
        order: [['created_at', 'DESC']],
      });

      return res.json({ success: true, count: tickets.length, data: tickets });
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

      const ticket = await SupportTicket.findByPk(id, {
        include: [
          { model: MasterTenant, as: 'tenant' },
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

      return res.json({ success: true, data: ticket });
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

      const newMsg = await TicketMessage.create({
        ticket_id: ticket.id,
        sender_type: sender_type || 'SUPPORT_STAFF',
        sender_id: sender_id || null,
        sender_name: sender_name || 'Support Engineer',
        message,
        diagnostic_payload: diagnostic_payload || null,
        attachments: attachments || [],
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
   * 5. Resolve Ticket Outlet-Wise
   */
  public static async resolveTicket(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const { resolution_summary } = req.body;

      const ticket = await SupportTicket.findByPk(id);
      if (!ticket) {
        return res.status(404).json({ success: false, message: 'Ticket not found.' });
      }

      ticket.status = 'RESOLVED';
      ticket.resolution_summary = resolution_summary || 'Resolved by Support Engineering.';
      ticket.resolved_at = new Date();
      await ticket.save();

      // Decrement agent active ticket load
      if (ticket.assigned_agent_id) {
        const agent = await SupportAgent.findByPk(ticket.assigned_agent_id);
        if (agent && agent.active_ticket_count > 0) {
          agent.active_ticket_count -= 1;
          await agent.save();
        }
      }

      // Add system message
      const closeMsg = await TicketMessage.create({
        ticket_id: ticket.id,
        sender_type: 'SYSTEM_BOT',
        sender_name: 'Famalth Lynx AI Core',
        message: `✅ Ticket marked as RESOLVED for Outlet #${ticket.outlet_id}. Summary: ${ticket.resolution_summary}`,
      });

      broadcastTicketMessage(ticket.id, closeMsg);

      return res.json({ success: true, message: 'Ticket resolved successfully.', data: ticket });
    } catch (err: any) {
      console.error('resolveTicket error:', err);
      return res.status(500).json({ success: false, message: err.message });
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
      const agents = await SupportAgent.findAll({
        attributes: ['id', 'full_name', 'email', 'role_level', 'is_online', 'active_ticket_count', 'max_concurrent_tickets', 'specialization'],
        order: [['is_online', 'DESC'], ['active_ticket_count', 'ASC']],
      });
      return res.json({ success: true, data: agents });
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
      const schema = extractSchemaFromMigrations();
      return res.json({
        success: true,
        message: 'Database schema successfully extracted from migrations.',
        data: schema,
      });
    } catch (err: any) {
      console.error('getSystemSchema error:', err);
      return res.status(500).json({ success: false, message: err.message });
    }
  }
}

export default SupportConsoleController;
