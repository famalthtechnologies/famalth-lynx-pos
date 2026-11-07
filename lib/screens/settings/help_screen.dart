import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_brand.dart';
import '../../widgets/support_helpdesk_dialog.dart';

/// Comprehensive Document Reader & Knowledge Center
/// Formatted with clean document sheet layout, outline navigation, and live Assigned Relationship Manager
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _docScrollController = ScrollController();

  late final List<_DocChapter> _chapters;
  late _DocTopic _activeTopic;

  bool _isOutlineVisible = true;
  String _searchQuery = '';
  double _fontScale = 1.0;

  // Real Assigned RM data
  bool _isLoadingRm = true;
  Map<String, dynamic>? _rmData;

  @override
  void initState() {
    super.initState();
    _chapters = _buildDocumentationChapters();
    _activeTopic = _chapters.first.topics.first;

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _fetchAssignedRmDetails();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _docScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchAssignedRmDetails() async {
    try {
      final res = await ApiClient.get('/api/v1/control-plane/license-and-rm-status');
      if (res != null && res['success'] == true && mounted) {
        final rm = res['data']?['relationshipManager'] as Map<String, dynamic>?;
        setState(() {
          _rmData = rm;
          _isLoadingRm = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingRm = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRm = false);
    }
  }

  void _selectTopic(_DocTopic topic) {
    setState(() {
      _activeTopic = topic;
    });
    // Smooth scroll to top of document sheet
    if (_docScrollController.hasClients) {
      _docScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _navigateRelative(int offset) {
    final allTopics = _chapters.expand((c) => c.topics).toList();
    final currentIndex = allTopics.indexWhere((t) => t.id == _activeTopic.id);
    if (currentIndex != -1) {
      final newIndex = currentIndex + offset;
      if (newIndex >= 0 && newIndex < allTopics.length) {
        _selectTopic(allTopics[newIndex]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 880;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F9),
      appBar: _buildTopBar(context, isDesktop),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar: Document Outline
          if (isDesktop && _isOutlineVisible)
            Container(
              width: 320,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                ),
              ),
              child: _buildOutlineSidebar(),
            ),

          // Main Center Workspace: Document Sheet Canvas
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView(
                  controller: _docScrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : 12,
                    vertical: 20,
                  ),
                  children: [
                    _buildDocumentSheet(context, isDesktop),
                    const SizedBox(height: 24),
                    _buildAssignedRmCard(context),
                    const SizedBox(height: 16),
                    _buildDocumentFooter(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: !isDesktop ? Drawer(child: SafeArea(child: _buildOutlineSidebar())) : null,
    );
  }

  // ---------------- TOP APP BAR ----------------
  PreferredSizeWidget _buildTopBar(BuildContext context, bool isDesktop) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF0F172A),
      titleSpacing: isDesktop ? 16 : 8,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.article_rounded, color: Color(0xFF0284C7), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'System Documentation & Knowledge Base',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  '${AppBrand.productName} • Official Step-by-Step Operations Manual',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (isDesktop)
          IconButton(
            tooltip: _isOutlineVisible ? 'Hide Outline' : 'Show Outline',
            icon: Icon(_isOutlineVisible ? Icons.menu_open_rounded : Icons.menu_rounded),
            onPressed: () {
              setState(() => _isOutlineVisible = !_isOutlineVisible);
            },
          ),
        IconButton(
          tooltip: 'Zoom Out',
          icon: const Icon(Icons.text_decrease_rounded),
          onPressed: _fontScale > 0.85
              ? () => setState(() => _fontScale = (_fontScale - 0.1).clamp(0.85, 1.3))
              : null,
        ),
        IconButton(
          tooltip: 'Zoom In',
          icon: const Icon(Icons.text_increase_rounded),
          onPressed: _fontScale < 1.3
              ? () => setState(() => _fontScale = (_fontScale + 0.1).clamp(0.85, 1.3))
              : null,
        ),
        IconButton(
          tooltip: 'Keyboard Shortcuts',
          icon: const Icon(Icons.keyboard_rounded),
          onPressed: () => _showShortcutsDialog(context),
        ),
        IconButton(
          tooltip: 'Copy Article Steps',
          icon: const Icon(Icons.copy_rounded),
          onPressed: _copyActiveTopic,
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => SupportHelpdeskDialog.show(context),
          icon: const Icon(Icons.support_agent_rounded, size: 18),
          label: const Text('Live Support'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 12),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
      ),
    );
  }

  // ---------------- OUTLINE SIDEBAR ----------------
  Widget _buildOutlineSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Outline Header & Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.format_list_bulleted_rounded, size: 18, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Text(
                    'DOCUMENT OUTLINE',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search topics, features, FAQs...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),

        // Outline Tree
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _chapters.length,
            itemBuilder: (context, chapterIdx) {
              final chapter = _chapters[chapterIdx];

              // Filter topics if search query present
              final matchingTopics = chapter.topics.where((t) {
                if (_searchQuery.isEmpty) return true;
                return t.title.toLowerCase().contains(_searchQuery) ||
                    t.subtitle.toLowerCase().contains(_searchQuery) ||
                    t.tags.any((tag) => tag.toLowerCase().contains(_searchQuery)) ||
                    t.steps.any((s) => s.toLowerCase().contains(_searchQuery));
              }).toList();

              if (matchingTopics.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(
                      children: [
                        Icon(chapter.icon, size: 15, color: const Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            chapter.title.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...matchingTopics.map((topic) {
                    final isSelected = topic.id == _activeTopic.id;
                    return InkWell(
                      onTap: () {
                        _selectTopic(topic);
                        if (Scaffold.of(context).isDrawerOpen) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE0F2FE) : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
                              width: 3.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              topic.icon,
                              size: 16,
                              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                topic.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------- DOCUMENT SHEET ----------------
  Widget _buildDocumentSheet(BuildContext context, bool isDesktop) {
    final allTopics = _chapters.expand((c) => c.topics).toList();
    final currentIndex = allTopics.indexWhere((t) => t.id == _activeTopic.id);
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex != -1 && currentIndex < allTopics.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 20,
        vertical: isDesktop ? 42 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs & Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _activeTopic.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _activeTopic.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _activeTopic.color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Documentation / ${_activeTopic.category}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Copy Steps',
                icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF0284C7)),
                onPressed: _copyActiveTopic,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Title
          Text(
            _activeTopic.title,
            style: TextStyle(
              fontSize: 24 * _fontScale,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
              height: 1.25,
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle / Executive Summary
          Text(
            _activeTopic.subtitle,
            style: TextStyle(
              fontSize: 15 * _fontScale,
              color: const Color(0xFF475569),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 22),

          // Section 1: Standard Operating Procedure (Numbered Steps)
          Row(
            children: [
              const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF0284C7), size: 20),
              const SizedBox(width: 8),
              Text(
                'Operating Procedure & Instructions',
                style: TextStyle(
                  fontSize: 16 * _fontScale,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ...List.generate(_activeTopic.steps.length, (index) {
            final step = _activeTopic.steps[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0284C7)),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      step,
                      style: TextStyle(
                        fontSize: 14.5 * _fontScale,
                        color: const Color(0xFF1E293B),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Section 2: Pro-Tips / Notes Callout Box
          if (_activeTopic.tips.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: Color(0xFFD97706), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Pro-Tips & Operational Best Practices',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._activeTopic.tips.map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                tip,
                                style: TextStyle(
                                  fontSize: 13.5 * _fontScale,
                                  color: const Color(0xFF78350F),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Section 3: Troubleshooting Box
          if (_activeTopic.troubleshooting != null && _activeTopic.troubleshooting!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.help_outline_rounded, color: Color(0xFF2563EB), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Troubleshooting & Resolution',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _activeTopic.troubleshooting!,
                    style: TextStyle(
                      fontSize: 13.5 * _fontScale,
                      color: const Color(0xFF1E3A8A),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Section 4: Document Reference Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Repository Source: ${_activeTopic.relatedDoc}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 20),

          // Document Page Pagination (Previous / Next)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (hasPrev)
                OutlinedButton.icon(
                  onPressed: () => _navigateRelative(-1),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Previous Chapter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                )
              else
                const SizedBox.shrink(),
              if (hasNext)
                FilledButton.icon(
                  onPressed: () => _navigateRelative(1),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Next Chapter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- ASSIGNED RM CARD (REAL DATA) ----------------
  Widget _buildAssignedRmCard(BuildContext context) {
    if (_isLoadingRm) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Connecting to account support desk...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    final rawName = (_rmData?['fullName'] ?? _rmData?['full_name'] ?? '').toString().trim();
    final name = rawName.isNotEmpty ? rawName : 'Dedicated Relationship Manager';
    final designation = (_rmData?['designation'] ?? 'Senior Account Specialist 1').toString().trim();
    final phone = (_rmData?['phone'] ?? '').toString().trim();
    final rawWa = (_rmData?['whatsappNumber'] ?? _rmData?['whatsapp_number'] ?? phone).toString().trim();
    final wa = rawWa.replaceAll('+', '').replaceAll(' ', '');
    final email = (_rmData?['email'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
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
                  radius: 22,
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.person, color: Color(0xFF0284C7), size: 26),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(5),
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
                    const SizedBox(height: 2),
                    Text(
                      designation,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => SupportHelpdeskDialog.show(context),
                icon: const Icon(Icons.support_agent_rounded, size: 16),
                label: const Text('Open Helpdesk'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (phone.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('tel:$phone');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: Text(phone),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    backgroundColor: const Color(0xFFF0F9FF),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              if (wa.isNotEmpty)
                FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(
                      'https://wa.me/$wa?text=${Uri.encodeComponent("Hello $name, I need assistance with our outlet system")}',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: const Text('Direct WhatsApp'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              if (email.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('mailto:$email?subject=${Uri.encodeComponent("Support Inquiry - ${AppBrand.productName}")}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  icon: const Icon(Icons.email_outlined, size: 16),
                  label: Text(email),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- FOOTER ----------------
  Widget _buildDocumentFooter() {
    return Column(
      children: [
        Text(
          '${AppBrand.companyName} - ${AppBrand.productName}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Enterprise Business OS • Version 2.2.574',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            AppBrand.openSourceNotice,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }

  // ---------------- COPY ACTIVE TOPIC ----------------
  void _copyActiveTopic() {
    final stepsText = _activeTopic.steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
    final tipsText = _activeTopic.tips.isNotEmpty ? '\n\nTips:\n${_activeTopic.tips.map((t) => '• $t').join('\n')}' : '';
    final text = '${_activeTopic.title}\n${_activeTopic.subtitle}\n\nOperating Steps:\n$stepsText$tipsText';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document chapter instructions copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ---------------- KEYBOARD SHORTCUTS MODAL ----------------
  void _showShortcutsDialog(BuildContext context) {
    final shortcuts = [
      {'key': 'F2 / Scan', 'desc': 'Focus Barcode Scanner / Search Box'},
      {'key': 'F4 / Space', 'desc': 'Quick Pay / Open Settlement Modal'},
      {'key': 'Alt + P', 'desc': 'Open Retail POS Billing Desk'},
      {'key': 'Alt + R', 'desc': 'Open Restaurant Running Tables & Floor'},
      {'key': 'Alt + C', 'desc': 'Open Clinic OPD & Doctor Queue'},
      {'key': 'Alt + I', 'desc': 'Open Inventory & Stock Management'},
      {'key': 'Alt + H', 'desc': 'Open Help & Documentation Center'},
      {'key': 'Alt + K', 'desc': 'Park / Hold Current Active Cart'},
      {'key': 'Esc', 'desc': 'Close Modal / Cancel Current Action'},
      {'key': 'Ctrl + P', 'desc': 'Print Receipt / Invoice Voucher'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 10),
            Text('Physical Keyboard Shortcuts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: shortcuts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (_, i) {
                    final item = shortcuts[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              item['key']!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['desc']!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---------------- DOCUMENTATION CHAPTERS REPOSITORY ----------------
  List<_DocChapter> _buildDocumentationChapters() {
    return [
      // CHAPTER 1
      _DocChapter(
        title: '1. Retail POS & Counter Billing',
        icon: Icons.point_of_sale_rounded,
        topics: [
          _DocTopic(
            id: 'pos_fast_checkout',
            category: 'Retail POS',
            title: 'Fast POS Checkout & Barcode Billing',
            subtitle: 'Scan barcodes, adjust item quantities, and execute rapid counter settlement.',
            icon: Icons.qr_code_scanner_rounded,
            color: const Color(0xFF0284C7),
            tags: ['pos', 'checkout', 'barcode', 'cart', 'billing'],
            steps: [
              'Open the POS screen from the main dashboard or press Alt + P.',
              'Scan product barcodes using a USB/wireless scanner to instantly load items into the active cart.',
              'Alternatively, search item name or code in the top search box and tap to add.',
              'Adjust quantities using the + / - buttons or type quantity directly.',
              'Select or search a registered customer to track loyalty points, or leave as Default Cash Customer.',
              'Press Pay / Settle (or Space / F4) to open the settlement modal.',
              'Confirm payment received and print thermal customer receipt.',
            ],
            tips: [
              'Press F2 at any time to return keyboard focus directly to the barcode scan box.',
              'Items with low or zero stock show a warning badge; check with supervisor if negative stock billing is disabled.',
            ],
            troubleshooting: 'If barcode does not scan, confirm scanner cable connection or test scanner typing in Windows Notepad.',
            relatedDoc: 'Docs/User-Guide-POS-Operations-And-Inventory.md',
          ),
          _DocTopic(
            id: 'pos_split_payment',
            category: 'Retail POS',
            title: 'Split Payments (Cash + Card / UPI)',
            subtitle: 'Collect payment across multiple payment channels for a single customer invoice.',
            icon: Icons.call_split_rounded,
            color: const Color(0xFF0284C7),
            tags: ['split', 'partial', 'cash', 'upi', 'card', 'payment'],
            steps: [
              'Scan all items into the customer cart and press Pay / Settle.',
              'In the settlement dialog, select "Split Payment".',
              'Enter the cash amount received from the customer.',
              'The remaining balance is calculated automatically.',
              'Select the second payment mode (e.g. UPI, Card, M-Pesa) for the remaining balance.',
              'Click "Confirm & Print Receipt". The printed bill itemizes both payment channels clearly.',
            ],
            tips: [
              'The system requires the combined split payments to match or exceed the bill total before settling.',
            ],
            relatedDoc: 'Docs/User-Guide-FAQ.md',
          ),
          _DocTopic(
            id: 'pos_park_bill',
            category: 'Retail POS',
            title: 'Hold & Resume Bills (Park Cart)',
            subtitle: 'Temporarily pause a customer transaction to serve the next customer without losing cart items.',
            icon: Icons.pause_circle_outline_rounded,
            color: const Color(0xFF0284C7),
            tags: ['hold', 'park', 'resume', 'cart', 'pause'],
            steps: [
              'If a customer forgot an item or needs time to pay, click "Hold Cart / Park Bill" (or Alt + K).',
              'The active cart is cleared immediately so you can serve the next customer in queue.',
              'When the customer returns, click the "Held Bills" badge at the top of the POS screen.',
              'Select the customer ticket from the list to resume their cart with all scanned items intact.',
              'Complete checkout normally.',
            ],
            tips: [
              'Held bills remain safely in local memory even if the application is restarted.',
            ],
            relatedDoc: 'Docs/User-Guide-FAQ.md',
          ),
          _DocTopic(
            id: 'pos_discounts_coupons',
            category: 'Retail POS',
            title: 'Discounts, Happy Hours & Coupons',
            subtitle: 'Apply flat amount discounts, percentage discounts, or store promotional coupon codes.',
            icon: Icons.discount_rounded,
            color: const Color(0xFF0284C7),
            tags: ['discount', 'coupon', 'happy hour', 'promotion'],
            steps: [
              'With items in the cart, click the "Add Discount / Coupon" button.',
              'Select either Percentage (%) or Flat Amount discount.',
              'If applying a promotional coupon code, enter the coupon code and click Validate.',
              'Happy hour discounts trigger automatically based on store system clock and minimum bill thresholds.',
              'If manager authorization is required, enter the Manager Override PIN when prompted.',
            ],
            tips: [
              'Items marked "Non-discountable" in Item Master are excluded from automatic percentage discounts.',
            ],
            relatedDoc: 'Docs/User-Guide-Promotions-Loyalty-And-LuckyDraw.md',
          ),
          _DocTopic(
            id: 'pos_returns_exchanges',
            category: 'Retail POS',
            title: 'Returns, Exchanges & Credit Notes',
            subtitle: 'Process customer returns against original invoice and issue cash refunds or store credit.',
            icon: Icons.assignment_return_rounded,
            color: const Color(0xFF0284C7),
            tags: ['return', 'refund', 'credit note', 'exchange'],
            steps: [
              'Open Operations > Return Items or click Return on POS.',
              'Enter or scan the original Invoice Number.',
              'Select the specific items and quantities being returned.',
              'Choose the return reason code (Defective, Wrong Item, Customer Mind Change).',
              'Select refund channel: Cash Refund, Store Credit Balance, or Exchange towards new items.',
              'Click "Process Return" to issue credit note and adjust inventory back into stock.',
            ],
            tips: [
              'Returned items are logged in the Daybook under sales returns and tracked in inventory movement reports.',
            ],
            relatedDoc: 'Docs/User-Guide-Operations-Document-Modification-Workflows.md',
          ),
        ],
      ),

      // CHAPTER 2
      _DocChapter(
        title: '2. Restaurant & Dining Operations',
        icon: Icons.restaurant_rounded,
        topics: [
          _DocTopic(
            id: 'dining_tables',
            category: 'Restaurant & Dining',
            title: 'Dining Floor Plan & Table Management',
            subtitle: 'View live table statuses, seat guests, and manage running dining tabs.',
            icon: Icons.table_restaurant_rounded,
            color: const Color(0xFFEA580C),
            tags: ['dining', 'tables', 'floor plan', 'running orders'],
            steps: [
              'Open Restaurant > Floor Plan or Running Orders.',
              'View real-time table status color codes: Green (Vacant), Red (Occupied/Busy), Orange (Billed), Blue (Reserved).',
              'Tap any vacant table to open a new dining session.',
              'Assign table captain or guest count if prompted.',
              'Punch ordered dishes to create or append running KOTs.',
            ],
            tips: [
              'Table floor layouts can be customized by floor or section (e.g. Ground Floor, Rooftop, AC Hall) in Settings.',
            ],
            relatedDoc: 'Docs/User-Guide-Restaurant-And-Hospitality.md',
          ),
          _DocTopic(
            id: 'dining_kds_kot',
            category: 'Restaurant & Dining',
            title: 'Kitchen Display System (KDS) & KOT Routing',
            subtitle: 'Send orders to kitchen stations instantly and monitor live preparation countdowns.',
            icon: Icons.soup_kitchen_rounded,
            color: const Color(0xFFEA580C),
            tags: ['kds', 'kot', 'kitchen', 'orders', 'chef'],
            steps: [
              'When an order is confirmed by waiter or cashier, the KOT is auto-sent to designated kitchen printer or KDS.',
              'Open Restaurant > Kitchen Display System (KDS) on kitchen screen.',
              'Incoming tickets show table number, items, and special cooking instructions.',
              'Tickets are color-coded by waiting time: Green (< 10 min), Yellow (10-20 min), Red (Delayed > 20 min).',
              'Kitchen staff taps "Start Cooking" then "Order Ready" to notify service captains.',
            ],
            tips: [
              'Items can be routed to different stations (e.g. Bar station prints to bar printer, Kitchen prints to hot food station).',
            ],
            relatedDoc: 'Docs/Developer-Guide-Captain-Console-Table-Management.md',
          ),
          _DocTopic(
            id: 'dining_transfer_merge',
            category: 'Restaurant & Dining',
            title: 'Table Transfer & Merge Orders',
            subtitle: 'Relocate guests between tables or merge multiple tables for larger dining parties.',
            icon: Icons.swap_horiz_rounded,
            color: const Color(0xFFEA580C),
            tags: ['transfer', 'merge', 'tables', 'restaurant'],
            steps: [
              'In Floor Plan, select the occupied table.',
              'Click "Transfer Table" and select destination empty table to move all active items and KOTs.',
              'To merge tables: click "Merge Tables" and choose adjacent tables.',
              'Both tables will link under a consolidated billing ticket.',
            ],
            tips: [
              'When merging tables, the kitchen KDS updates ticket labels so food runners deliver to the consolidated group.',
            ],
            relatedDoc: 'Docs/User-Guide-FAQ.md',
          ),
        ],
      ),

      // CHAPTER 3
      _DocChapter(
        title: '3. Inventory & Warehouse Logistics',
        icon: Icons.inventory_2_rounded,
        topics: [
          _DocTopic(
            id: 'inv_stock_in',
            category: 'Inventory & Stock',
            title: 'Stock In (Goods Receiving Note / GRN)',
            subtitle: 'Receive stock from vendors, verify purchase invoices, and update on-hand quantities.',
            icon: Icons.move_to_inbox_rounded,
            color: const Color(0xFF16A34A),
            tags: ['grn', 'stock in', 'vendor', 'purchase', 'receiving'],
            steps: [
              'Open Inventory > Stock In (Receiving) or Purchase Order.',
              'Select Supplier / Vendor and enter supplier invoice number.',
              'Scan or select incoming products.',
              'Enter received quantities, batch numbers, expiry dates, and purchase unit prices.',
              'Confirm tax calculations match the vendor challan.',
              'Click "Save & Post GRN". Stock quantities are immediately credited to inventory.',
            ],
            tips: [
              'Always verify physical goods against supplier bill before posting to prevent stock discrepancies.',
            ],
            relatedDoc: 'Docs/Developer-Guide-POS-Inventory-Manufacturing.md',
          ),
          _DocTopic(
            id: 'inv_stock_dispatch',
            category: 'Inventory & Stock',
            title: 'Stock Dispatch & Branch Transfers',
            subtitle: 'Transfer items from central warehouse to store departments or satellite outlets.',
            icon: Icons.outbox_rounded,
            color: const Color(0xFF16A34A),
            tags: ['dispatch', 'transfer', 'branch', 'department'],
            steps: [
              'Open Inventory > Stock Dispatch.',
              'Choose Source Warehouse and Destination Department or Outlet.',
              'Add items and quantities to dispatch.',
              'Generate and print Dispatch Delivery Challan.',
              'The receiving department verifies physical stock and confirms receipt to complete transfer.',
            ],
            tips: [
              'In transit items are logged in the Transfer Register until the receiving branch acknowledges.',
            ],
            relatedDoc: 'Docs/Help-File.md',
          ),
          _DocTopic(
            id: 'inv_stock_taking',
            category: 'Inventory & Stock',
            title: 'Stock Taking & Physical Inventory Audit',
            subtitle: 'Perform barcode-based physical inventory count and reconcile variance surpluses or deficits.',
            icon: Icons.checklist_rounded,
            color: const Color(0xFF16A34A),
            tags: ['audit', 'stock taking', 'variance', 'reconciliation'],
            steps: [
              'Open Inventory > Stock Taking & Audit.',
              'Scan shelf barcodes to record physical counts item by item.',
              'Review live comparison: System Count vs Physical Count vs Variance.',
              'Investigate any major variances (damages, unposted receipts, missing tags).',
              'Click "Reconcile & Update Stock" to align software records with physical shelf counts.',
            ],
            tips: [
              'Run stock taking by category or aisle during off-peak hours to avoid interruptions.',
            ],
            relatedDoc: 'Docs/User-Guide-Stock-Taking-Modifiers-And-GRN-Verification.md',
          ),
          _DocTopic(
            id: 'inv_damage_entry',
            category: 'Inventory & Stock',
            title: 'Damage, Wastage & Expiry Entry',
            subtitle: 'Write off damaged, expired, or spoiled merchandise with loss accounting entries.',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFF16A34A),
            tags: ['damage', 'wastage', 'spoilage', 'expired', 'loss'],
            steps: [
              'Go to Inventory > Damage Entry.',
              'Select damaged item and quantity lost.',
              'Select Reason Code (Broken, Expired, Water Damage, In-transit Spoilage).',
              'Enter supervisor remarks and take photo evidence if required.',
              'Click Save. The system debits Inventory Loss Expense and decreases stock.',
            ],
            tips: [
              'Regularly review the Damage Summary Report to detect recurring product packaging issues.',
            ],
            relatedDoc: 'Docs/Help-File.md',
          ),
        ],
      ),

      // CHAPTER 4
      _DocChapter(
        title: '4. Clinic Management & OPD Suite',
        icon: Icons.local_hospital_rounded,
        topics: [
          _DocTopic(
            id: 'clinic_queue',
            category: 'Clinic & OPD',
            title: 'Reception Desk: Patient Registration & OPD Queue',
            subtitle: 'Register walk-in patients, issue daily queue tokens, and assign doctors.',
            icon: Icons.badge_rounded,
            color: const Color(0xFF0D9488),
            tags: ['clinic', 'opd', 'patient', 'queue', 'token', 'appointment'],
            steps: [
              'Open Clinic & Doctor Consultation > Reception Desk.',
              'Click "+ Book Walk-in Appointment".',
              'Enter patient name, phone number, age, and gender.',
              'Select consulting doctor and time slot.',
              'A daily OPD queue token number (e.g. #101) is generated and added to waiting queue.',
              'Collect consultation fee or mark as Pay Later / Credit.',
            ],
            tips: [
              'Repeat patients are detected automatically by phone number, preserving prior medical history.',
            ],
            relatedDoc: 'Docs/User-Guide-Clinic-Management-And-OPD.md',
          ),
          _DocTopic(
            id: 'clinic_consultation',
            category: 'Clinic & OPD',
            title: 'Doctor Consultation Desk & Digital Rx Prescriptions',
            subtitle: 'Record clinical vitals, diagnose symptoms, and prescribe in-stock medicines.',
            icon: Icons.medical_services_rounded,
            color: const Color(0xFF0D9488),
            tags: ['doctor', 'consultation', 'prescription', 'rx', 'vitals', 'opd'],
            steps: [
              'Open Doctor Consultation tab on clinic dashboard.',
              'Select current doctor profile or desk.',
              'Click on patient from waiting queue.',
              'Record patient vitals (Blood Pressure, Pulse, Temperature, SpO2, Weight).',
              'Type clinical diagnosis notes.',
              'Search prescribed medicines from current pharmacy inventory and set dosage instructions.',
              'Click "Save Prescription & Mark Consulted". A printable Rx PDF is generated.',
            ],
            tips: [
              'Doctors can see real-time in-stock pharmacy batches while typing medicine names.',
            ],
            relatedDoc: 'Docs/User-Guide-Clinic-Management-And-OPD.md',
          ),
          _DocTopic(
            id: 'clinic_pharmacy_billing',
            category: 'Clinic & OPD',
            title: 'Pharmacy 1-Tap Prescription Dispensing',
            subtitle: 'Load doctor-approved medicines into POS billing cart in 1 tap for rapid medicine fulfillment.',
            icon: Icons.medication_rounded,
            color: const Color(0xFF0D9488),
            tags: ['pharmacy', 'dispensing', 'medicines', 'cart', 'billing'],
            steps: [
              'Open Clinic Dashboard > Pharmacy & Dispensing tab.',
              'Consulted patients with approved digital prescriptions appear in dispensing queue.',
              'Click "Add to POS Cart" next to the patient.',
              'Prescribed medicines, quantities, and pharmacy batch numbers are loaded directly into POS cart.',
              'Collect payment (Cash / UPI / Card) and hand over medicines with receipt.',
            ],
            tips: [
              'If an item is out of stock, substitute medicines can be selected directly before checkout.',
            ],
            relatedDoc: 'Docs/User-Guide-Clinic-Management-And-OPD.md',
          ),
        ],
      ),

      // CHAPTER 5
      _DocChapter(
        title: '5. HRMS, Attendance & Payroll',
        icon: Icons.people_alt_rounded,
        topics: [
          _DocTopic(
            id: 'hrms_attendance',
            category: 'HRMS & Staff',
            title: 'Staff Biometric & Attendance Punching',
            subtitle: 'Track employee shift logins, punch-in/out timestamps, and overtime.',
            icon: Icons.fingerprint_rounded,
            color: const Color(0xFF8B5CF6),
            tags: ['attendance', 'biometric', 'staff', 'punch', 'shifts'],
            steps: [
              'Go to HRMS > Attendance or use Staff QR Badge scan on main login screen.',
              'Employee scans badge QR or enters their personal 4-digit PIN.',
              'Click "Punch In" upon shift start; click "Punch Out" upon end of shift.',
              'The system records exact timestamps, calculates shift duration, and logs overtime.',
            ],
            tips: [
              'Managers can review daily attendance summaries and approve regularizations in HRMS Master.',
            ],
            relatedDoc: 'Docs/User-Guide-HRMS-And-Payroll.md',
          ),
          _DocTopic(
            id: 'hrms_payroll',
            category: 'HRMS & Staff',
            title: 'Monthly Payroll & Payslip Generation',
            subtitle: 'Calculate salary, bonuses, overtime, statutory deductions, and print payslips.',
            icon: Icons.payments_rounded,
            color: const Color(0xFF8B5CF6),
            tags: ['payroll', 'salary', 'payslip', 'wages', 'hrms'],
            steps: [
              'Open HRMS > Payroll.',
              'Select payroll Month and Year.',
              'Click "Calculate Payroll" to aggregate punch records, approved leaves, and overtime hours.',
              'Review deductions (advances, taxes, late penalties) and net payable amounts.',
              'Click "Process Payroll" and print or email salary payslips to employees.',
            ],
            tips: [
              'Salary payouts auto-link into Accounting Ledgers under Staff Salary Expense.',
            ],
            relatedDoc: 'Docs/User-Guide-HRMS-And-Payroll.md',
          ),
        ],
      ),

      // CHAPTER 6
      _DocChapter(
        title: '6. Accounting & Financial Ledgers',
        icon: Icons.account_balance_rounded,
        topics: [
          _DocTopic(
            id: 'acc_cash_ledger',
            category: 'Accounting & Finance',
            title: 'Universal Cash Ledger & Daybook',
            subtitle: 'Track real-time drawer opening balance, cash sales, expenses, and net cash balance.',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF059669),
            tags: ['cash ledger', 'daybook', 'expenses', 'cash drawer'],
            steps: [
              'Open Accounting > Universal Cash Ledger (or Daybook).',
              'Review Opening Balance entered at start of shift.',
              'All cash receipts from POS, OPD consultations, and customer credit collections reflect in real time.',
              'Petty cash payouts (tea, logistics, store cleaning) are logged under Expense Entries.',
              'Current cash in drawer is calculated continuously: Opening + Inflow - Outflow.',
            ],
            tips: [
              'Never payout cash from drawer without recording a petty cash expense voucher.',
            ],
            relatedDoc: 'Docs/User-Guide-Accounting-And-Financial-Ledger.md',
          ),
          _DocTopic(
            id: 'acc_night_audit',
            category: 'Accounting & Finance',
            title: 'Day-End Closing & Night Audit',
            subtitle: 'Count drawer cash, detect overages/shortages, and lock the daily financial register.',
            icon: Icons.event_repeat_rounded,
            color: const Color(0xFF059669),
            tags: ['night audit', 'day end', 'closing', 'cash handover'],
            steps: [
              'At close of trading, go to Reports > Night Audit / Day End.',
              'Count physical currency and coins in cash drawer.',
              'Enter counted physical amount in Counted Cash field.',
              'The system compares physical cash against expected software balance and reports variance (Overage or Shortage).',
              'Click "Execute Day End Closing" to lock register and generate daily audit summary PDF.',
            ],
            tips: [
              'Night audit prevents tampering with closed date invoices and finalizes daily tax reports.',
            ],
            relatedDoc: 'Docs/User-Guide-FAQ.md',
          ),
        ],
      ),

      // CHAPTER 7
      _DocChapter(
        title: '7. Cloud, Encrypted Backups & Disaster Recovery',
        icon: Icons.cloud_done_rounded,
        topics: [
          _DocTopic(
            id: 'backup_local_enc',
            category: 'Cloud & Backup',
            title: 'Creating Encrypted Local Snapshots (.fambak / .enc)',
            subtitle: 'Create password-protected full backups of your outlet database and media.',
            icon: Icons.shield_rounded,
            color: const Color(0xFF2563EB),
            tags: ['backup', 'snapshot', 'security', 'fambak', 'enc'],
            steps: [
              'Go to Settings > Security & Gateways or main dashboard Data Protection Card.',
              'Click "Create Local Backup / Export Snapshot".',
              'Choose backup format (.enc AES-256 encrypted or .fambak standard compressed archive).',
              'Set a secure backup password when prompted.',
              'Save the backup file to an external USB flash drive or secure backup folder.',
            ],
            tips: [
              'Store offline backup copies offsite or on an external drive to protect against hardware failure.',
            ],
            relatedDoc: 'Docs/Disaster-Recovery-Documentation.md',
          ),
          _DocTopic(
            id: 'backup_cloud_remote',
            category: 'Cloud & Backup',
            title: 'Cloud Drive Automated Remote Backups',
            subtitle: 'Configure automated scheduled backups to cloud storage for disaster recovery.',
            icon: Icons.cloud_upload_rounded,
            color: const Color(0xFF2563EB),
            tags: ['cloud', 'backup', 'automation', 'remote'],
            steps: [
              'Go to Settings > Backup & Storage.',
              'Click "Connect Cloud Storage" and follow the one-time browser permission login.',
              'Enable "Automated Cloud Backups".',
              'Set backup frequency (e.g. Daily at 23:00 or after every Day-End Night Audit).',
              'Verify that the Cloud Drive Status indicator displays "Connected & Healthy".',
            ],
            tips: [
              'Cloud backups are encrypted client-side before uploading, ensuring zero unauthorized access.',
            ],
            relatedDoc: 'Docs/User-Guide-Cloud-Features-And-Server-Config.md',
          ),
          _DocTopic(
            id: 'backup_restore',
            category: 'Cloud & Backup',
            title: 'Disaster Recovery & Point-in-Time Restore',
            subtitle: 'Restore an outlet database from .fambak/.enc with automated schema migration and healing.',
            icon: Icons.restore_rounded,
            color: const Color(0xFF2563EB),
            tags: ['restore', 'disaster recovery', 'schema healing', 'migration'],
            steps: [
              'Open Outlet Setup Screen > Restore Backup / Snapshot.',
              'Select your backup file (.fambak or .enc) using the file picker.',
              'Enter backup decryption password.',
              'The system restores data and automatically executes post-restore schema healing to fix missing columns or tables.',
              'Cloud backup is kept OFF by default upon restore to prevent overwriting cloud records until verified.',
              'Restart application and log in.',
            ],
            tips: [
              'Always verify outlet code and store name after restoring.',
            ],
            relatedDoc: 'Docs/Disaster-Recovery-Documentation.md',
          ),
        ],
      ),

      // CHAPTER 8
      _DocChapter(
        title: '8. Hardware, Scanners & Printers',
        icon: Icons.hardware_rounded,
        topics: [
          _DocTopic(
            id: 'hw_thermal_printer',
            category: 'Hardware & Devices',
            title: 'Thermal Receipt Printer Setup (80mm / 58mm)',
            subtitle: 'Configure roll width, ESC/POS commands, cash drawer kick, and test printing.',
            icon: Icons.print_rounded,
            color: const Color(0xFF475569),
            tags: ['printer', 'thermal', '80mm', '58mm', 'esc/pos', 'receipt'],
            steps: [
              'Open Settings > Billing & Print or Receipt Template Designer.',
              'Select Paper Width: 80mm (Standard 3-inch) or 58mm (Compact 2-inch).',
              'Configure Header details (Store Name, Address, GST/Tax, Phone, Receipt Note).',
              'Toggle "Auto-Cut Paper" and "Cash Drawer Kick on Print" as supported by your printer.',
              'Click "Test Print" to ensure alignment and clean output.',
            ],
            tips: [
              'Thermal paper roll must be inserted with thermal coating facing the printhead, otherwise it prints blank.',
            ],
            troubleshooting: 'If printout is blank, flip the paper roll over. If text is gibberish, check baud rate in device manager.',
            relatedDoc: 'Docs/Developer-Guide-A5-Invoice-And-Template-Designer.md',
          ),
          _DocTopic(
            id: 'hw_barcode_scanner',
            category: 'Hardware & Devices',
            title: 'USB & Wireless Barcode Scanner Setup',
            subtitle: 'Connect and verify 1D/2D handheld barcode scanners for fast billing.',
            icon: Icons.qr_code_scanner_rounded,
            color: const Color(0xFF475569),
            tags: ['scanner', 'barcode', 'usb', 'wireless', 'hardware'],
            steps: [
              'Plug the USB scanner cable or 2.4G wireless receiver dongle into computer.',
              'Windows will automatically recognize device as a standard HID keyboard.',
              'Open Windows Notepad and scan any barcode product sticker.',
              'The barcode numbers should type out immediately followed by an Enter key.',
              'In POS screen, scanner input is captured directly into cart.',
            ],
            tips: [
              'Configure scanner with "Enter / Carriage Return" suffix using the programming barcode in scanner manual.',
            ],
            troubleshooting: 'If scanner emits red beeps without typing, reconnect to a motherboard back USB port.',
            relatedDoc: 'Docs/User-Guide-FAQ.md',
          ),
        ],
      ),

      // CHAPTER 9
      _DocChapter(
        title: '9. Troubleshooting & System FAQs',
        icon: Icons.help_center_rounded,
        topics: [
          _DocTopic(
            id: 'trouble_stock_mismatch',
            category: 'Troubleshooting & FAQs',
            title: 'Why Stock Mismatch Happens & How to Fix',
            subtitle: 'Resolving discrepancies between software system stock and physical shelf count.',
            icon: Icons.sync_problem_rounded,
            color: const Color(0xFFDC2626),
            tags: ['stock mismatch', 'discrepancy', 'troubleshooting', 'inventory'],
            steps: [
              'Step 1: Check pending unapproved Goods Receiving Notes (GRNs) under Inventory.',
              'Step 2: Check if Negative Stock Billing was allowed during fast cashier sales.',
              'Step 3: Review unrecorded damages, breakage, or expired goods in Damage Entry.',
              'Step 4: Check if items were dispatched to another department without posting transfer.',
              'Step 5: Run "Stock Taking & Physical Audit" to reconcile software counts with shelf inventory.',
            ],
            tips: [
              'Conduct periodic weekly cycle counts on high-value products to detect variance early.',
            ],
            relatedDoc: 'Docs/User-Guide-FAQ.md',
          ),
          _DocTopic(
            id: 'trouble_permission_denied',
            category: 'Troubleshooting & FAQs',
            title: 'Permission Denied / Action Restricted',
            subtitle: 'Understanding role-based access restrictions and requesting manager overrides.',
            icon: Icons.lock_person_rounded,
            color: const Color(0xFFDC2626),
            tags: ['permissions', 'access denied', 'roles', 'manager pin'],
            steps: [
              'Certain critical operations (e.g. deleting items, modifying approved invoices, discounts > threshold) are restricted by role.',
              'Ask a Store Manager or Administrator to enter their Manager PIN on the prompt dialog.',
              'To permanently grant permissions, Administrator logs in and opens Masters > User Management.',
              'Edit staff profile and enable necessary role permissions.',
            ],
            tips: [
              'Never share Admin Master passwords; assign tailored roles (Cashier, Waiter, Doctor, Accountant) instead.',
            ],
            relatedDoc: 'Docs/Help-File.md',
          ),
          _DocTopic(
            id: 'trouble_offline_mode',
            category: 'Troubleshooting & FAQs',
            title: 'Offline Mode: Billing During Internet Outage',
            subtitle: 'How the system continues sales and billing uninterrupted when the internet disconnects.',
            icon: Icons.wifi_off_rounded,
            color: const Color(0xFFDC2626),
            tags: ['offline', 'internet down', 'disconnected', 'sync'],
            steps: [
              'When internet connection drops, the app switches automatically to Local Engine mode.',
              'Cashiers can continue scanning items, accepting cash payments, and printing thermal receipts without delay.',
              'All offline transactions are securely buffered in local database.',
              'When internet connectivity is restored, cloud sync and backup tasks resume automatically in background.',
            ],
            tips: [
              'Digital card or UPI payments may require standalone card swipe terminal or mobile QR when internet is down.',
            ],
            relatedDoc: 'Docs/User-Guide-FAQ.md',
          ),
          _DocTopic(
            id: 'trouble_forgot_password',
            category: 'Troubleshooting & FAQs',
            title: 'Forgot Password / Emergency Recovery',
            subtitle: 'Resetting forgotten staff PINs or performing owner emergency password recovery.',
            icon: Icons.password_rounded,
            color: const Color(0xFFDC2626),
            tags: ['password', 'pin', 'recovery', 'reset', 'login'],
            steps: [
              'For Staff / Cashiers: Store Manager or Admin logs in and resets PIN in User Management.',
              'For Admin / Store Owner: Click "Emergency Recovery / Forgot Password" on login screen.',
              'Enter registered Owner Mobile Number or Email.',
              'Enter 6-digit OTP received via SMS/Email.',
              'Set a new secure Master Admin Password and confirm.',
            ],
            tips: [
              'Ensure owner contact phone and email are kept updated in Store Business Profile settings.',
            ],
            relatedDoc: 'Docs/User-Guide-FAQ.md',
          ),
        ],
      ),
    ];
  }
}

// ---------------- DATA STRUCTURES ----------------
class _DocChapter {
  final String title;
  final IconData icon;
  final List<_DocTopic> topics;

  _DocChapter({
    required this.title,
    required this.icon,
    required this.topics,
  });
}

class _DocTopic {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> tags;
  final List<String> steps;
  final List<String> tips;
  final String? troubleshooting;
  final String relatedDoc;

  _DocTopic({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tags,
    required this.steps,
    this.tips = const [],
    this.troubleshooting,
    required this.relatedDoc,
  });
}
