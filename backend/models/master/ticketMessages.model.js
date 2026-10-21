"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sequelize_1 = require("sequelize");
exports.default = (sequelize) => {
    class TicketMessage extends sequelize_1.Model {
    }
    TicketMessage.init({
        id: {
            type: sequelize_1.DataTypes.BIGINT,
            autoIncrement: true,
            primaryKey: true,
        },
        ticket_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: false,
        },
        sender_type: {
            type: sequelize_1.DataTypes.STRING(30),
            allowNull: false,
        },
        sender_id: {
            type: sequelize_1.DataTypes.STRING(100),
            allowNull: true,
        },
        sender_name: {
            type: sequelize_1.DataTypes.STRING(150),
            allowNull: true,
        },
        message: {
            type: sequelize_1.DataTypes.TEXT,
            allowNull: false,
        },
        diagnostic_payload: {
            type: sequelize_1.DataTypes.JSONB,
            allowNull: true,
        },
        attachments: {
            type: sequelize_1.DataTypes.JSONB,
            defaultValue: [],
        },
    }, {
        sequelize,
        tableName: 'ticket_messages',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: false,
    });
    return TicketMessage;
};
