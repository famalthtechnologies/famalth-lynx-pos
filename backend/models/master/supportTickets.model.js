"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sequelize_1 = require("sequelize");
exports.default = (sequelize) => {
    class SupportTicket extends sequelize_1.Model {
    }
    SupportTicket.init({
        id: {
            type: sequelize_1.DataTypes.UUID,
            defaultValue: sequelize_1.DataTypes.UUIDV4,
            primaryKey: true,
        },
        ticket_number: {
            type: sequelize_1.DataTypes.STRING(50),
            allowNull: false,
            unique: true,
        },
        tenant_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: false,
        },
        outlet_id: {
            type: sequelize_1.DataTypes.BIGINT,
            allowNull: false,
        },
        subject: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: false,
        },
        priority: {
            type: sequelize_1.DataTypes.STRING(20),
            defaultValue: 'MEDIUM',
        },
        status: {
            type: sequelize_1.DataTypes.STRING(30),
            defaultValue: 'OPEN',
        },
        assigned_agent_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: true,
        },
        client_telemetry: {
            type: sequelize_1.DataTypes.JSONB,
            defaultValue: {},
        },
        resolution_summary: {
            type: sequelize_1.DataTypes.TEXT,
            allowNull: true,
        },
        resolved_at: {
            type: sequelize_1.DataTypes.DATE,
            allowNull: true,
        },
    }, {
        sequelize,
        tableName: 'support_tickets',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
    });
    return SupportTicket;
};
