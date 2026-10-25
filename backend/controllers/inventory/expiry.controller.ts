import { Request, Response } from 'express';
import { Op, Sequelize } from 'sequelize';

export const getExpiryTracker = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;
        const { search, status_filter } = req.query as any;

        // Fetch all goods receipt items that have expiry_date set
        const receiptItems = await (req as any).propertyDb.models.goods_receipt_items.findAll({
            where: {
                expiry_date: {
                    [Op.ne]: null
                }
            },
            include: [
                {
                    model: (req as any).propertyDb.models.goods_receipts,
                    as: 'grn',
                    where: { outlet_id },
                    attributes: ['id', 'grn_no', 'receipt_date', 'supplier_id', 'supplier_bill_no']
                }
            ],
            order: [
                ['expiry_date', 'ASC'],
                ['id', 'DESC']
            ]
        });

        // Group by item_code or item_id
        const itemMap: Record<string, any> = {};

        for (const item of receiptItems) {
            const key = item.item_id ? String(item.item_id) : String(item.item_code || item.item_name);
            if (!itemMap[key]) {
                itemMap[key] = {
                    item_id: item.item_id,
                    item_code: item.item_code,
                    item_name: item.item_name,
                    brand: item.brand,
                    unit: item.unit,
                    total_received_qty: 0,
                    batches: []
                };
            }

            itemMap[key].total_received_qty += Number(item.qty || 0);
            itemMap[key].batches.push({
                grn_id: item.grn_id,
                grn_no: item.grn?.grn_no || '--',
                receipt_date: item.grn?.receipt_date,
                supplier_id: item.grn?.supplier_id,
                supplier_bill_no: item.grn?.supplier_bill_no,
                qty: Number(item.qty || 0),
                rate: Number(item.rate || 0),
                expiry_date: item.expiry_date
            });
        }

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const allEntries: any[] = [];
        for (const key of Object.keys(itemMap)) {
            const data = itemMap[key];
            const batches = data.batches;

            // 1. Get live stock balance from item_master or stock_ledger
            let currentStock = data.total_received_qty;
            if (data.item_id) {
                const itemMaster = await (req as any).propertyDb.models.item_master.findByPk(data.item_id, {
                    attributes: ['opening_balance']
                });
                const lastLedger = await (req as any).propertyDb.models.stock_ledger.findOne({
                    where: { outlet_id, item_code: data.item_code },
                    order: [['id', 'DESC']],
                    attributes: ['balance']
                });
                if (lastLedger && lastLedger.balance !== null) {
                    currentStock = Number(lastLedger.balance);
                } else if (itemMaster && itemMaster.opening_balance !== null) {
                    currentStock = Number(itemMaster.opening_balance);
                }
            }

            // 2. FEFO (First Expired First Out) stock deduction:
            // Earliest expiring batches are deducted first!
            const totalReceived = data.total_received_qty;
            let totalSold = Math.max(0, totalReceived - currentStock);

            // Sort batches by expiry_date ASC
            const sortedByExpiryAsc = [...batches].sort((a: any, b: any) => new Date(a.expiry_date).getTime() - new Date(b.expiry_date).getTime());

            let remainingSold = totalSold;
            for (const b of sortedByExpiryAsc) {
                const bQty = Number(b.qty || 0);
                if (remainingSold >= bQty) {
                    b.qty_sold = bQty;
                    b.available_qty = 0;
                    b.status = 'SOLD_OUT';
                    remainingSold -= bQty;
                } else {
                    b.qty_sold = remainingSold;
                    b.available_qty = Math.max(0, bQty - remainingSold);
                    remainingSold = 0;

                    const expDate = new Date(b.expiry_date);
                    const diffTime = expDate.getTime() - today.getTime();
                    const daysLeft = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
                    b.days_left = daysLeft;
                    b.status = daysLeft < 0 ? 'EXPIRED' : (daysLeft <= 30 ? 'CRITICAL' : (daysLeft <= 90 ? 'WARNING' : 'HEALTHY'));
                }
            }

            // 3. Identify active batch with remaining available stock
            const activeBatches = sortedByExpiryAsc.filter(b => b.available_qty > 0);
            const nearestActiveBatch = activeBatches.length > 0 ? activeBatches[0] : (sortedByExpiryAsc.length > 0 ? sortedByExpiryAsc[sortedByExpiryAsc.length - 1] : null);

            let status = 'HEALTHY';
            let daysRemaining = 999;
            let nearestExpiryDate = nearestActiveBatch ? nearestActiveBatch.expiry_date : 'N/A';

            if (currentStock <= 0) {
                status = 'SOLD_OUT';
                daysRemaining = 0;
            } else if (nearestActiveBatch) {
                const expDate = new Date(nearestActiveBatch.expiry_date);
                const diffTime = expDate.getTime() - today.getTime();
                daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

                if (daysRemaining < 0) {
                    status = 'EXPIRED';
                } else if (daysRemaining <= 30) {
                    status = 'CRITICAL';
                } else if (daysRemaining <= 90) {
                    status = 'WARNING';
                } else {
                    status = 'HEALTHY';
                }
            }

            // Sort batches by receipt_date descending for comparison (newest vs older active)
            const batchesByReceipt = [...batches].sort((a: any, b: any) => new Date(b.receipt_date).getTime() - new Date(a.receipt_date).getTime());
            const newestBatch = batchesByReceipt[0];
            const olderBatches = batchesByReceipt.slice(1);
            const oldestBatchWithStock = olderBatches.find(b => b.available_qty > 0) || (olderBatches.length > 0 ? olderBatches[olderBatches.length - 1] : null);

            let expiryComparison = 'NORMAL';
            let daysDifference = 0;
            if (oldestBatchWithStock) {
                const newExpTime = new Date(newestBatch.expiry_date).getTime();
                const oldExpTime = new Date(oldestBatchWithStock.expiry_date).getTime();
                const diffDays = Math.round((newExpTime - oldExpTime) / (1000 * 60 * 60 * 24));
                daysDifference = diffDays;
                if (diffDays < 0) {
                    expiryComparison = 'NEW_SHORTER_THAN_OLD';
                } else if (diffDays > 0) {
                    expiryComparison = 'NEW_LONGER_THAN_OLD';
                } else {
                    expiryComparison = 'SAME_EXPIRY';
                }
            }

            const itemEntry = {
                item_id: data.item_id,
                item_code: data.item_code,
                item_name: data.item_name,
                brand: data.brand || 'General',
                unit: data.unit || 'PCS',
                current_stock: currentStock,
                total_received_qty: data.total_received_qty,
                nearest_expiry_date: nearestExpiryDate,
                days_remaining: daysRemaining,
                status,
                active_batch_available_qty: nearestActiveBatch ? nearestActiveBatch.available_qty : 0,
                active_batches_count: activeBatches.length,
                newest_batch_expiry: newestBatch.expiry_date,
                old_batch_expiry: oldestBatchWithStock ? oldestBatchWithStock.expiry_date : null,
                expiry_comparison: expiryComparison,
                days_difference: daysDifference,
                batches_count: batches.length,
                batches: sortedByExpiryAsc
            };

            allEntries.push(itemEntry);
        }

        // Sort by nearest active expiry first (lowest days_remaining first)
        allEntries.sort((a, b) => a.days_remaining - b.days_remaining);

        // Summary KPI counts across all tracked batches
        const expiredCount = allEntries.filter(i => i.status === 'EXPIRED').length;
        const criticalCount = allEntries.filter(i => i.status === 'CRITICAL').length;
        const warningCount = allEntries.filter(i => i.status === 'WARNING').length;
        const healthyCount = allEntries.filter(i => i.status === 'HEALTHY').length;
        const newShorterAlerts = allEntries.filter(i => i.expiry_comparison === 'NEW_SHORTER_THAN_OLD').length;

        // Apply filters to list returned
        let filteredList = [...allEntries];
        if (status_filter && status_filter !== 'ALL') {
            filteredList = filteredList.filter(i => i.status === status_filter);
        }
        if (search) {
            const q = search.toLowerCase();
            filteredList = filteredList.filter(i =>
                (i.item_name && i.item_name.toLowerCase().includes(q)) ||
                (i.item_code && i.item_code.toLowerCase().includes(q)) ||
                (i.brand && i.brand.toLowerCase().includes(q))
            );
        }

        return res.json({
            success: true,
            summary: {
                total_tracked: allEntries.length,
                expired: expiredCount,
                critical: criticalCount,
                warning: warningCount,
                healthy: healthyCount,
                new_shorter_than_old: newShorterAlerts
            },
            data: filteredList
        });
    } catch (err: any) {
        console.error('[GET EXPIRY TRACKER ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

export const getExpiryLedgerByItem = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;
        const itemId = req.params.itemId;

        const whereItem: any = {};
        if (Number(itemId)) {
            whereItem.item_id = Number(itemId);
        } else {
            whereItem.item_code = itemId;
        }

        const items = await (req as any).propertyDb.models.goods_receipt_items.findAll({
            where: {
                ...whereItem,
                expiry_date: { [Op.ne]: null }
            },
            include: [
                {
                    model: (req as any).propertyDb.models.goods_receipts,
                    as: 'grn',
                    where: { outlet_id },
                    attributes: ['id', 'grn_no', 'receipt_date', 'supplier_id', 'supplier_bill_no']
                }
            ],
            order: [['expiry_date', 'ASC'], ['id', 'ASC']]
        });

        // Supplier names lookup
        const supplierIds = [...new Set(items.map((i: any) => i.grn?.supplier_id).filter(Boolean))];
        const suppliers = await (req as any).propertyDb.models.supplier_master.findAll({
            where: { id: { [Op.in]: supplierIds } },
            attributes: ['id', 'supplier_name']
        });
        const supplierMap: Record<number, string> = {};
        suppliers.forEach((s: any) => supplierMap[s.id] = s.supplier_name);

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        // Fetch current live stock balance
        let currentStock = 0;
        const sample = items[0];
        if (sample) {
            const itemCode = sample.item_code;
            const itemIdNum = sample.item_id;
            if (itemIdNum) {
                const itemMaster = await (req as any).propertyDb.models.item_master.findByPk(itemIdNum, {
                    attributes: ['opening_balance']
                });
                if (itemMaster && itemMaster.opening_balance !== null) {
                    currentStock = Number(itemMaster.opening_balance);
                }
            }
            if (itemCode) {
                const lastLedger = await (req as any).propertyDb.models.stock_ledger.findOne({
                    where: { outlet_id, item_code: itemCode },
                    order: [['id', 'DESC']],
                    attributes: ['balance']
                });
                if (lastLedger && lastLedger.balance !== null) {
                    currentStock = Number(lastLedger.balance);
                }
            }
        }

        const totalReceived = items.reduce((sum: number, i: any) => sum + Number(i.qty || 0), 0);
        let remainingSold = Math.max(0, totalReceived - currentStock);

        // Calculate FEFO stock depletion per batch
        const ledger = items.map((i: any, index: number) => {
            const expDate = new Date(i.expiry_date);
            const diffTime = expDate.getTime() - today.getTime();
            const daysLeft = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
            const batchQty = Number(i.qty || 0);

            let qtySold = 0;
            let qtyAvailable = 0;

            if (remainingSold >= batchQty) {
                qtySold = batchQty;
                qtyAvailable = 0;
                remainingSold -= batchQty;
            } else {
                qtySold = remainingSold;
                qtyAvailable = Math.max(0, batchQty - remainingSold);
                remainingSold = 0;
            }

            let status = 'ACTIVE';
            if (qtyAvailable <= 0) {
                status = 'SOLD OUT';
            } else if (daysLeft < 0) {
                status = 'EXPIRED';
            } else if (daysLeft <= 30) {
                status = 'CRITICAL';
            } else if (daysLeft <= 90) {
                status = 'WARNING';
            } else {
                status = 'ACTIVE';
            }

            return {
                batch_no: `BATCH-${i.grn?.grn_no || index + 1}`,
                grn_no: i.grn?.grn_no || '--',
                receipt_date: i.grn?.receipt_date,
                supplier_bill_no: i.grn?.supplier_bill_no || '--',
                supplier_name: supplierMap[i.grn?.supplier_id] || 'Direct Supplier',
                qty_received: batchQty,
                qty_sold: qtySold,
                qty_available: qtyAvailable,
                purchase_rate: Number(i.rate || 0),
                expiry_date: i.expiry_date,
                days_left: daysLeft,
                status: status,
                is_latest_receiving: index === items.length - 1
            };
        });

        return res.json({
            success: true,
            data: ledger,
            ledger: ledger
        });
    } catch (err: any) {
        console.error('[GET EXPIRY LEDGER ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

export const triggerExpiryNotifications = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;
        const today = new Date();
        const thirtyDaysLater = new Date();
        thirtyDaysLater.setDate(today.getDate() + 30);

        const expiringItems = await (req as any).propertyDb.models.goods_receipt_items.findAll({
            where: {
                expiry_date: {
                    [Op.lte]: thirtyDaysLater.toISOString().split('T')[0]
                }
            },
            include: [
                {
                    model: (req as any).propertyDb.models.goods_receipts,
                    as: 'grn',
                    where: { outlet_id },
                    attributes: ['id', 'grn_no', 'receipt_date']
                }
            ],
            order: [['expiry_date', 'ASC']]
        });

        let createdCount = 0;
        for (const item of expiringItems) {
            const expDate = new Date(item.expiry_date);
            const daysLeft = Math.ceil((expDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));

            const title = daysLeft < 0 ? `🚨 Expired Stock: ${item.item_name}` : `⚠️ Critical Expiry (<30d): ${item.item_name}`;
            const message = `Item ${item.item_name} (Code: ${item.item_code || '--'}, Batch GRN #${item.grn?.grn_no || '--'}) ${daysLeft < 0 ? `expired on ${item.expiry_date}.` : `will expire on ${item.expiry_date} (${daysLeft} days remaining).`} Please review inventory.`;

            // Check if notification exists
            const existing = await (req as any).propertyDb.models.system_notifications.findOne({
                where: {
                    outlet_id,
                    module: 'EXPIRY_ALERT',
                    entity_id: item.id
                }
            });

            if (!existing) {
                await (req as any).propertyDb.models.system_notifications.create({
                    outlet_id,
                    module: 'EXPIRY_ALERT',
                    title,
                    message,
                    type: daysLeft < 0 ? 'CRITICAL' : 'WARNING',
                    entity_id: item.id,
                    is_read: false
                });
                createdCount++;
            }
        }

        return res.json({
            success: true,
            message: `Batch expiry scan completed. ${createdCount} notification alerts generated.`,
            count: createdCount
        });
    } catch (err: any) {
        console.error('[TRIGGER EXPIRY ALERTS ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};
