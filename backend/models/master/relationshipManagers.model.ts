import { Sequelize, DataTypes, Model } from 'sequelize';

export interface RelationshipManagerAttributes {
  id?: string;
  rm_code: string;
  full_name: string;
  email: string;
  phone: string;
  whatsapp_number: string;
  avatar_url?: string;
  designation?: string;
  is_active?: boolean;
  created_at?: Date;
  updated_at?: Date;
}

export default (sequelize: Sequelize) => {
  class MasterRelationshipManager extends Model<RelationshipManagerAttributes> implements RelationshipManagerAttributes {
    declare public id: string;
    declare public rm_code: string;
    declare public full_name: string;
    declare public email: string;
    declare public phone: string;
    declare public whatsapp_number: string;
    declare public avatar_url?: string;
    declare public designation: string;
    declare public is_active: boolean;
  }

  MasterRelationshipManager.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      rm_code: {
        type: DataTypes.STRING(50),
        allowNull: false,
        unique: true,
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
      phone: {
        type: DataTypes.STRING(50),
        allowNull: false,
      },
      whatsapp_number: {
        type: DataTypes.STRING(50),
        allowNull: false,
      },
      avatar_url: {
        type: DataTypes.TEXT,
        defaultValue: '',
      },
      designation: {
        type: DataTypes.STRING(100),
        defaultValue: 'Senior Account Specialist',
      },
      is_active: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
      },
    },
    {
      sequelize,
      tableName: 'master_relationship_managers',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
    }
  );

  return MasterRelationshipManager;
};
