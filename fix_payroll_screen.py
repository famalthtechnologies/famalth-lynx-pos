with open('lib/screens/hrms/payroll_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# 1. State variables
old_vars = """  String _selectedOfficeId = 'all';
  List<Map<String, dynamic>> _offices = [];"""

new_vars = """  String _selectedOfficeId = 'all';
  String _selectedScheduleOfficeId = 'all';
  String _selectedApprovalsOfficeId = 'all';
  List<Map<String, dynamic>> _offices = [];"""

old_vars_lf = old_vars.replace('\r\n', '\n')
old_vars_crlf = old_vars.replace('\r\n', '\n').replace('\n', '\r\n')

if old_vars_crlf in c:
    c = c.replace(old_vars_crlf, new_vars.replace('\r\n', '\n').replace('\n', '\r\n'))
    print("Replaced vars (CRLF)")
elif old_vars_lf in c:
    c = c.replace(old_vars_lf, new_vars.replace('\r\n', '\n'))
    print("Replaced vars (LF)")
else:
    print("old_vars not found")

# 2. Add _buildOfficeScheduleBar in _buildPayScheduleTab
old_sched = """  // ================= TAB 5: PAY SCHEDULE =================
  Widget _buildPayScheduleTab() {
    if (_loadingTab) return const Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _payScheduleCard("""

new_sched = """  // ================= TAB 5: PAY SCHEDULE =================
  Widget _buildOfficeScheduleBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_city_rounded, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Schedule Office Scope:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
              Text('Branch-Wise or Company-Wide Schedule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedScheduleOfficeId,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('🏢 All Offices (Consolidated Default)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  ..._offices.map((o) => DropdownMenuItem(
                    value: o['id'].toString(),
                    child: Text('🏢 ${o['office_code']} - ${o['office_name']}', style: const TextStyle(fontSize: 12)),
                  )),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedScheduleOfficeId = v);
                    _loadTabContent();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayScheduleTab() {
    if (_loadingTab) return const Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOfficeScheduleBar(),
        _payScheduleCard("""

old_sched_lf = old_sched.replace('\r\n', '\n')
old_sched_crlf = old_sched.replace('\r\n', '\n').replace('\n', '\r\n')

if old_sched_crlf in c:
    c = c.replace(old_sched_crlf, new_sched.replace('\r\n', '\n').replace('\n', '\r\n'))
    print("Replaced pay schedule tab (CRLF)")
elif old_sched_lf in c:
    c = c.replace(old_sched_lf, new_sched.replace('\r\n', '\n'))
    print("Replaced pay schedule tab (LF)")
else:
    print("old_sched not found")

# 3. Add _buildApprovalsOfficeFilterBar and filtering in _buildApprovalsTab
old_appr = """  // ================= TAB 6: APPROVALS =================
  Widget _buildApprovalsTab() {
    if (_loadingTab) return const Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D)));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Leave Applications Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A5F))),
        ),"""

new_appr = """  // ================= TAB 6: APPROVALS =================
  Widget _buildApprovalsOfficeFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, color: Color(0xFF6B7280), size: 18),
          const SizedBox(width: 8),
          const Text('Filter Approvals by Office:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedApprovalsOfficeId,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('🏢 All Offices & Branches', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  ..._offices.map((o) => DropdownMenuItem(
                    value: o['id'].toString(),
                    child: Text('🏢 ${o['office_code']} - ${o['office_name']}', style: const TextStyle(fontSize: 12)),
                  )),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedApprovalsOfficeId = v);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalsTab() {
    if (_loadingTab) return const Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D)));

    final filteredLeaves = _leaveApprovals.where((a) {
      if (_selectedApprovalsOfficeId == 'all') return true;
      final emp = a['employee'];
      return emp != null && emp['office_id']?.toString() == _selectedApprovalsOfficeId;
    }).toList();

    final filteredLoans = _loanApprovals.where((a) {
      if (_selectedApprovalsOfficeId == 'all') return true;
      final emp = a['employee'];
      return emp != null && emp['office_id']?.toString() == _selectedApprovalsOfficeId;
    }).toList();

    final filteredRevisions = _revisionApprovals.where((a) {
      if (_selectedApprovalsOfficeId == 'all') return true;
      final emp = a['employee'];
      return emp != null && emp['office_id']?.toString() == _selectedApprovalsOfficeId;
    }).toList();

    final filteredBonuses = _bonusApprovals.where((a) {
      if (_selectedApprovalsOfficeId == 'all') return true;
      final emp = a['employee'];
      return emp != null && emp['office_id']?.toString() == _selectedApprovalsOfficeId;
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _buildApprovalsOfficeFilterBar(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Leave Applications Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A5F))),
        ),"""

old_appr_lf = old_appr.replace('\r\n', '\n')
old_appr_crlf = old_appr.replace('\r\n', '\n').replace('\n', '\r\n')

if old_appr_crlf in c:
    c = c.replace(old_appr_crlf, new_appr.replace('\r\n', '\n').replace('\n', '\r\n'))
    print("Replaced approvals tab (CRLF)")
elif old_appr_lf in c:
    c = c.replace(old_appr_lf, new_appr.replace('\r\n', '\n'))
    print("Replaced approvals tab (LF)")
else:
    print("old_appr not found")

# Replace list references with filtered lists
c = c.replace("rows: _leaveApprovals.map((app) {", "rows: filteredLeaves.map((app) {")
c = c.replace("rows: _loanApprovals.map((loan) {", "rows: filteredLoans.map((loan) {")
c = c.replace("children: _revisionApprovals.map((rev) {", "children: filteredRevisions.map((rev) {")
c = c.replace("children: _bonusApprovals.map((b) {", "children: filteredBonuses.map((b) {")

with open('lib/screens/hrms/payroll_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print("Updated payroll_screen.dart!")
