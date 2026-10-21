"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sequelize_1 = require("sequelize");
exports.default = (sequelize) => {
    class SupportAgent extends sequelize_1.Model {
    }
    SupportAgent.init({
        id: {
            type: sequelize_1.DataTypes.UUID,
            defaultValue: sequelize_1.DataTypes.UUIDV4,
            primaryKey: true,
        },
        full_name: {
            type: sequelize_1.DataTypes.STRING(150),
            allowNull: false,
        },
        email: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: false,
            unique: true,
        },
        password_hash: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: true,
        },
        role_level: {
            type: sequelize_1.DataTypes.STRING(20),
            defaultValue: 'L1',
        },
        is_online: {
            type: sequelize_1.DataTypes.BOOLEAN,
            defaultValue: false,
        },
        active_ticket_count: {
            type: sequelize_1.DataTypes.INTEGER,
            defaultValue: 0,
        },
        max_concurrent_tickets: {
            type: sequelize_1.DataTypes.INTEGER,
            defaultValue: 5,
        },
        specialization: {
            type: sequelize_1.DataTypes.STRING(50),
            defaultValue: 'GENERAL',
        },
    }, {
        sequelize,
        tableName: 'support_agents',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
    });
    return SupportAgent;
};
