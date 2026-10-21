"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sequelize_1 = require("sequelize");
exports.default = (sequelize) => {
    class DiagnosticQueryAuditLog extends sequelize_1.Model {
    }
    DiagnosticQueryAuditLog.init({
        id: {
            type: sequelize_1.DataTypes.UUID,
            defaultValue: sequelize_1.DataTypes.UUIDV4,
            primaryKey: true,
        },
        ticket_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: true,
        },
        agent_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: true,
        },
        tenant_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: false,
        },
        outlet_id: {
            type: sequelize_1.DataTypes.BIGINT,
            allowNull: false,
        },
        executed_sql: {
            type: sequelize_1.DataTypes.TEXT,
            allowNull: false,
        },
        operation_type: {
            type: sequelize_1.DataTypes.STRING(20),
            allowNull: false,
        },
        where_clause_text: {
            type: sequelize_1.DataTypes.TEXT,
            allowNull: false,
        },
        row_count_affected: {
            type: sequelize_1.DataTypes.INTEGER,
            defaultValue: 0,
        },
        pre_change_snapshot: {
            type: sequelize_1.DataTypes.JSONB,
            allowNull: true,
        },
        execution_duration_ms: {
            type: sequelize_1.DataTypes.INTEGER,
            defaultValue: 0,
        },
    }, {
        sequelize,
        tableName: 'diagnostic_query_audit_logs',
        timestamps: true,
        createdAt: 'executed_at',
        updatedAt: false,
    });
    return DiagnosticQueryAuditLog;
};
