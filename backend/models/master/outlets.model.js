"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sequelize_1 = require("sequelize");
exports.default = (sequelize) => {
    class MasterOutlet extends sequelize_1.Model {
    }
    MasterOutlet.init({
        id: {
            type: sequelize_1.DataTypes.BIGINT,
            autoIncrement: true,
            primaryKey: true,
        },
        tenant_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: false,
        },
        outlet_code: {
            type: sequelize_1.DataTypes.STRING(50),
            allowNull: false,
            unique: true,
        },
        outlet_name: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: false,
        },
        outlet_type: {
            type: sequelize_1.DataTypes.STRING(50),
            defaultValue: 'RETAIL',
        },
        city: {
            type: sequelize_1.DataTypes.STRING(100),
            allowNull: true,
        },
        state: {
            type: sequelize_1.DataTypes.STRING(100),
            allowNull: true,
        },
        country: {
            type: sequelize_1.DataTypes.STRING(100),
            defaultValue: 'India',
        },
        hardware_machine_id: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: true,
        },
        ip_address: {
            type: sequelize_1.DataTypes.STRING(45),
            allowNull: true,
        },
        is_active: {
            type: sequelize_1.DataTypes.BOOLEAN,
            defaultValue: true,
        },
        is_kill_switched: {
            type: sequelize_1.DataTypes.BOOLEAN,
            defaultValue: false,
        },
        kill_switch_reason: {
            type: sequelize_1.DataTypes.TEXT,
            allowNull: true,
        },
        last_ping_at: {
            type: sequelize_1.DataTypes.DATE,
            allowNull: true,
        },
    }, {
        sequelize,
        tableName: 'master_outlets',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
    });
    return MasterOutlet;
};
