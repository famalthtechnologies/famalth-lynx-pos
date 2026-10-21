import { Sequelize, DataTypes, Model } from 'sequelize';

export interface DiagnosticQueryAuditLogAttributes {
  id?: string;
  ticket_id?: string;
  agent_id?: string;
  tenant_id: string;
  outlet_id: number;
  executed_sql: string;
  operation_type: string;
  where_clause_text: string;
  row_count_affected?: number;
  pre_change_snapshot?: any;
  execution_duration_ms?: number;
  executed_at?: Date;
}

export default (sequelize: Sequelize) => {
  class DiagnosticQueryAuditLog
    extends Model<DiagnosticQueryAuditLogAttributes>
    implements DiagnosticQueryAuditLogAttributes
  {
    declare public id: string;
    declare public ticket_id?: string;
    declare public agent_id?: string;
    declare public tenant_id: string;
    declare public outlet_id: number;
    declare public executed_sql: string;
    declare public operation_type: string;
    declare public where_clause_text: string;
    declare public row_count_affected: number;
    declare public pre_change_snapshot?: any;
    declare public execution_duration_ms: number;
    declare public executed_at: Date;
  }

  DiagnosticQueryAuditLog.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      ticket_id: {
        type: DataTypes.UUID,
        allowNull: true,
      },
      agent_id: {
        type: DataTypes.UUID,
        allowNull: true,
      },
      tenant_id: {
        type: DataTypes.UUID,
        allowNull: false,
      },
      outlet_id: {
        type: DataTypes.BIGINT,
        allowNull: false,
      },
      executed_sql: {
        type: DataTypes.TEXT,
        allowNull: false,
      },
      operation_type: {
        type: DataTypes.STRING(20),
        allowNull: false,
      },
      where_clause_text: {
        type: DataTypes.TEXT,
        allowNull: false,
      },
      row_count_affected: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
      },
      pre_change_snapshot: {
        type: DataTypes.JSONB,
        allowNull: true,
      },
      execution_duration_ms: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
      },
    },
    {
      sequelize,
      tableName: 'diagnostic_query_audit_logs',
      timestamps: true,
      createdAt: 'executed_at',
      updatedAt: false,
    }
  );

  return DiagnosticQueryAuditLog;
};
