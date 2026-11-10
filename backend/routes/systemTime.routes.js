"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
/**
 * GET /api/system/server-time
 *
 * NO authentication required — Flutter calls this at startup before login
 * to anchor its internal clock against the server (PostgreSQL) time.
 *
 * Returns:
 *   { success: true, serverTime: "<ISO8601>", source: "db"|"node" }
 */
router.get('/', async (req, res) => {
    try {
        // Prefer PostgreSQL time so it is independent of OS clock
        const db = req.db || req.propertyDb;
        if (db) {
            const [[{ now }]] = await db.query('SELECT NOW() AS now');
            return res.json({
                success: true,
                serverTime: new Date(now).toISOString(),
                source: 'db'
            });
        }
    }
    catch (_) {
        // fall through to Node fallback
    }
    // Fallback: use Node's Date
    return res.json({
        success: true,
        serverTime: new Date().toISOString(),
        source: 'node'
    });
});

/**
 * GET /api/system/server-time/network-info
 * Returns system network interfaces so client devices can connect over local Wi-Fi / LAN
 */
router.get('/network-info', (req, res) => {
    try {
        const os = require('os');
        const ifaces = os.networkInterfaces();
        const ips = [];
        for (const name in ifaces) {
            for (const net of ifaces[name]) {
                if (net.family === 'IPv4' && !net.internal && !net.address.startsWith('169.254.')) {
                    ips.push({ iface: name, ip: net.address });
                }
            }
        }
        // Prioritize standard home/office subnets: 192.168.x.x, 10.x.x.x, 172.16-31.x.x
        let primaryIp = ips.length > 0 ? ips[0].ip : '127.0.0.1';
        const preferred = ips.find(item => item.ip.startsWith('192.168.') || item.ip.startsWith('10.'));
        if (preferred) {
            primaryIp = preferred.ip;
        }

        return res.json({
            success: true,
            primaryIp,
            ips,
            port: req.socket.localPort || 3000
        });
    } catch (e) {
        return res.status(500).json({ success: false, error: e.message });
    }
});

module.exports = router;
exports.default = router;
