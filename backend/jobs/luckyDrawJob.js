"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.startLuckyDrawJob = startLuckyDrawJob;
const node_cron_1 = __importDefault(require("node-cron"));
const sequelize_1 = require("sequelize");
const { withDistributedLock } = require('../utils/distributedLock');
function startLuckyDrawJob(db) {
    if (!db)
        return;
    console.log('Initializing lucky draw lifecycle cron: 0 0 * * *');
    // Run daily at midnight
    node_cron_1.default.schedule('0 0 * * *', async () => {
        await withDistributedLock(db, 'lucky_draw_lifecycle_job', async () => {
            try {
                const activeCampaigns = await db.models.lucky_draw_campaigns.findAll({
                    where: {
                        status: 'ACTIVE',
                        draw_date: {
                            [sequelize_1.Op.lte]: new Date()
                        }
                    }
                });
                for (const campaign of activeCampaigns) {
                    // Update status to PENDING_RESULT
                    await campaign.update({ status: 'PENDING_RESULT' });
                    // Create a system notification alert for the retailer
                    await db.models.system_notification.create({
                        outlet_id: campaign.outlet_id,
                        module: 'LUCKY_DRAW',
                        title: '⚠️ Lucky Draw Pending!',
                        message: `Please declare the winner for your campaign "${campaign.name}" to reset the limit and start a new draw.`,
                        type: 'WARNING',
                        entity_id: campaign.id,
                        is_read: false
                    });
                    console.log(`[LUCKY DRAW] Campaign "${campaign.name}" (ID: ${campaign.id}) draw date reached. Status changed to PENDING_RESULT.`);
                }
            }
            catch (error) {
                console.error(`[LUCKY DRAW] Lifecycle cron failed: ${error.message}`);
            }
        });
    });
}
module.exports = { startLuckyDrawJob };
