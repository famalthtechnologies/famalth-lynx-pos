"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sequelize_1 = require("sequelize");
exports.default = (sequelize) => {
    class MasterReseller extends sequelize_1.Model {
    }
    MasterReseller.init({
        id: {
            type: sequelize_1.DataTypes.UUID,
            defaultValue: sequelize_1.DataTypes.UUIDV4,
            primaryKey: true,
        },
        reseller_code: {
            type: sequelize_1.DataTypes.STRING(50),
            allowNull: false,
            unique: true,
        },
        company_name: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: false,
        },
        contact_name: {
            type: sequelize_1.DataTypes.STRING(150),
            allowNull: false,
        },
        email: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: false,
            unique: true,
        },
        phone: {
            type: sequelize_1.DataTypes.STRING(50),
            allowNull: false,
        },
        commission_rate: {
            type: sequelize_1.DataTypes.DECIMAL(5, 2),
            defaultValue: 15.0,
        },
        allocated_license_credits: {
            type: sequelize_1.DataTypes.INTEGER,
            defaultValue: 10,
        },
        password_hash: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: true,
        },
        is_active: {
            type: sequelize_1.DataTypes.BOOLEAN,
            defaultValue: true,
        },
    }, {
        sequelize,
        tableName: 'master_resellers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
    });
    return MasterReseller;
};
