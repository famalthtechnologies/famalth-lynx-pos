import { Sequelize, DataTypes, Model } from 'sequelize';

export interface LicenseAttributes {
  id?: string;
  tenant_id: string;
  license_key: string;
  tier_name?: string;
  max_outlets?: number;
  max_terminals?: number;
  valid_from: Date;
  valid_till: Date;
  warning_zone_days?: number;
  grace_period_days?: number;
  subscription_amount?: number;
  tax_percentage?: number;
  next_payment_date?: Date | null;
  payment_status?: string;
  last_payment_date?: Date | null;
  is_perpetual?: boolean;
  status?: string;
  signed_jwt_token?: string;
  created_at?: Date;
  updated_at?: Date;
}

export default (sequelize: Sequelize) => {
  class MasterLicense extends Model<LicenseAttributes> implements LicenseAttributes {
    declare public id: string;
    declare public tenant_id: string;
    declare public license_key: string;
    declare public tier_name: string;
    declare public max_outlets: number;
    declare public max_terminals: number;
    declare public valid_from: Date;
    declare public valid_till: Date;
    declare public warning_zone_days: number;
    declare public grace_period_days: number;
    declare public subscription_amount: number;
    declare public tax_percentage: number;
    declare public next_payment_date: Date | null;
    declare public payment_status: string;
    declare public last_payment_date: Date | null;
    declare public is_perpetual: boolean;
    declare public status: string;
    declare public signed_jwt_token?: string;
  }

  MasterLicense.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      tenant_id: {
        type: DataTypes.UUID,
        allowNull: false,
      },
      license_key: {
        type: DataTypes.STRING(255),
        allowNull: false,
        unique: true,
      },
      tier_name: {
        type: DataTypes.STRING(50),
        defaultValue: 'PROFESSIONAL',
      },
      max_outlets: {
        type: DataTypes.INTEGER,
        defaultValue: 1,
      },
      max_terminals: {
        type: DataTypes.INTEGER,
        defaultValue: 3,
      },
      valid_from: {
        type: DataTypes.DATEONLY,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      valid_till: {
        type: DataTypes.DATEONLY,
        allowNull: false,
      },
      warning_zone_days: {
        type: DataTypes.INTEGER,
        defaultValue: 15,
      },
      grace_period_days: {
        type: DataTypes.INTEGER,
        defaultValue: 15,
      },
      subscription_amount: {
        type: DataTypes.DECIMAL(12, 2),
        defaultValue: 4999.00,
      },
      tax_percentage: {
        type: DataTypes.DECIMAL(5, 2),
        defaultValue: 18.00,
      },
      next_payment_date: {
        type: DataTypes.DATEONLY,
        allowNull: true,
      },
      payment_status: {
        type: DataTypes.STRING(50),
        defaultValue: 'PAID',
      },
      last_payment_date: {
        type: DataTypes.DATEONLY,
        allowNull: true,
      },
      is_perpetual: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
      },
      status: {
        type: DataTypes.STRING(30),
        defaultValue: 'ACTIVE',
      },
      signed_jwt_token: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
    },
    {
      sequelize,
      tableName: 'master_licenses',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
    }
  );

  return MasterLicense;
};
