import { Sequelize, DataTypes, Model } from 'sequelize';

export interface SupportTicketAttributes {
  id?: string;
  ticket_number: string;
  tenant_id: string;
  outlet_id: number;
  subject: string;
  priority?: string;
  status?: string;
  assigned_agent_id?: string;
  client_telemetry?: any;
  resolution_summary?: string;
  resolved_at?: Date;
  last_read_by_support_at?: Date;
  created_at?: Date;
  updated_at?: Date;
}

export default (sequelize: Sequelize) => {
  class SupportTicket extends Model<SupportTicketAttributes> implements SupportTicketAttributes {
    declare public id: string;
    declare public ticket_number: string;
    declare public tenant_id: string;
    declare public outlet_id: number;
    declare public subject: string;
    declare public priority: string;
    declare public status: string;
    declare public assigned_agent_id?: string;
    declare public client_telemetry?: any;
    declare public resolution_summary?: string;
    declare public resolved_at?: Date;
    declare public last_read_by_support_at?: Date;
  }

  SupportTicket.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      ticket_number: {
        type: DataTypes.STRING(50),
        allowNull: false,
        unique: true,
      },
      tenant_id: {
        type: DataTypes.UUID,
        allowNull: false,
      },
      outlet_id: {
        type: DataTypes.BIGINT,
        allowNull: false,
      },
      subject: {
        type: DataTypes.STRING(255),
        allowNull: false,
      },
      priority: {
        type: DataTypes.STRING(20),
        defaultValue: 'MEDIUM',
      },
      status: {
        type: DataTypes.STRING(30),
        defaultValue: 'OPEN',
      },
      assigned_agent_id: {
        type: DataTypes.UUID,
        allowNull: true,
      },
      client_telemetry: {
        type: DataTypes.JSONB,
        defaultValue: {},
      },
      resolution_summary: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      resolved_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      last_read_by_support_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
    },
    {
      sequelize,
      tableName: 'support_tickets',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
    }
  );

  return SupportTicket;
};
