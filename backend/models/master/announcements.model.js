"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const sequelize_1 = require("sequelize");
exports.default = (sequelize) => {
    class MasterAnnouncement extends sequelize_1.Model {
    }
    MasterAnnouncement.init({
        id: {
            type: sequelize_1.DataTypes.UUID,
            defaultValue: sequelize_1.DataTypes.UUIDV4,
            primaryKey: true,
        },
        target_tenant_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: true,
        },
        title: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: false,
        },
        message: {
            type: sequelize_1.DataTypes.TEXT,
            allowNull: false,
        },
        action_link: {
            type: sequelize_1.DataTypes.STRING(500),
            allowNull: true,
        },
        action_label: {
            type: sequelize_1.DataTypes.STRING(100),
            defaultValue: 'Learn More',
        },
        badge_text: {
            type: sequelize_1.DataTypes.STRING(50),
            defaultValue: 'Special Offer',
        },
        discount_code: {
            type: sequelize_1.DataTypes.STRING(50),
            allowNull: true,
        },
        is_active: {
            type: sequelize_1.DataTypes.BOOLEAN,
            defaultValue: true,
        },
        expires_at: {
            type: sequelize_1.DataTypes.DATE,
            allowNull: true,
        },
    }, {
        sequelize,
        tableName: 'master_announcements',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
    });
    return MasterAnnouncement;
};
