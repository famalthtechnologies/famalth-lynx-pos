import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_client.dart';

class RelationshipManagerCard extends StatefulWidget {
  const RelationshipManagerCard({super.key});

  @override
  State<RelationshipManagerCard> createState() => _RelationshipManagerCardState();
}

class _RelationshipManagerCardState extends State<RelationshipManagerCard> {
  bool _isLoading = true;
  Map<String, dynamic>? _rmData;
  int _daysLeft = 365;

  @override
  void initState() {
    super.initState();
    _fetchRmDetails();
  }

  Future<void> _fetchRmDetails() async {
    try {
      final res = await ApiClient.get('/api/v1/control-plane/license-and-rm-status');
      if (res != null && res['success'] == true && mounted) {
        setState(() {
          _rmData = res['data']?['relationshipManager'] as Map<String, dynamic>?;
          _daysLeft = (res['data']?['daysLeft'] ?? 365) as int;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final hasRm = _rmData != null && (_rmData?['full_name'] != null || _rmData?['fullName'] != null);
    final name = hasRm ? (_rmData?['full_name'] ?? _rmData?['fullName']) : 'Support Desk';
    final designation = hasRm ? (_rmData?['designation'] ?? 'Account Manager') : 'Customer Care Team';
    final phone = hasRm ? (_rmData?['phone'] ?? '') : '';
    final rawWa = hasRm ? (_rmData?['whatsapp_number'] ?? _rmData?['whatsappNumber'] ?? '') : '';
    final wa = rawWa.toString().replaceAll('+', '').replaceAll(' ', '');
    final email = hasRm ? (_rmData?['email'] ?? 'care@famalth.com') : 'care@famalth.com';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0284C7), width: 2),
                ),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.person, color: Color(0xFF0284C7), size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                          ),
                          child: const Text(
                            'ASSIGNED RM',
                            style: TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      designation,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  backgroundColor: const Color(0xFFF0F9FF),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                icon: const Icon(Icons.phone_rounded, size: 16),
                label: Text(phone, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final text = Uri.encodeComponent(
                    'Hello $name, I am reaching out from our store terminal. License Days Left: $_daysLeft.',
                  );
                  launchUrl(
                    Uri.parse('https://wa.me/$wa?text=$text'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                label: const Text('Direct WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  backgroundColor: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => launchUrl(Uri.parse('mailto:$email')),
                icon: const Icon(Icons.mail_outline_rounded, size: 16),
                label: Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
