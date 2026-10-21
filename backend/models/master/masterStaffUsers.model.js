"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MasterStaffUser = void 0;
exports.default = defineMasterStaffUser;
const sequelize_1 = require("sequelize");
class MasterStaffUser extends sequelize_1.Model {
}
exports.MasterStaffUser = MasterStaffUser;
function defineMasterStaffUser(sequelize) {
    MasterStaffUser.init({
        id: {
            type: sequelize_1.DataTypes.UUID,
            defaultValue: sequelize_1.DataTypes.UUIDV4,
            primaryKey: true,
        },
        username: {
            type: sequelize_1.DataTypes.STRING(80),
            allowNull: false,
            unique: true,
        },
        email: {
            type: sequelize_1.DataTypes.STRING(150),
            allowNull: false,
            unique: true,
        },
        password_hash: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: false,
        },
        full_name: {
            type: sequelize_1.DataTypes.STRING(150),
            allowNull: false,
        },
        role: {
            type: sequelize_1.DataTypes.ENUM('SUPER_ADMIN', 'RESELLER_ADMIN', 'DEVELOPER', 'SUPPORT_AGENT', 'RM'),
            defaultValue: 'SUPPORT_AGENT',
            allowNull: false,
        },
        reseller_id: {
            type: sequelize_1.DataTypes.UUID,
            allowNull: true,
        },
        permissions: {
            type: sequelize_1.DataTypes.JSONB,
            defaultValue: [],
        },
        is_active: {
            type: sequelize_1.DataTypes.BOOLEAN,
            defaultValue: true,
        },
        phone: {
            type: sequelize_1.DataTypes.STRING(30),
            allowNull: true,
        },
        avatar_url: {
            type: sequelize_1.DataTypes.STRING(255),
            allowNull: true,
        },
        last_login_at: {
            type: sequelize_1.DataTypes.DATE,
            allowNull: true,
        },
    }, {
        sequelize,
        tableName: 'master_staff_users',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
    });
    return MasterStaffUser;
}
