import { DataTypes, Model, Sequelize } from 'sequelize';

export interface MasterStaffUserAttributes {
  id: string;
  username: string;
  email: string;
  password_hash: string;
  full_name: string;
  role: 'SUPER_ADMIN' | 'RESELLER_ADMIN' | 'DEVELOPER' | 'SUPPORT_AGENT' | 'RM';
  reseller_id?: string | null;
  permissions: string[];
  is_active: boolean;
  phone?: string | null;
  avatar_url?: string | null;
  last_login_at?: Date | null;
  created_at?: Date;
  updated_at?: Date;
}

export class MasterStaffUser extends Model<MasterStaffUserAttributes> implements MasterStaffUserAttributes {
  declare public id: string;
  declare public username: string;
  declare public email: string;
  declare public password_hash: string;
  declare public full_name: string;
  declare public role: 'SUPER_ADMIN' | 'RESELLER_ADMIN' | 'DEVELOPER' | 'SUPPORT_AGENT' | 'RM';
  declare public reseller_id: string | null;
  declare public permissions: string[];
  declare public is_active: boolean;
  declare public phone: string | null;
  declare public avatar_url: string | null;
  declare public last_login_at: Date | null;
  declare public readonly created_at: Date;
  declare public readonly updated_at: Date;
}

export default function defineMasterStaffUser(sequelize: Sequelize) {
  MasterStaffUser.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      username: {
        type: DataTypes.STRING(80),
        allowNull: false,
        unique: true,
      },
      email: {
        type: DataTypes.STRING(150),
        allowNull: false,
        unique: true,
      },
      password_hash: {
        type: DataTypes.STRING(255),
        allowNull: false,
      },
      full_name: {
        type: DataTypes.STRING(150),
        allowNull: false,
      },
      role: {
        type: DataTypes.ENUM('SUPER_ADMIN', 'RESELLER_ADMIN', 'DEVELOPER', 'SUPPORT_AGENT', 'RM'),
        defaultValue: 'SUPPORT_AGENT',
        allowNull: false,
      },
      reseller_id: {
        type: DataTypes.UUID,
        allowNull: true,
      },
      permissions: {
        type: DataTypes.JSONB,
        defaultValue: [],
      },
      is_active: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
      },
      phone: {
        type: DataTypes.STRING(30),
        allowNull: true,
      },
      avatar_url: {
        type: DataTypes.STRING(255),
        allowNull: true,
      },
      last_login_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
    },
    {
      sequelize,
      tableName: 'master_staff_users',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
    }
  );

  return MasterStaffUser;
}
