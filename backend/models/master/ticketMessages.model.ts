import { Sequelize, DataTypes, Model } from 'sequelize';

export interface TicketMessageAttributes {
  id?: number;
  ticket_id: string;
  sender_type: string;
  sender_id?: string;
  sender_name?: string;
  message: string;
  diagnostic_payload?: any;
  attachments?: any;
  is_read_by_support?: boolean;
  created_at?: Date;
}

export default (sequelize: Sequelize) => {
  class TicketMessage extends Model<TicketMessageAttributes> implements TicketMessageAttributes {
    declare public id: number;
    declare public ticket_id: string;
    declare public sender_type: string;
    declare public sender_id?: string;
    declare public sender_name?: string;
    declare public message: string;
    declare public diagnostic_payload?: any;
    declare public attachments?: any;
    declare public is_read_by_support?: boolean;
  }

  TicketMessage.init(
    {
      id: {
        type: DataTypes.BIGINT,
        autoIncrement: true,
        primaryKey: true,
      },
      ticket_id: {
        type: DataTypes.UUID,
        allowNull: false,
      },
      sender_type: {
        type: DataTypes.STRING(30),
        allowNull: false,
      },
      sender_id: {
        type: DataTypes.STRING(100),
        allowNull: true,
      },
      sender_name: {
        type: DataTypes.STRING(150),
        allowNull: true,
      },
      message: {
        type: DataTypes.TEXT,
        allowNull: false,
      },
      diagnostic_payload: {
        type: DataTypes.JSONB,
        allowNull: true,
      },
      attachments: {
        type: DataTypes.JSONB,
        defaultValue: [],
      },
      is_read_by_support: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
      },
    },
    {
      sequelize,
      tableName: 'ticket_messages',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: false,
    }
  );

  return TicketMessage;
};
