import { Sequelize, DataTypes, Model } from 'sequelize';

export interface ResellerAttributes {
  id?: string;
  reseller_code: string;
  company_name: string;
  contact_name: string;
  email: string;
  phone: string;
  commission_rate?: number;
  allocated_license_credits?: number;
  password_hash?: string;
  is_active?: boolean;
  created_at?: Date;
  updated_at?: Date;
}

export default (sequelize: Sequelize) => {
  class MasterReseller extends Model<ResellerAttributes> implements ResellerAttributes {
    declare public id: string;
    declare public reseller_code: string;
    declare public company_name: string;
    declare public contact_name: string;
    declare public email: string;
    declare public phone: string;
    declare public commission_rate: number;
    declare public allocated_license_credits: number;
    declare public password_hash?: string;
    declare public is_active: boolean;
  }

  MasterReseller.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      reseller_code: {
        type: DataTypes.STRING(50),
        allowNull: false,
        unique: true,
      },
      company_name: {
        type: DataTypes.STRING(255),
        allowNull: false,
      },
      contact_name: {
        type: DataTypes.STRING(150),
        allowNull: false,
      },
      email: {
        type: DataTypes.STRING(255),
        allowNull: false,
        unique: true,
      },
      phone: {
        type: DataTypes.STRING(50),
        allowNull: false,
      },
      commission_rate: {
        type: DataTypes.DECIMAL(5, 2),
        defaultValue: 15.0,
      },
      allocated_license_credits: {
        type: DataTypes.INTEGER,
        defaultValue: 10,
      },
      password_hash: {
        type: DataTypes.STRING(255),
        allowNull: true,
      },
      is_active: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
      },
    },
    {
      sequelize,
      tableName: 'master_resellers',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
    }
  );

  return MasterReseller;
};
