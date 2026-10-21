import { Sequelize, DataTypes, Model } from 'sequelize';

export interface SupportAgentAttributes {
  id?: string;
  full_name: string;
  email: string;
  password_hash?: string;
  role_level?: string;
  is_online?: boolean;
  active_ticket_count?: number;
  max_concurrent_tickets?: number;
  specialization?: string;
  created_at?: Date;
  updated_at?: Date;
}

export default (sequelize: Sequelize) => {
  class SupportAgent extends Model<SupportAgentAttributes> implements SupportAgentAttributes {
    declare public id: string;
    declare public full_name: string;
    declare public email: string;
    declare public password_hash?: string;
    declare public role_level: string;
    declare public is_online: boolean;
    declare public active_ticket_count: number;
    declare public max_concurrent_tickets: number;
    declare public specialization: string;
  }

  SupportAgent.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      full_name: {
        type: DataTypes.STRING(150),
        allowNull: false,
      },
      email: {
        type: DataTypes.STRING(255),
        allowNull: false,
        unique: true,
      },
      password_hash: {
        type: DataTypes.STRING(255),
        allowNull: true,
      },
      role_level: {
        type: DataTypes.STRING(20),
        defaultValue: 'L1',
      },
      is_online: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
      },
      active_ticket_count: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
      },
      max_concurrent_tickets: {
        type: DataTypes.INTEGER,
        defaultValue: 5,
      },
      specialization: {
        type: DataTypes.STRING(50),
        defaultValue: 'GENERAL',
      },
    },
    {
      sequelize,
      tableName: 'support_agents',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
    }
  );

  return SupportAgent;
};
