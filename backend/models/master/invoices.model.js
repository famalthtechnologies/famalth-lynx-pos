"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sequelize_1 = require("sequelize");
exports.default = (sequelize) => {
    class MasterInvoice extends sequelize_1.Model {
    }
    MasterInvoice.init({
        id: {
            type: sequelize_1.DataTypes.UUID,
            defaultValue: sequelize_1.DataTypes.UUIDV4,
            primaryKey: true,
        },
        tenant_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: false,
        },
        invoice_number: {
            type: sequelize_1.DataTypes.STRING(100),
            allowNull: false,
            unique: true,
        },
        billing_period_start: {
            type: sequelize_1.DataTypes.DATEONLY,
            allowNull: false,
        },
        billing_period_end: {
            type: sequelize_1.DataTypes.DATEONLY,
            allowNull: false,
        },
        due_date: {
            type: sequelize_1.DataTypes.DATEONLY,
            allowNull: false,
        },
        subtotal: {
            type: sequelize_1.DataTypes.DECIMAL(12, 2),
            allowNull: false,
        },
        tax_rate: {
            type: sequelize_1.DataTypes.DECIMAL(5, 2),
            defaultValue: 18.00,
        },
        tax_amount: {
            type: sequelize_1.DataTypes.DECIMAL(12, 2),
            allowNull: false,
        },
        total_amount: {
            type: sequelize_1.DataTypes.DECIMAL(12, 2),
            allowNull: false,
        },
        status: {
            type: sequelize_1.DataTypes.STRING(50),
            defaultValue: 'ISSUED',
        },
        pdf_data: {
            type: sequelize_1.DataTypes.TEXT,
            allowNull: true,
        },
        paid_at: {
            type: sequelize_1.DataTypes.DATE,
            allowNull: true,
        },
    }, {
        sequelize,
        tableName: 'master_invoices',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
    });
    return MasterInvoice;
};
