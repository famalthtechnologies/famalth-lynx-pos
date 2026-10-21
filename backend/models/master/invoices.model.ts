import { Sequelize, DataTypes, Model } from 'sequelize';

export interface InvoiceAttributes {
  id?: string;
  tenant_id: string;
  invoice_number: string;
  billing_period_start: Date;
  billing_period_end: Date;
  due_date: Date;
  subtotal: number;
  tax_rate: number;
  tax_amount: number;
  total_amount: number;
  status: string;
  pdf_data?: string | null;
  created_at?: Date;
  updated_at?: Date;
  paid_at?: Date | null;
}

export default (sequelize: Sequelize) => {
  class MasterInvoice extends Model<InvoiceAttributes> implements InvoiceAttributes {
    declare public id: string;
    declare public tenant_id: string;
    declare public invoice_number: string;
    declare public billing_period_start: Date;
    declare public billing_period_end: Date;
    declare public due_date: Date;
    declare public subtotal: number;
    declare public tax_rate: number;
    declare public tax_amount: number;
    declare public total_amount: number;
    declare public status: string;
    declare public pdf_data?: string | null;
    declare public created_at?: Date;
    declare public updated_at?: Date;
    declare public paid_at?: Date | null;
  }

  MasterInvoice.init(
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
      invoice_number: {
        type: DataTypes.STRING(100),
        allowNull: false,
        unique: true,
      },
      billing_period_start: {
        type: DataTypes.DATEONLY,
        allowNull: false,
      },
      billing_period_end: {
        type: DataTypes.DATEONLY,
        allowNull: false,
      },
      due_date: {
        type: DataTypes.DATEONLY,
        allowNull: false,
      },
      subtotal: {
        type: DataTypes.DECIMAL(12, 2),
        allowNull: false,
      },
      tax_rate: {
        type: DataTypes.DECIMAL(5, 2),
        defaultValue: 18.00,
      },
      tax_amount: {
        type: DataTypes.DECIMAL(12, 2),
        allowNull: false,
      },
      total_amount: {
        type: DataTypes.DECIMAL(12, 2),
        allowNull: false,
      },
      status: {
        type: DataTypes.STRING(50),
        defaultValue: 'ISSUED',
      },
      pdf_data: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      paid_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
    },
    {
      sequelize,
      tableName: 'master_invoices',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
    }
  );

  return MasterInvoice;
};
