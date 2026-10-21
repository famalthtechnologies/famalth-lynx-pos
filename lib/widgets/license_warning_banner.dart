import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_client.dart';

class LicenseWarningBanner extends StatefulWidget {
  final VoidCallback? onContactRm;

  const LicenseWarningBanner({super.key, this.onContactRm});

  @override
  State<LicenseWarningBanner> createState() => _LicenseWarningBannerState();
}

class _LicenseWarningBannerState extends State<LicenseWarningBanner> {
  bool _isLoading = true;
  bool _warningZone = false;
  String _warningLevel = 'SAFE';
  int _daysLeft = 365;
  String? _validTill;
  String? _softwareStartDate;
  String? _nextPaymentDate;
  int _gracePeriodDays = 15;
  String _paymentStatus = 'PAID';
  bool _isPendingPayment = false;
  num _totalPaymentAmount = 5898.82;
  Map<String, dynamic>? _rmData;
  Map<String, dynamic>? _supportAgent;
  Map<String, dynamic>? _tenantData;

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';
    try {
      final dt = value is DateTime ? value : DateTime.parse(value.toString());
      return '${dt.day.toString().padLeft(2, '0')} ${_monthNames[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return value.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchLicenseAndRmStatus();
  }

  Future<void> _fetchLicenseAndRmStatus() async {
    try {
      final res = await ApiClient.get('/api/v1/control-plane/license-and-rm-status');
      if (res != null && res['success'] == true && mounted) {
        final data = res['data'] ?? {};
        setState(() {
          _daysLeft = (data['daysLeft'] ?? 365) as int;
          _warningZone = (data['warningZone'] ?? false) as bool;
          _warningLevel = (data['warningLevel'] ?? 'SAFE').toString();
          _validTill = data['validTill']?.toString();
          _softwareStartDate = data['softwareStartDate']?.toString();
          _nextPaymentDate = data['nextPaymentDate']?.toString();
          _gracePeriodDays = (data['gracePeriodDays'] ?? 15) as int;
          _paymentStatus = (data['paymentStatus'] ?? 'PAID').toString();
          _isPendingPayment = (data['isPendingPayment'] ?? false) as bool;
          _totalPaymentAmount = (data['totalPaymentAmount'] ?? 5898.82) as num;
          _rmData = data['relationshipManager'] as Map<String, dynamic>?;
          _supportAgent = data['assignedSupportAgent'] as Map<String, dynamic>?;
          _tenantData = data['tenant'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadInvoice() async {
    final tenantId = _tenantData?['id'];
    if (tenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant metadata not ready for invoice download.'), backgroundColor: Colors.amber),
      );
      return;
    }
    final url = '${ApiClient.baseUrl}/api/v1/control-plane/invoices/download/$tenantId';
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening Tax Invoice PDF...'),
          backgroundColor: Color(0xFF0284C7),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open invoice PDF: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showProfileModal(BuildContext context) {
    final isPaid = _paymentStatus == 'PAID';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    child: const Icon(Icons.apartment_rounded, color: Color(0xFF0284C7), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tenantData?['legal_name'] ?? 'Client Enterprise Property',
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Client Code: ${_tenantData?['client_code'] ?? 'CL-001'}  •  ${_tenantData?['email'] ?? ''}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0), height: 28),

              // Subscription & License Status Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subscription Status:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                          ),
                          child: Text(
                            isPaid ? 'PAID / ACTIVE' : 'PAYMENT PENDING',
                            style: TextStyle(
                              color: isPaid ? const Color(0xFF10B981) : const Color(0xFFD97706),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Software Start Date', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(_formatDate(_softwareStartDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Renewal / Valid Till', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('${_formatDate(_validTill)} ($_daysLeft days left)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Next Payment Date', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(_formatDate(_nextPaymentDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Amount Due / Subscription Fee', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('₹$_totalPaymentAmount (incl. GST)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Grace Period: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        Text('$_gracePeriodDays Days post-expiry before system lock', style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Download Latest Tax Invoice Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _downloadInvoice,
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('Download Latest Subscription Tax Invoice (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 20),

              // Relationship Manager Section
              const Text('Dedicated Relationship Manager', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_rmData != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                            child: const Icon(Icons.person_pin_rounded, color: Color(0xFF10B981), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_rmData?['full_name'] ?? 'Account Manager', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14)),
                                Text(_rmData?['designation'] ?? 'Enterprise Account Executive', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              ],
                            ),
                          ),
                          if (_rmData?['phone'] != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                              onPressed: () => launchUrl(Uri.parse('tel:${_rmData!['phone']}')),
                              icon: const Icon(Icons.call, size: 14),
                              label: const Text('Call', style: TextStyle(fontSize: 11)),
                            ),
                          const SizedBox(width: 6),
                          if (_rmData?['whatsapp_number'] != null || _rmData?['phone'] != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                              onPressed: () {
                                final wa = (_rmData?['whatsapp_number'] ?? _rmData?['phone'] ?? '').toString().replaceAll('+', '').replaceAll(' ', '');
                                final text = Uri.encodeComponent('Hello, I am contacting from ${_tenantData?['legal_name'] ?? "our property"} regarding our software license renewal.');
                                launchUrl(Uri.parse('https://wa.me/$wa?text=$text'), mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                              label: const Text('WhatsApp', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                      if (_rmData?['email'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(_rmData!['email'].toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
                      SizedBox(width: 8),
                      Text('No dedicated RM assigned yet. Contact support desk for assistance.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Support Agent Section
              if (_supportAgent != null) ...[
                const Text('Assigned Technical Support Engineer', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        child: const Icon(Icons.support_agent_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_supportAgent?['full_name'] ?? 'Support Specialist', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                            Text(_supportAgent?['email'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                          ],
                        ),
                      ),
                      if (_supportAgent?['phone'] != null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () => launchUrl(Uri.parse('tel:${_supportAgent!['phone']}')),
                          icon: const Icon(Icons.call, size: 14),
                          label: const Text('Call Support', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    final isExpired = _warningLevel == 'EXPIRED' || _daysLeft <= 0;
    final isCritical = _warningLevel == 'CRITICAL_RED' || _daysLeft <= 3;
    final showPaymentBanner = _isPendingPayment || _paymentStatus == 'PENDING';

    // If neither warning zone nor pending payment, hide banner
    if (!_warningZone && !showPaymentBanner) {
      return const SizedBox.shrink();
    }

    Color bgColor = const Color(0xFFD97706); // Amber
    String bannerTitle = '';

    if (isExpired) {
      bgColor = const Color(0xFF7F1D1D);
      bannerTitle = 'SOFTWARE LICENSE EXPIRED: System operating in restricted recovery mode. Renew immediately.';
    } else if (isCritical) {
      bgColor = const Color(0xFFDC2626);
      bannerTitle = 'CRITICAL LICENSE WARNING: Only $_daysLeft days left until lockdown! (Valid till ${_formatDate(_validTill)})';
    } else if (showPaymentBanner) {
      bgColor = const Color(0xFFD97706);
      bannerTitle = 'Subscription Renewal Due: ₹$_totalPaymentAmount payable on ${_formatDate(_nextPaymentDate)}. Tax invoice generated.';
    } else {
      bgColor = const Color(0xFFD97706);
      bannerTitle = 'License Notice: Your subscription expires in $_daysLeft days (${_formatDate(_validTill)}). Contact your RM.';
    }

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              (isCritical || isExpired) ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bannerTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: bgColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                if (widget.onContactRm != null) {
                  widget.onContactRm!();
                } else {
                  _showProfileModal(context);
                }
              },
              icon: const Icon(Icons.account_box_rounded, size: 16),
              label: const Text(
                'View Profile & Pay',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
