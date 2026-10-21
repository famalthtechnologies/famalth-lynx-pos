"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sequelize_1 = require("sequelize");
exports.default = (sequelize) => {
    class MasterTenant extends sequelize_1.Model {
    }
    MasterTenant.init({
        id: {
            type: sequelize_1.DataTypes.UUID,
            defaultValue: sequelize_1.DataTypes.UUIDV4,
            primaryKey: true,
        },
        client_code: {
            type: sequelize_1.DataTypes.STRING(50),
            allowNull: false,
            unique: true,
        },
        legal_name: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: false,
        },
        trade_name: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: true,
        },
        tax_identifier: {
            type: sequelize_1.DataTypes.STRING(50),
            defaultValue: '',
        },
        contact_email: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: false,
        },
        contact_phone: {
            type: sequelize_1.DataTypes.STRING(50),
            defaultValue: '',
        },
        reseller_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: true,
        },
        rm_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: true,
        },
        status: {
            type: sequelize_1.DataTypes.STRING(30),
            defaultValue: 'ACTIVE',
        },
        db_storage_mode: {
            type: sequelize_1.DataTypes.STRING(30),
            defaultValue: 'SHARED_DB_TENANT_TAGGED',
        },
        db_connection_url: {
            type: sequelize_1.DataTypes.TEXT,
            allowNull: true,
        },
        pin_hash: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: true,
        },
        custom_metadata: {
            type: sequelize_1.DataTypes.JSONB,
            defaultValue: {},
        },
    }, {
        sequelize,
        tableName: 'master_tenants',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
    });
    return MasterTenant;
};
