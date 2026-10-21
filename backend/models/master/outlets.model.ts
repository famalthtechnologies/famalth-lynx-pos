import { Sequelize, DataTypes, Model } from 'sequelize';

export interface MasterOutletAttributes {
  id?: number;
  tenant_id: string;
  outlet_code: string;
  outlet_name: string;
  outlet_type?: string;
  city?: string;
  state?: string;
  country?: string;
  hardware_machine_id?: string;
  ip_address?: string;
  is_active?: boolean;
  is_kill_switched?: boolean;
  kill_switch_reason?: string;
  last_ping_at?: Date;
  created_at?: Date;
  updated_at?: Date;
}

export default (sequelize: Sequelize) => {
  class MasterOutlet extends Model<MasterOutletAttributes> implements MasterOutletAttributes {
    declare public id: number;
    declare public tenant_id: string;
    declare public outlet_code: string;
    declare public outlet_name: string;
    declare public outlet_type: string;
    declare public city?: string;
    declare public state?: string;
    declare public country?: string;
    declare public hardware_machine_id?: string;
    declare public ip_address?: string;
    declare public is_active: boolean;
    declare public is_kill_switched: boolean;
    declare public kill_switch_reason?: string;
    declare public last_ping_at?: Date;
  }

  MasterOutlet.init(
    {
      id: {
        type: DataTypes.BIGINT,
        autoIncrement: true,
        primaryKey: true,
      },
      tenant_id: {
        type: DataTypes.UUID,
        allowNull: false,
      },
      outlet_code: {
        type: DataTypes.STRING(50),
        allowNull: false,
        unique: true,
      },
      outlet_name: {
        type: DataTypes.STRING(255),
        allowNull: false,
      },
      outlet_type: {
        type: DataTypes.STRING(50),
        defaultValue: 'RETAIL',
      },
      city: {
        type: DataTypes.STRING(100),
        allowNull: true,
      },
      state: {
        type: DataTypes.STRING(100),
        allowNull: true,
      },
      country: {
        type: DataTypes.STRING(100),
        defaultValue: 'India',
      },
      hardware_machine_id: {
        type: DataTypes.STRING(255),
        allowNull: true,
      },
      ip_address: {
        type: DataTypes.STRING(45),
        allowNull: true,
      },
      is_active: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
      },
      is_kill_switched: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
      },
      kill_switch_reason: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      last_ping_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
    },
    {
      sequelize,
      tableName: 'master_outlets',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
    }
  );

  return MasterOutlet;
};
