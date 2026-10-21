"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sequelize_1 = require("sequelize");
exports.default = (sequelize) => {
    class MasterRelationshipManager extends sequelize_1.Model {
    }
    MasterRelationshipManager.init({
        id: {
            type: sequelize_1.DataTypes.UUID,
            defaultValue: sequelize_1.DataTypes.UUIDV4,
            primaryKey: true,
        },
        rm_code: {
            type: sequelize_1.DataTypes.STRING(50),
            allowNull: false,
            unique: true,
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
        phone: {
            type: sequelize_1.DataTypes.STRING(50),
            allowNull: false,
        },
        whatsapp_number: {
            type: sequelize_1.DataTypes.STRING(50),
            allowNull: false,
        },
        avatar_url: {
            type: sequelize_1.DataTypes.TEXT,
            defaultValue: '',
        },
        designation: {
            type: sequelize_1.DataTypes.STRING(100),
            defaultValue: 'Senior Account Specialist',
        },
        is_active: {
            type: sequelize_1.DataTypes.BOOLEAN,
            defaultValue: true,
        },
    }, {
        sequelize,
        tableName: 'master_relationship_managers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
    });
    return MasterRelationshipManager;
};
