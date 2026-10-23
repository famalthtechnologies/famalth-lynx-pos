const { Op } = require('sequelize');
const audit = require('../../services/audit.service');
const { createLedgerEntry, dateKey } = require('../../services/cashLedger.service');
const { isBankPayment, debitBankBalance } = require('../../services/bankAccount.service');
exports.getSupplierBills = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { fromDate, toDate, supplierId, status } = req.query;

        const where: any = { outlet_id };

        if (supplierId && supplierId !== '' && supplierId !== 'null') {
            where.supplier_id = Number(supplierId);
        }

        if (status && status !== '' && status !== 'null') {
            where.status = status;
        }

        if (fromDate && toDate) {
            where.bill_date = {
                [Op.between]: [fromDate, toDate]
            };
        }

        const bills = await req.propertyDb.models.supplier_bills.findAll({
            where,
            include: [{
                model: req.propertyDb.models.supplier_master,
                as: 'supplier',
                attributes: ['supplier_name']
            }],
            order: [['bill_date', 'DESC']]
        });

        console.log("BILLS LENGTH:", bills.length);

        const totalPurchase = bills.reduce(
            (s, b) => s + Number(b.bill_amount), 0
        );

        const totalPaid = bills.reduce(
            (s, b) => s + Number(b.paid_amount), 0
        );

        const totalUnpaid = bills.reduce(
            (s, b) =>
                s + (Number(b.bill_amount) - Number(b.paid_amount)), 0
        );

        const grns = await req.propertyDb.models.goods_receipts.findAll({
            where: { outlet_id },
            attributes: ['grn_no', 'supplier_id', 'supplier_bill_no']
        });

        const grnMap = {};
        for (const g of grns) {
            if (g.supplier_id && g.supplier_bill_no) {
                const key = `${g.supplier_id}_${String(g.supplier_bill_no).trim()}`;
                grnMap[key] = g.grn_no;
            }
        }

        const billsWithGrn = bills.map(b => {
            const json = b.toJSON();
            const key = `${b.supplier_id}_${String(b.bill_no || '').trim()}`;
            json.grn_no = grnMap[key] || '';
            return json;
        });

        res.json({
            success: true,
            summary: {
                totalPurchase,
                totalPaid,
                totalUnpaid
            },
            data: billsWithGrn
        });

    } catch (err) {
        console.error(err);
        res.status(500).json({
            success: false,
            error: err.message
        });
    }
};

