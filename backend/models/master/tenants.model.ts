import { Sequelize, DataTypes, Model } from 'sequelize';

export interface TenantAttributes {
  id?: string;
  client_code: string;
  legal_name: string;
  trade_name?: string;
  tax_identifier?: string;
  contact_email: string;
  contact_phone?: string;
  reseller_id?: string;
  rm_id?: string;
  status?: string;
  db_storage_mode?: string;
  db_connection_url?: string;
  pin_hash?: string;
  custom_metadata?: any;
  created_at?: Date;
  updated_at?: Date;
}

export default (sequelize: Sequelize) => {
  class MasterTenant extends Model<TenantAttributes> implements TenantAttributes {
    declare public id: string;
    declare public client_code: string;
    declare public legal_name: string;
    declare public trade_name?: string;
    declare public tax_identifier?: string;
    declare public contact_email: string;
    declare public contact_phone?: string;
    declare public reseller_id?: string;
    declare public rm_id?: string;
    declare public status: string;
    declare public db_storage_mode: string;
    declare public db_connection_url?: string;
    declare public pin_hash?: string;
    declare public custom_metadata?: any;
  }

  MasterTenant.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      client_code: {
        type: DataTypes.STRING(50),
        allowNull: false,
        unique: true,
      },
      legal_name: {
        type: DataTypes.STRING(255),
        allowNull: false,
      },
      trade_name: {
        type: DataTypes.STRING(255),
        allowNull: true,
      },
      tax_identifier: {
        type: DataTypes.STRING(50),
        defaultValue: '',
      },
      contact_email: {
        type: DataTypes.STRING(255),
        allowNull: false,
      },
      contact_phone: {
        type: DataTypes.STRING(50),
        defaultValue: '',
      },
      reseller_id: {
        type: DataTypes.UUID,
        allowNull: true,
      },
      rm_id: {
        type: DataTypes.UUID,
        allowNull: true,
      },
      status: {
        type: DataTypes.STRING(30),
        defaultValue: 'ACTIVE',
      },
      db_storage_mode: {
        type: DataTypes.STRING(30),
        defaultValue: 'SHARED_DB_TENANT_TAGGED',
      },
      db_connection_url: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      pin_hash: {
        type: DataTypes.STRING(255),
        allowNull: true,
      },
      custom_metadata: {
        type: DataTypes.JSONB,
        defaultValue: {},
      },
    },
    {
      sequelize,
      tableName: 'master_tenants',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
    }
  );

  return MasterTenant;
};
