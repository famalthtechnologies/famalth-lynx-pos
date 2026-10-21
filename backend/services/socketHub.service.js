"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.initSocketHub = initSocketHub;
exports.getSocketHub = getSocketHub;
exports.broadcastNewSupportTicket = broadcastNewSupportTicket;
exports.broadcastTicketMessage = broadcastTicketMessage;
exports.broadcastRemoteKillSwitch = broadcastRemoteKillSwitch;
exports.broadcastQuotaUpdated = broadcastQuotaUpdated;
const socket_io_1 = require("socket.io");
let ioInstance = null;
function initSocketHub(httpServer) {
    const io = new socket_io_1.Server(httpServer, {
        cors: {
            origin: '*',
            methods: ['GET', 'POST'],
            credentials: true,
        },
    });
    io.on('connection', (socket) => {
        const { role, tenant_id, outlet_id, client_code } = socket.handshake.query;
        console.log(`🔌 [SOCKET] New client connected: ${socket.id} (Role: ${role || 'ANON'})`);
        // 1. Join tenant & outlet specific rooms for live push notifications & kill-switch
        if (tenant_id) {
            socket.join(`tenant:${tenant_id}`);
        }
        if (outlet_id) {
            socket.join(`outlet:${outlet_id}`);
        }
        if (client_code) {
            socket.join(`client:${client_code}`);
        }
        // 2. Control plane staff join global broadcast room
        if (role === 'SUPPORT_AGENT' || role === 'SUPER_ADMIN' || role === 'RESELLER' || role === 'RM') {
            socket.join('control_plane_agents');
            console.log(`🛡️ [SOCKET] Support Staff joined room control_plane_agents: ${socket.id}`);
        }
        // 3. Join specific support ticket room for live chat & diagnostic streaming
        socket.on('join_ticket', (ticketId) => {
            socket.join(`ticket:${ticketId}`);
            console.log(`💬 [SOCKET] Client joined ticket:${ticketId}`);
        });
        socket.on('leave_ticket', (ticketId) => {
            socket.leave(`ticket:${ticketId}`);
        });
        socket.on('disconnect', () => {
            console.log(`🔌 [SOCKET] Client disconnected: ${socket.id}`);
        });
    });
    ioInstance = io;
    return io;
}
function getSocketHub() {
    return ioInstance;
}
/**
 * Broadcasts a newly raised ticket with sound chime trigger to all online support staff.
 */
function broadcastNewSupportTicket(ticket) {
    if (!ioInstance)
        return;
    ioInstance.to('control_plane_agents').emit('new_support_ticket', {
        type: 'TICKET_CREATED',
        soundChime: 'urgent_alert.mp3',
        ticket,
        timestamp: new Date(),
    });
}
/**
 * Broadcasts a live chat message to everyone in the ticket room.
 */
function broadcastTicketMessage(ticketId, message) {
    if (!ioInstance)
        return;
    ioInstance.to(`ticket:${ticketId}`).emit('ticket_message_received', message);
}
/**
 * Broadcasts an emergency remote kill switch / deactivation event to a specific outlet or tenant.
 */
function broadcastRemoteKillSwitch(target) {
    if (!ioInstance)
        return;
    const payload = {
        action: 'REMOTE_KILL_SWITCH',
        status: target.status,
        reason: target.reason,
        timestamp: new Date(),
    };
    if (target.outletId) {
        ioInstance.to(`outlet:${target.outletId}`).emit('remote_control_event', payload);
    }
    if (target.tenantId) {
        ioInstance.to(`tenant:${target.tenantId}`).emit('remote_control_event', payload);
    }
}
/**
 * Broadcasts quota updates (e.g. license increase, seat increase) in real-time.
 */
function broadcastQuotaUpdated(tenantId, license) {
    if (!ioInstance)
        return;
    ioInstance.to(`tenant:${tenantId}`).emit('license_quota_updated', {
        action: 'LICENSE_UPDATED',
        license,
        timestamp: new Date(),
    });
}
exports.default = {
    initSocketHub,
    getSocketHub,
    broadcastNewSupportTicket,
    broadcastTicketMessage,
    broadcastRemoteKillSwitch,
    broadcastQuotaUpdated,
};