exports.getSupplierBillDetails = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const billId = Number(req.params.billId);

        if (!Number.isFinite(billId) || billId <= 0) {
            return res.status(400).json({
                success: false,
                message: 'Invalid bill id'
            });
        }

        const bill = await req.propertyDb.models.supplier_bills.findOne({
            where: { id: billId, outlet_id },
            include: [{
                model: req.propertyDb.models.supplier_master,
                as: 'supplier',
                attributes: ['supplier_name', 'phone', 'address']
            }]
        });

        if (!bill) {
            return res.status(404).json({
                success: false,
                message: 'Supplier bill not found'
            });
        }

        const grn = await req.propertyDb.models.goods_receipts.findOne({
            where: {
                outlet_id,
                supplier_id: bill.supplier_id,
                supplier_bill_no: bill.bill_no
            },
            include: [{
                model: req.propertyDb.models.goods_receipt_items,
                as: 'items'
            }],
            order: [[{ model: req.propertyDb.models.goods_receipt_items, as: 'items' }, 'id', 'ASC']]
        });

        res.json({
            success: true,
            data: {
                bill: bill.toJSON(),
                grn: grn ? grn.toJSON() : null,
                items: grn?.items?.map((item) => item.toJSON()) || []
            }
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

async function calculateSupplierAvailableCredit(db: any, outlet_id: any, supplier_id: any, transaction: any = null) {
    const totalCreditRefunded = await db.models.supplier_return_refunds.sum('amount', {
        where: {
            outlet_id,
            supplier_id,
            payment_mode: 'CREDIT'
        },
        transaction
    }) || 0;

    const totalCreditAdjusted = await db.models.supplier_payments.sum('credit_adjusted', {
        where: {
            outlet_id,
            supplier_id
        },
        transaction
    }) || 0;

    return Math.max(0, Number(totalCreditRefunded) - Number(totalCreditAdjusted));
}

exports.getAvailableCredit = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const supplier_id = Number(req.params.supplierId);

        if (!supplier_id) {
            return res.status(400).json({ success: false, message: 'Invalid supplier id' });
        }

        const availableCredit = await calculateSupplierAvailableCredit(req.propertyDb, outlet_id, supplier_id);

        res.json({
            success: true,
            data: {
                availableCredit
            }
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.paySupplierBill = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;

        const { bill_id, amount } = req.body;
        const credit_adjusted = Number(req.body.credit_adjusted || 0);
        const paymentMode = String(req.body.payment_mode || 'CASH').trim().toUpperCase();
        const referenceNo = String(req.body.reference_no || '').trim() || null;
        const paymentDate = dateKey(req.body.payment_date || new Date());
        const note = String(req.body.note || '').trim() || null;

        const Bill = req.propertyDb.models.supplier_bills;

        const bill = await Bill.findOne({
            where: { id: bill_id, outlet_id },
            transaction: t
        });

        if (!bill) {
            await t.rollback();
            return res.status(404).json({ success: false });
        }

        const balance = Number(bill.bill_amount) - Number(bill.paid_amount);
        const numAmount = Number(amount || 0);
        const creditAdjusted = Number(credit_adjusted || 0);
        let round_off = Number(req.body.round_off || req.body.round_off_amount || 0);

        // Auto-calculate round-off if user rounded to nearest integer (e.g. paying 102.00 on 101.76 balance)
        if (numAmount > 0 && Math.abs((numAmount + creditAdjusted) - balance) <= 1.0 && round_off === 0) {
            if (numAmount + creditAdjusted > balance) {
                round_off = Number(((numAmount + creditAdjusted) - balance).toFixed(2));
            }
        }

        const effectiveApplied = numAmount + creditAdjusted;
        const totalSettlementImpact = effectiveApplied + (round_off < 0 ? Math.abs(round_off) : 0);
        const isFullSettlement = (balance - totalSettlementImpact) <= 0.01;

        if (numAmount < 0 || creditAdjusted < 0) {
            await t.rollback();
            return res.status(400).json({
                message: 'Invalid payment amount'
            });
        }

        if (numAmount === 0 && creditAdjusted === 0) {
            await t.rollback();
            return res.status(400).json({
                message: 'Payment amount or credit required'
            });
        }

        if (!isFullSettlement && effectiveApplied > balance + 1.0) {
            await t.rollback();
            return res.status(400).json({
                message: 'Payment amount exceeds outstanding balance'
            });
        }

        if (credit_adjusted > 0) {
            const availableCredit = await calculateSupplierAvailableCredit(req.propertyDb, outlet_id, bill.supplier_id, t);
            if (credit_adjusted > availableCredit + 0.009) {
                await t.rollback();
                return res.status(400).json({
                    message: `Adjusted credit exceeds available credit. Available: ${availableCredit.toFixed(2)}`
                });
            }
        }

        const oldBillData = bill.toJSON();

        if (isFullSettlement) {
            bill.paid_amount = Number(bill.bill_amount);
            bill.status = 'PAID';
        } else {
            bill.paid_amount = Number(bill.paid_amount) + effectiveApplied + (round_off < 0 ? Math.abs(round_off) : 0);
            if (bill.paid_amount >= Number(bill.bill_amount) - 0.009) {
                bill.paid_amount = Number(bill.bill_amount);
                bill.status = 'PAID';
            } else {
                bill.status = bill.paid_amount > 0 ? 'PARTIAL' : 'UNPAID';
            }
        }

        if (round_off !== 0) {
            bill.round_off_amount = Number((Number(bill.round_off_amount || 0) + round_off).toFixed(2));
        }

        await bill.save({ transaction: t });

        await req.propertyDb.models.supplier_payments.create({
            outlet_id,
            supplier_id: bill.supplier_id,
            bill_id: bill.id,
            payment_date: paymentDate,
            amount: numAmount,
            credit_adjusted: creditAdjusted,
            round_off,
            payment_mode: paymentMode,
            reference_no: referenceNo,
            created_by: req.user.id
        }, { transaction: t });

        const supplier = await req.propertyDb.models.supplier_master.findByPk(
            bill.supplier_id,
            { transaction: t }
        );

        const grnRecord = await req.propertyDb.models.goods_receipts.findOne({
            where: {
                outlet_id,
                supplier_id: bill.supplier_id,
                supplier_bill_no: bill.bill_no
            },
            transaction: t
        });

        const grnNo = grnRecord?.grn_no || '';
        const grnTag = grnNo ? ` (GRN: ${grnNo})` : '';
        const supplierVNo = bill.bill_no
            ? (bill.bill_no.startsWith('PV-') ? bill.bill_no : `PV-${bill.bill_no}${grnTag}`)
            : (grnNo ? `PV-${grnNo}` : `PV-SUP`);

        const remainingBal = bill.status === 'PAID' ? 0 : Math.max(0, Number(bill.bill_amount) - Number(bill.paid_amount));
        try {
            const prevEntries = await req.propertyDb.models.cash_ledger.findAll({
                where: {
                    outlet_id,
                    reference_type: 'SUPPLIER_BILL',
                    reference_id: String(bill.id)
                },
                transaction: t
            });
            for (const prevEntry of prevEntries) {
                let updatedNotes = prevEntry.notes || '';
                if (remainingBal <= 0.009) {
                    updatedNotes = updatedNotes.replace(/-?\s*outstanding\s+[0-9]+(?:\.[0-9]+)?/gi, '(Settled / Paid)');
                    if (!updatedNotes.includes('(Settled / Paid)')) {
                        updatedNotes = `${updatedNotes} (Settled / Paid)`.trim();
                    }
                }
                await prevEntry.update({
                    adjustment_amount: 0,
                    notes: updatedNotes
                }, { transaction: t });
            }
        } catch (uErr) {
            console.error('Error updating GRN ledger entry notes:', uErr);
        }

        if (numAmount > 0) {
            const paymentNote = note || (remainingBal <= 0.009
                ? `Supplier payment for bill ${bill.bill_no}${grnTag} (Settled / Paid)`
                : `Supplier payment for bill ${bill.bill_no}${grnTag} - outstanding ${remainingBal.toFixed(2)}`);

            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id,
                txn_date: paymentDate,
                transaction_type: 'SUPPLIER_PAYMENT',
                reference_type: 'SUPPLIER_BILL',
                reference_id: bill.id,
                reference_no: supplierVNo,
                party_name: supplier?.supplier_name || null,
                payment_method: paymentMode,
                amount_out: numAmount,
                adjustment_amount: remainingBal > 0.009 ? remainingBal : 0,
                notes: paymentNote,
                created_by: req.user.id,
                transaction: t
            });
        }

        await audit.log({
            req,
            module: 'SUPPLIER_PAYMENT',
            action: 'PAY',
            table: 'supplier_bills',
            recordId: bill.id,
            old_data: oldBillData,
            new_data: bill.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        await t.commit();

        // Auto-create accounting voucher safely after transaction commit
        if (amount > 0) {
            try {
                if (isBankPayment(paymentMode)) {
                    await debitBankBalance({ db: req.propertyDb, outlet_id, amount });
                }
                const { getNextNumber } = require('../../services/numbering.service');
                let vNo;
                try {
                    vNo = await getNextNumber(req.propertyDb, outlet_id, 'PAYMENT');
                } catch (_) {
                    vNo = supplierVNo;
                }
                const header = await req.propertyDb.models.accounting_vouchers.create({
                    outlet_id,
                    voucher_no: vNo,
                    voucher_type: 'PAYMENT',
                    voucher_date: paymentDate,
                    total_debit: amount,
                    total_credit: amount,
                    narration: note || `Supplier payment for bill ${bill.bill_no} (${supplier?.supplier_name || 'Vendor'})`,
                    payment_mode: paymentMode,
                    status: 'POSTED',
                    created_by: req.user.id
                });

                await req.propertyDb.models.voucher_lines.bulkCreate([
                    {
                        voucher_id: header.id,
                        line_type: 'DEBIT',
                        account_name: supplier?.supplier_name || 'Accounts Payable',
                        account_type: 'LIABILITY',
                        debit_amount: amount,
                        credit_amount: 0
                    },
                    {
                        voucher_id: header.id,
                        line_type: 'CREDIT',
                        account_name: paymentMode || 'CASH',
                        account_type: 'ASSET',
                        debit_amount: 0,
                        credit_amount: amount
                    }
                ]);
            } catch (vErr) {
                console.error('Error auto-creating supplier payment voucher:', vErr);
            }
        }

        res.json({ success: true });

    } catch (err) {

        if (!t.finished) {
            await t.rollback();
        }

        res.status(500).json({
            success: false,
            error: err.message
        });
    }
};


exports.getBillPayments = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const billId = req.params.billId;

        const payments = await req.propertyDb.models.supplier_payments.findAll({
            where: { bill_id: billId, outlet_id },
            order: [['payment_date', 'ASC']]
        });

        res.json({ success: true, data: payments });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};


module.exports = exports;
export default exports;
