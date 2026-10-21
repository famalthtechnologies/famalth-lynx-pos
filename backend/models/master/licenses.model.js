"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sequelize_1 = require("sequelize");
exports.default = (sequelize) => {
    class MasterLicense extends sequelize_1.Model {
    }
    MasterLicense.init({
        id: {
            type: sequelize_1.DataTypes.UUID,
            defaultValue: sequelize_1.DataTypes.UUIDV4,
            primaryKey: true,
        },
        tenant_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: false,
        },
        license_key: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: false,
            unique: true,
        },
        tier_name: {
            type: sequelize_1.DataTypes.STRING(50),
            defaultValue: 'PROFESSIONAL',
        },
        max_outlets: {
            type: sequelize_1.DataTypes.INTEGER,
            defaultValue: 1,
        },
        max_terminals: {
            type: sequelize_1.DataTypes.INTEGER,
            defaultValue: 3,
        },
        valid_from: {
            type: sequelize_1.DataTypes.DATEONLY,
            allowNull: false,
            defaultValue: sequelize_1.DataTypes.NOW,
        },
        valid_till: {
            type: sequelize_1.DataTypes.DATEONLY,
            allowNull: false,
        },
        warning_zone_days: {
            type: sequelize_1.DataTypes.INTEGER,
            defaultValue: 15,
        },
        grace_period_days: {
            type: sequelize_1.DataTypes.INTEGER,
            defaultValue: 15,
        },
        subscription_amount: {
            type: sequelize_1.DataTypes.DECIMAL(12, 2),
            defaultValue: 4999.00,
        },
        tax_percentage: {
            type: sequelize_1.DataTypes.DECIMAL(5, 2),
            defaultValue: 18.00,
        },
        next_payment_date: {
            type: sequelize_1.DataTypes.DATEONLY,
            allowNull: true,
        },
        payment_status: {
            type: sequelize_1.DataTypes.STRING(50),
            defaultValue: 'PAID',
        },
        last_payment_date: {
            type: sequelize_1.DataTypes.DATEONLY,
            allowNull: true,
        },
        is_perpetual: {
            type: sequelize_1.DataTypes.BOOLEAN,
            defaultValue: false,
        },
        status: {
            type: sequelize_1.DataTypes.STRING(30),
            defaultValue: 'ACTIVE',
        },
        signed_jwt_token: {
            type: sequelize_1.DataTypes.TEXT,
            allowNull: true,
        },
    }, {
        sequelize,
        tableName: 'master_licenses',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
    });
    return MasterLicense;
};
