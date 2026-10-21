import { Sequelize, DataTypes, Model } from 'sequelize';

export interface AnnouncementAttributes {
  id?: string;
  target_tenant_id?: string | null;
  title: string;
  message: string;
  action_link?: string | null;
  action_label?: string | null;
  badge_text?: string | null;
  discount_code?: string | null;
  is_active?: boolean;
  expires_at?: Date | null;
  created_at?: Date;
  updated_at?: Date;
}

export default (sequelize: Sequelize) => {
  class MasterAnnouncement extends Model<AnnouncementAttributes> implements AnnouncementAttributes {
    declare public id: string;
    declare public target_tenant_id?: string | null;
    declare public title: string;
    declare public message: string;
    declare public action_link?: string | null;
    declare public action_label?: string | null;
    declare public badge_text?: string | null;
    declare public discount_code?: string | null;
    declare public is_active: boolean;
    declare public expires_at?: Date | null;
    declare public created_at?: Date;
    declare public updated_at?: Date;
  }

  MasterAnnouncement.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      target_tenant_id: {
        type: DataTypes.UUID,
        allowNull: true,
      },
      title: {
        type: DataTypes.STRING(255),
        allowNull: false,
      },
      message: {
        type: DataTypes.TEXT,
        allowNull: false,
      },
      action_link: {
        type: DataTypes.STRING(500),
        allowNull: true,
      },
      action_label: {
        type: DataTypes.STRING(100),
        defaultValue: 'Learn More',
      },
      badge_text: {
        type: DataTypes.STRING(50),
        defaultValue: 'Special Offer',
      },
      discount_code: {
        type: DataTypes.STRING(50),
        allowNull: true,
      },
      is_active: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
      },
      expires_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
    },
    {
      sequelize,
      tableName: 'master_announcements',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
    }
  );

  return MasterAnnouncement;
};
