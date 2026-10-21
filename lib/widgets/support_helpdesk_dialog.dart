import 'dart:io';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';

class SupportHelpdeskDialog extends StatefulWidget {
  final int outletId;
  final String? outletCode;

  const SupportHelpdeskDialog({
    super.key,
    this.outletId = 1,
    this.outletCode,
  });

  static void show(BuildContext context, {int outletId = 1, String? outletCode}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SupportHelpdeskDialog(outletId: outletId, outletCode: outletCode),
    );
  }

  @override
  State<SupportHelpdeskDialog> createState() => _SupportHelpdeskDialogState();
}

class _SupportHelpdeskDialogState extends State<SupportHelpdeskDialog> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  String _priority = 'MEDIUM';
  bool _isSubmitting = false;
  bool _isSendingMessage = false;

  Map<String, dynamic>? _activeTicket;
  List<dynamic> _messages = [];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty) {
      showErrorSnackbar('Please enter an issue subject');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final telemetry = {
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'appVersion': '1.0.3+1',
        'outletId': widget.outletId,
        'outletCode': widget.outletCode ?? '',
        'localHostname': Platform.localHostname,
        'reportedAt': DateTime.now().toIso8601String(),
      };

      final payload = {
        'outlet_id': widget.outletId,
        'outlet_code': widget.outletCode,
        'subject': subject,
        'priority': _priority,
        'message': message,
        'telemetry': telemetry,
      };

      final res = await ApiClient.post('/api/v1/control-plane/support/tickets', payload);

      if (res != null && res['success'] == true && mounted) {
        final ticketData = (res['data'] is Map && res['data']['ticket'] != null)
            ? res['data']['ticket']
            : res['data'];

        setState(() {
          _activeTicket = ticketData is Map ? Map<String, dynamic>.from(ticketData) : null;
          _messages = [
            if (message.isNotEmpty)
              {
                'sender_type': 'CLIENT_OUTLET',
                'sender_name': 'Store Cashier / POS Operator',
                'message': message,
                'created_at': DateTime.now().toIso8601String(),
              }
          ];
          _isSubmitting = false;
        });
        if (_activeTicket != null && _activeTicket!['id'] != null) {
          _pollTicketMessages();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendChatMessage() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _activeTicket == null || _activeTicket!['id'] == null) return;

    setState(() => _isSendingMessage = true);

    try {
      final ticketId = _activeTicket!['id'].toString();
      final res = await ApiClient.post('/api/v1/control-plane/support/tickets/$ticketId/messages', {
        'message': text,
        'sender_type': 'CLIENT_OUTLET',
        'sender_name': 'Store Cashier / POS Operator',
      });

      if (res != null && res['success'] == true && mounted) {
        _chatInputController.clear();
        setState(() {
          _messages.add(res['data']);
          _isSendingMessage = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  Future<void> _pollTicketMessages() async {
    if (_activeTicket == null || _activeTicket!['id'] == null || !mounted) return;
    try {
      final ticketId = _activeTicket!['id'].toString();
      final res = await ApiClient.get('/api/v1/control-plane/support/tickets/$ticketId');
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _activeTicket = res['data'];
          _messages = res['data']['messages'] ?? [];
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 680),
        child: _activeTicket == null ? _buildTicketCreationView() : _buildLiveChatView(),
      ),
    );
  }

  Widget _buildTicketCreationView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.support_agent_rounded, color: Color(0xFF0284C7), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Support Console & Diagnostic Helpdesk',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Outlet #${widget.outletId} | Auto-routing to online support engineers',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 28),
          const Text('Issue Subject', style: TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _subjectController,
            style: const TextStyle(color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'e.g. Duplicate bill generation error or thermal printer timeout',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Urgency / Priority: ', style: TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              ...['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].map((p) {
                final isSelected = _priority == p;
                final color = p == 'CRITICAL'
                    ? const Color(0xFFDC2626)
                    : (p == 'HIGH' ? const Color(0xFFEA580C) : const Color(0xFF0284C7));
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      p,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: const Color(0xFFF1F5F9),
                    onSelected: (val) {
                      if (val) setState(() => _priority = p);
                    },
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Detailed Query / Error Log (Optional)', style: TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _messageController,
            maxLines: 4,
            style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Paste stack traces, SQL error codes, or invoice numbers...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isSubmitting ? null : _submitTicket,
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveChatView() {
    final agent = _activeTicket?['agent'];
    final ticketNumber = _activeTicket?['ticket_number'] ?? 'TCK-LIVE';

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF16A34A),
                child: const Icon(Icons.support_agent, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket #$ticketNumber: ${_activeTicket?['subject']}',
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      agent != null
                          ? 'Assigned: ${agent['full_name']} (${agent['role_level']} Specialist)'
                          : 'Routing to available support staff...',
                      style: const TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Chat stream
        Expanded(
          child: Container(
            color: const Color(0xFFF1F5F9), // Clean Light slate chat canvas
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              controller: _chatScrollController,
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isMe = msg['sender_type'] == 'CLIENT_OUTLET';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 450),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF0284C7) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['sender_name'] ?? (isMe ? 'Store Cashier / POS Operator' : 'Support Engineer'),
                          style: TextStyle(
                            color: isMe ? const Color(0xFFE0F2FE) : const Color(0xFF0284C7),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['message'] ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _chatInputController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    onSubmitted: (_) => _sendChatMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Type your message or response...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isSendingMessage
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)))
                    : const Icon(Icons.send_rounded, color: Color(0xFF0284C7)),
                onPressed: _isSendingMessage ? null : _sendChatMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
