import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/reports/night_audit_controller.dart';
import '../../controllers/inventory/stock_transfer_controller.dart';
import 'dart:io';
import 'package:retailpos/models/security/app_user_model.dart';
import 'package:retailpos/screens/dashboard/system_update_screen.dart';
import 'package:retailpos/screens/reports/return_report_screen.dart';import 'package:retailpos/screens/reports/supplier_return_report_screen.dart';
import 'package:retailpos/screens/reports/cashier_handover_report_screen.dart';
import 'package:retailpos/screens/settings/settings_screen.dart';
import 'package:retailpos/widgets/brand_logo_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/dashboard/dashboard_controller.dart'
    as UserProfiledata;
import '../../controllers/reports/inventory_dashboard_controller.dart';
import '../../controllers/security/user_controller.dart';
import '../../controllers/settings/notification_services.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../core/currency/currency_service.dart';
import '../../core/config/date_time_service.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/token_storage.dart';
import '../../core/auth/auth_service.dart';
import '../../core/navigation/home_route_helper.dart';
import '../../core/config/app_config.dart';
import '../../core/navigation/ai_navigation_registry.dart';
import '../../controllers/notes/user_notes_controller.dart';
import '../../widgets/sticky_notes_modal.dart';
import '../../core/settings/local_preferences.dart';
import '../../models/auth/permission_service.dart';
import '../../core/permissions/module_capability.dart';
import '../../models/common/property_info_model.dart';
import '../auth/login_screen.dart' show LoginScreen;
import '../auth/user_management_screen.dart';
import '../inventory/damage_item_screen.dart';
import '../inventory/stock_issue_screen.dart';
import '../inventory/item_master_screen.dart';
import '../inventory/b2b_marketplace_screen.dart';
import '../community/community_hub_screen.dart';
import '../../widgets/storage_backup_card.dart';
import '../../controllers/community/community_controller.dart';
import '../../widgets/cloud_feature_gate.dart';
import '../../widgets/license_warning_banner.dart';
import '../../widgets/support_helpdesk_dialog.dart';
import '../settings/master_control_plane_screen.dart';
import '../inventory/purchase_order_screen.dart';
import '../inventory/goods_receiving_screen.dart';
import '../inventory/stock_request_screen.dart';
import '../inventory/salescreen.dart';
import '../inventory/stock_transfer_screen.dart';
import '../inventory/stock_dispatch_screen.dart';
import '../inventory/stock_receive_screen.dart';
import '../reports/transfer_progress_dashboard_screen.dart';
import '../inventory/assembly_screen.dart';
import '../inventory/return_issue_screen.dart';
import '../inventory/stock_taking_screen.dart';
import '../inventory/modifier_master_screen.dart';
import '../inventory/supplier_return_refund_screen.dart';
import '../inventory/supplier_return_screen.dart';
import '../reports/expiry_tracker_screen.dart';
import '../clinic/clinic_dashboard_screen.dart';
import '../clinic/public_appointment_booking_screen.dart';
import '../clinic/clinic_doctor_management_dialog.dart';
import '../hrms/employee_screen.dart';
import '../hrms/attendance_screen.dart';
import '../hrms/payroll_screen.dart';
import '../hrms/hrms_masters_screen.dart';
import '../inventory/supplier_master_screen.dart';
import '../restaurant/captain_dashboard_screen.dart';
import '../restaurant/waiter_app_screen.dart';
import '../restaurant/kots_history_screen.dart';
import '../restaurant/table_qr_designer_screen.dart';
import '../restaurant/table_reservation_screen.dart';
import '../dining/table_dining_screen.dart';
import '../settings/mpesa_config_screen.dart';
import '../settings/payment_gateways_screen.dart';
import '../restaurant/floor_plan_configurator.dart';
import '../restaurant/restaurant_setup_screen.dart';
import '../restaurant/kds_screen.dart';
import '../restaurant/delivery_challan_screen.dart';
import '../restaurant/recurring_expenses_screen.dart';
import '../restaurant/restaurant_analytics_reports_screen.dart';
import '../inventory/approval_center_screen.dart';
import '../inventory/submitted_status_screen.dart';
import '../settings/property_info_screen.dart';
import '../settings/outlet_detail_modification_screen.dart';
import '../settings/outlet_hierarchy_linking_screen.dart';
import '../settings/outlet_setup_checklist_screen.dart';
import 'customer_app_screen.dart';
import 'lynx_feature_testing_screen.dart';
import 'autonomous_agent_screen.dart';
import 'retailer_console_screen.dart';
import 'rider_console_screen.dart';
import '../reports/operations_intelligence_screen.dart';
import '../reports/night_audit_screen.dart';
import '../settings/workflow_automation_screen.dart';
import '../settings/developer_ecosystem_screen.dart';
import '../settings/plugin_marketplace_screen.dart';
import '../settings/plugin_dev_studio_screen.dart';
import '../reports/third_party_orders_report_screen.dart';
import '../modify/purchase_modify.dart';
import '../modify/receiving_modify.dart';
import '../modify/request_modify.dart';
import '../modify/sales_reprint_modify_screen.dart';
import '../modify/stock_out_modify.dart';
import '../recovery/backup_service.dart';
import '../reports/closing_report_screen.dart';
import '../reports/cash_ledger_screen.dart';
import '../accounting/accounting_dashboard_screen.dart';
import '../accounting/bank_accounts_screen.dart';
import '../accounting/accounting_vouchers_screen.dart';
import '../accounting/trial_balance_screen.dart';
import '../accounting/profit_loss_screen.dart';
import '../accounting/balance_sheet_screen.dart';
import '../reports/damage_report_screen.dart';
import '../reports/damage_summary_screen.dart';
import '../reports/purchase_report_screen.dart';
import '../reports/request_report_screen.dart';
import '../reports/scheme_report_screen.dart';
import '../reports/loyalty_report_screen.dart';
import '../reports/subscription_report_screen.dart';
import '../reports/sales_report_screen.dart';
import '../reports/store_analysis_screen.dart';
import '../reports/lucky_draw_campaign_screen.dart';
import '../reports/brand_analysis_screen.dart';
import '../reports/scheme_analysis_screen.dart';
import '../reports/source_analysis_screen.dart';
import '../reports/payment_analysis_screen.dart';
import '../reports/ai_query_analytics_screen.dart';
import '../reports/stock_ledger_report_screen.dart';
import '../reports/commission_report_screen.dart';
import '../reports/supplier_payments_report_screen.dart';
import '../reports/refund_pending_report_screen.dart';
import '../reports/stock_transfer_report_screen.dart';
import '../reports/stock_balance_screen.dart';
import '../reports/stock_in_report_screen.dart';
import '../reports/stock_out_report_screen.dart';
import '../reports/supplier_payment_screen.dart';
import '../settings/help_screen.dart';
import '../settings/document_sequence_screen.dart';
import '../settings/stock_location_screen.dart';
import '../settings/loyalty_master_config_screen.dart';
import '../settings/whatsapp_dashboard_screen.dart';
import '../settings/smtp_settings_screen.dart';
import 'notification_screen.dart';
import '../../widgets/lynx_assist_modal.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with WidgetsBindingObserver {
  // OUTLET HIERARCHY & CONTACT DIRECTORY
  int? _selectedDashboardOutletId;
  Map<String, dynamic>? _dashboardHierarchyData;
  final StockTransferController _dashboardTransferCtrl = StockTransferController();

  // USER SESSION
  final Set<int> _shownNotificationIds = {};
  bool _hasPendingDraw = false;
  String _pendingCampaignName = '';

  DateTime _loginTime = DateTime.now();

  UserProfile? user;
  // 🔥 SUPPLIER FINANCE DATA
  // KPI
  int todayIn = 24;
  int todayOut = 31;
  int lowStock = 12;
  double stockValue = 642300;
  double totalRevenue = 0;
  double totalProfit = 0;
  double totalLoss = 0;
  double cogsTotal = 0;
  double grossMarginPercent = 0;
  double expenseTotal = 0;
  double withdrawalTotal = 0;
  double customerOutstanding = 0;
  double supplierOutstanding = 0;
  double cashInTotal = 0;
  double cashOutTotal = 0;
  double cashNetTotal = 0;
  double netOperatingProfit = 0;
  double netSubscription = 0;
  double netDebit = 0;
  double todaySubscriptionQty = 0;
  double todaySubscriptionAmount = 0;
  double todayDiscount = 0;
  double todayRevenue = 0;
  double todayCollection = 0;
  double todayCogs = 0;
  double todayGrossProfit = 0;
  double todayGrossLoss = 0;
  double todayExpenses = 0;
  double todayNetProfit = 0;
  double todayNetLoss = 0;
  double todayGst = 0;
  double todayTaxableRevenue = 0;
  Timer? _appBarTimer;
  Timer? _dataProtectionTimer;
  DateTime _currentTime = DateTime.now();
  DateTime? _lastUploadDateTime;
  String _lastUploadTime = 'Never';
  final UserController userCtrl = UserController();
  // DATA
  List<String> lowStockItems = [];
  List<_TxnDay> issueReceive7 = [];
  List<_DeptIssue> deptIssue = [];
  List<_DamageDay> damage7 = [];
  List<_CategoryStock> categoryStock = [];
  List<_SupplierPayment> supplierPayments = [];
  List<_UnpaidSupplier> unpaidSuppliers = [];
  List<_HeatmapItem> topHeatmapItems = [];
  List<_TransactionTypeSummary> monthlyTransactionTypes = [];
  Map<String, _GrowthComparison> growthComparisons = {};
  Timer? _notificationTimer;
  Timer? _liveHeartbeatTimer;
  Timer? _maintenanceHourlyTimer;
  Map<String, dynamic>? _maintenanceAdvanceNotice;
  bool _isNoticeDismissedForSession = false;
  bool _isLicenseLockoutOpen = false;
  Timer? _customerOrderPollTimer;
  final Set<String> _seenCustomerOrderIds = {};
  bool _isCustomerOrderAlertOpen = false;

  // CLINIC DASHBOARD STATE
  bool _loadingClinicData = false;
  bool _isClinicClosedToday = false;
  String _clinicClosedReason = '';
  List<dynamic> _clinicAppointments = [];
  List<dynamic> _clinicDoctors = [];
  List<dynamic> _clinicSubscriptions = [];
  Map<String, dynamic> _clinicAnalytics = {};
  int _clinicTodayQueueCount = 0;
  int _clinicConsultedCount = 0;
  int _clinicWaitingCount = 0;
  int _clinicPharmacyBilledCount = 0;
  double _clinicTodayRevenue = 0.0;
  int _clinicActiveTherapyCount = 0;

  // HRMS DASHBOARD STATE
  bool _loadingHrmsData = false;
  List<Map<String, dynamic>> _hrmsEmployees = [];
  List<Map<String, dynamic>> _hrmsAttendanceToday = [];
  List<Map<String, dynamic>> _hrmsLeavesPending = [];
  List<Map<String, dynamic>> _hrmsDesignations = [];
  List<Map<String, dynamic>> _hrmsShifts = [];
  int _hrmsTotalEmployees = 0;
  int _hrmsActiveEmployees = 0;
  int _hrmsPresentToday = 0;
  int _hrmsOnLeaveToday = 0;
  int _hrmsAbsentToday = 0;
  double _hrmsMonthlyPayrollEst = 0.0;
  bool _hasInitializedCustomerOrders = false;
  final Set<String> _seenDiningCallIds = {};
  bool _isDiningAlertOpen = false;
  bool _hasInitializedDiningCalls = false;
  String currentVersion = "";
  final InventoryDashboardController dashboardCtrl =
      InventoryDashboardController();
  final propertyCtrl = PropertyInfoController();
  PropertyInfo? property;
  bool _showNotifications = true;
  bool _isSyncing = false;
  String _userRole = '';
  String _drawerSearchQuery = '';
  Set<String> _favoriteDrawerItems = {};
  final UserNotesController _notesCtrl = UserNotesController();
  bool _isFabExpanded = false;

  String get _billingCountry {
    try {
      final systemSettings = context.read<SystemSettingsController>().settings;
      final country = (systemSettings?.billingCountry ?? '').trim();
      if (country.isNotEmpty) return country;
    } catch (_) {}
    return 'India';
  }

  bool get _isIndiaTax {
    try {
      final systemSettings = context.read<SystemSettingsController>().settings;
      final taxMode = (systemSettings?.billingTaxMode ?? '').trim().toUpperCase();
      if (taxMode == 'CGST_SGST' || taxMode == 'IGST') return true;
      if (taxMode == 'US_SALES_TAX' || taxMode == 'VAT' || taxMode == 'COMPOSITE') return false;
      final country = _billingCountry.toLowerCase();
      return country == 'india' || country.isEmpty;
    } catch (_) {
      return true;
    }
  }

  String get _currencyPrefix {
    try {
      final systemSettings = context.read<SystemSettingsController>().settings;
      if (systemSettings != null && systemSettings.baseCurrencySymbol.trim().isNotEmpty) {
        return systemSettings.baseCurrencySymbol.trim();
      }
    } catch (_) {}
    if (!_isIndiaTax) {
      final c = _billingCountry.toLowerCase();
      if (c == 'usa' || c == 'united states') return '\$';
      if (c == 'kenya') return 'KSh';
      if (c == 'uk' || c == 'united kingdom') return '£';
      if (c == 'uae') return 'AED';
      return CurrencyService.symbol;
    }
    return CurrencyService.symbol;
  }

  IconData get _currencyIcon {
    if (_isIndiaTax) {
      return Icons.currency_rupee;
    }
    final c = _billingCountry.toLowerCase();
    if (c == 'usa' || c == 'united states') return Icons.attach_money;
    if (c == 'uk' || c == 'united kingdom') return Icons.currency_pound;
    if (c == 'europe') return Icons.euro;
    return Icons.payments_outlined;
  }

  String get _taxTerm {
    if (_isIndiaTax) return 'GST';
    final c = _billingCountry.toLowerCase();
    if (c == 'usa' || c == 'united states') return 'Sales Tax';
    if (c == 'kenya' || c == 'uk' || c == 'uae') return 'VAT';
    return 'Tax';
  }

  String _formatMoney(num amount, {int decimals = 0}) {
    return CurrencyService.formatWithSymbol(amount, _currencyPrefix, decimals);
  }

  Future<void> _loadFavorites() async {
    final list = await LocalPreferences.getFavoriteDrawerItems();
    if (mounted) {
      setState(() {
        if (list.isEmpty) {
          _favoriteDrawerItems = {
            'Billing (POS)',
            'Draft & Hold Bills',
            'Captain Console',
            'Floor Designer',
            'Kitchen KDS Queue',
            'Delivery Challans',
          };
        } else {
          _favoriteDrawerItems = list.toSet();
        }
      });
    }
  }

  Future<void> _toggleFavorite(String itemLabel) async {
    setState(() {
      if (_favoriteDrawerItems.contains(itemLabel)) {
        _favoriteDrawerItems.remove(itemLabel);
      } else {
        _favoriteDrawerItems.add(itemLabel);
      }
    });
    await LocalPreferences.setFavoriteDrawerItems(_favoriteDrawerItems.toList());
  }

  void _openManageFavoritesDialog(List<Map<String, dynamic>> allDrawerItems) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.star_rounded, color: Color(0xFFFFB800)),
                  SizedBox(width: 8),
                  Text('Customize Favorite Features', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select features to pin directly to the top of your navigation drawer:',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        children: allDrawerItems.map((item) {
                          final label = item['label'] as String;
                          final category = item['category'] as String;
                          final icon = item['icon'] as IconData;
                          final isFav = _favoriteDrawerItems.contains(label);
                          final perm = item['permission'] as String?;
                          if (perm != null && !PermissionService.can(perm)) return const SizedBox();

                          return CheckboxListTile(
                            dense: true,
                            value: isFav,
                            activeColor: const Color(0xFFFFB800),
                            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(category, style: const TextStyle(fontSize: 11)),
                            secondary: Icon(icon, size: 18, color: theme.colorScheme.primary),
                            onChanged: (val) async {
                              await _toggleFavorite(label);
                              setDialogState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String get _businessType => (user?.outletType ?? '').toUpperCase();
  String get _businessModule {
    final raw = (user?.businessModule ?? '').trim().toUpperCase();
    if (raw.isNotEmpty) return raw;
    if (_isRetailBusiness) return 'RETAIL';
    if (_isWarehouseBusiness) return 'INVENTORY';
    if (const {'RESTAURANT', 'CAFE', 'BAR'}.contains(_businessType)) return 'RESTAURANT';
    if (const {'CLINIC', 'HOSPITAL', 'DOCTOR'}.contains(_businessType)) return 'CLINIC';
    return raw.isNotEmpty ? raw : 'RETAIL';
  }
  bool get _isRetailBusiness =>
      _businessType == 'RETAIL' ||
      _businessType == 'RETAIL STORE' ||
      const {
        'KIRANA',
        'MEDICAL',
        'PARTS',
        'MACHINERY',
        'PETS',
        'CLOTHES',
        'SOFTWARE',
        'SHOES',
        'MART'
      }.contains(_businessType);
  bool get _isWarehouseBusiness => _businessType == 'WAREHOUSE';
  bool get _isHospitalityBusiness =>
      const {'HOTEL', 'RESTAURANT', 'CAFE', 'BAR'}.contains(_businessType);
  bool get _showRetailSalesSection => true;
  bool get _showRetailSalesReportSection => true;
  String get _dashboardTitle {
    final clientName = (property?.propertyName ?? propertyCtrl.data?.propertyName ?? user?.propertyName ?? '').trim();
    if (clientName.isNotEmpty) {
      return '$clientName Dashboard';
    }
    if (_isWarehouseBusiness) return 'Warehouse Dashboard';
    if (_isHospitalityBusiness) return 'Department Dashboard';
    return 'FAMALTH LYNX Dashboard';
  }

  void _onTimeZoneChanged() {
    if (mounted) {
      setState(() {
        _currentTime = DateTimeService.instance.nowInTimeZone;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DateTimeService.instance.addListener(_onTimeZoneChanged);
    _currentTime = DateTimeService.instance.nowInTimeZone;
    _startAppBarTimer();
    _startCustomerOrderPolling();
    _startLiveHeartbeatTimer();
    _startMaintenanceHourlyCheck();

    _loadPropertyInfo();

    _loadDashboardHierarchy();

    _verifyDataProtection();
    _dataProtectionTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _verifyDataProtection();
    });

    _loadNotificationPreference();

    loadUser();

    _loadSessionTime();
    _loadUserRole();
    _loadFavorites();
    _notesCtrl.loadNotes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (ModuleCapability.hasBilling(_businessModule)) {
          context.read<NightAuditController>().fetchStatus();
        }
        context.read<SystemSettingsController>().load();
        _checkActiveAnnouncements();
        if (ModuleCapability.hasHrms(_businessModule)) {
          _loadHrmsDashboardData();
        }
        if (ModuleCapability.hasClinic(_businessModule)) {
          _loadClinicDashboardData();
        }
      }
    });
  }

  
  
  void _startMaintenanceHourlyCheck() {
    _maintenanceHourlyTimer?.cancel();
    _fetchMaintenanceTelemetry();
    // Hourly check (not every minute) to conserve bandwidth and avoid server polling overload
    _maintenanceHourlyTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (mounted) {
        _fetchMaintenanceTelemetry();
      }
    });
  }

  Future<void> _fetchMaintenanceTelemetry() async {
    try {
      dynamic res;
      try {
        res = await ApiClient.get('/api/system/maintenance-status', silent: true);
      } catch (_) {
        res = await ApiClient.get('/api/v1/control-plane/maintenance-status', silent: true);
      }
      if (res != null && res['data'] is Map && mounted) {
        final data = res['data'] as Map<String, dynamic>;
        final isActive = data['isActive'] == true;
        if (isActive) {
          final role = await TokenStorage.getRole();
          final uRole = (role ?? '').toUpperCase();
          if (uRole != 'SUPER_ADMIN' && uRole != 'ENTERPRISE_ADMIN') {
            ApiClient.showMaintenanceLockoutDialog(
              title: data['title']?.toString(),
              message: data['message']?.toString(),
              remainingMinutes: data['remainingMinutes'] is num ? (data['remainingMinutes'] as num).toInt() : 30,
            );
          }
        }

        setState(() {
          _maintenanceAdvanceNotice = data;
        });
      }
    } catch (_) {}
  }

  Widget _buildScheduledMaintenanceNoticeBanner() {
    if (_maintenanceAdvanceNotice == null || _isNoticeDismissedForSession) {
      return const SizedBox.shrink();
    }

    final bool isNoticeActive = _maintenanceAdvanceNotice!['advanceNoticeActive'] == true;
    if (!isNoticeActive) return const SizedBox.shrink();

    final title = _maintenanceAdvanceNotice!['noticeTitle']?.toString() ?? '⚠️ Scheduled System Maintenance Notice';
    final message = _maintenanceAdvanceNotice!['noticeMessage']?.toString() ?? 'Cloud infrastructure optimization is scheduled.';
    final scheduledTime = _maintenanceAdvanceNotice!['scheduledStartTime'];
    final duration = _maintenanceAdvanceNotice!['scheduledDurationMinutes'] ?? 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFD97706),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.engineering_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                    if (scheduledTime != null && scheduledTime.toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE68A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF92400E)),
                            const SizedBox(width: 4),
                            Text(
                              'Window: $scheduledTime (~$duration mins)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78350F),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF92400E)),
            tooltip: 'Dismiss for this session',
            onPressed: () {
              setState(() {
                _isNoticeDismissedForSession = true;
              });
            },
          ),
        ],
      ),
    );
  }

  void _startLiveHeartbeatTimer() {
    _liveHeartbeatTimer?.cancel();
    _maintenanceHourlyTimer?.cancel();
    _sendLiveActivityHeartbeat();
    _liveHeartbeatTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (mounted) {
        _sendLiveActivityHeartbeat();
      }
    });
  }

  Future<void> _sendLiveActivityHeartbeat() async {
    try {
      final outletCode = await TokenStorage.getOutletCode();
      if (outletCode == null || outletCode.isEmpty) return;

      final res = await ApiClient.post('/api/public/outlet/heartbeat', {
        'outlet_code': outletCode,
        'client_version': currentVersion,
      }, silent: true);

      if (res != null && mounted) {
        final status = (res['license_status'] ?? '').toString().toUpperCase();
        if ((status == 'EXPIRED' || status == 'SUSPENDED' || status == 'LOCKED') && !_isLicenseLockoutOpen) {
          _showLicenseLockoutDialog(res['message']?.toString() ?? 'Software subscription has expired. Please renew to continue.');
        }
      }
    } catch (_) {
      // Offline fallback: preserve operational uptime
    }
  }

  void _showLicenseLockoutDialog(String message) {
    if (!mounted || _isLicenseLockoutOpen) return;
    _isLicenseLockoutOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.lock_clock_rounded, color: Color(0xFFDC2626), size: 48),
            title: const Text(
              'Enterprise License Expired',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Color(0xFFDC2626)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your access has been locked by administration. Please contact your administrator or renew your subscription to restore service.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF991B1B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Log Out Immediately', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  _liveHeartbeatTimer?.cancel();
                  await TokenStorage.clear();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _startAppBarTimer() {
    _appBarTimer?.cancel();
    _appBarTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTimeService.instance.nowInTimeZone;
        });
      }
    });
  }

  void _startCustomerOrderPolling() {
    _customerOrderPollTimer?.cancel();
    if (ModuleCapability.hasRetail(_businessModule)) {
      _fetchAndCheckCustomerOrders();
    }
    if (ModuleCapability.hasRestaurant(_businessModule)) {
      _fetchAndCheckDiningAlerts();
    }
    _customerOrderPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        if (ModuleCapability.hasRetail(_businessModule)) {
          _fetchAndCheckCustomerOrders();
        }
        if (ModuleCapability.hasRestaurant(_businessModule)) {
          _fetchAndCheckDiningAlerts();
        }
      }
    });
  }

  Future<void> _fetchAndCheckDiningAlerts() async {
    if (!ModuleCapability.hasRestaurant(_businessModule)) return;
    try {
      final res = await ApiClient.get('/api/restaurant/dining/waiter-calls', silent: true);
      if (res['success'] == true && res['data'] is List) {
        final List<dynamic> calls = res['data'];

        if (!_hasInitializedDiningCalls) {
          for (final c in calls) {
            final id = c['id']?.toString() ?? '';
            if (id.isNotEmpty) _seenDiningCallIds.add(id);
          }
          _hasInitializedDiningCalls = true;
          return;
        }

        final newCalls = calls.where((c) {
          final id = c['id']?.toString() ?? '';
          return id.isNotEmpty && !_seenDiningCallIds.contains(id) && c['resolved'] != true;
        }).toList();

        if (newCalls.isNotEmpty && !_isDiningAlertOpen && !_isCustomerOrderAlertOpen && mounted) {
          for (final c in newCalls) {
            final id = c['id']?.toString() ?? '';
            if (id.isNotEmpty) _seenDiningCallIds.add(id);
          }
          _showDiningAppAlertDialog(newCalls.first, totalNewCount: newCalls.length);
        }
      }
    } catch (_) {}
  }

  void _showDiningAppAlertDialog(dynamic call, {int totalNewCount = 1}) {
    if (_isDiningAlertOpen || !mounted) return;
    _isDiningAlertOpen = true;

    final tableName = call['table_name'] ?? 'Table #${call['table_id'] ?? ''}';
    final customerName = call['customer_name'] ?? 'Guest';
    final requestType = (call['request_type'] ?? 'CALL_WAITER').toString().toUpperCase();

    IconData requestIcon = Icons.notifications_active;
    Color requestColor = const Color(0xFFEA580C);
    String requestTitle = 'Server Called';
    if (requestType == 'WATER') {
      requestIcon = Icons.water_drop;
      requestColor = const Color(0xFF0284C7);
      requestTitle = 'Water Requested';
    } else if (requestType == 'BILL') {
      requestIcon = Icons.receipt_long;
      requestColor = const Color(0xFFD97706);
      requestTitle = 'Bill Requested';
    } else if (requestType == 'ORDER' || requestType == 'KOT') {
      requestIcon = Icons.restaurant_menu;
      requestColor = const Color(0xFF16A34A);
      requestTitle = 'New Dining Table Order';
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: requestColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: requestColor, width: 1.5),
                ),
                child: Icon(requestIcon, color: requestColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Dining App Alert: $requestTitle',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (totalNewCount > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '+$totalNewCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Received from Customer Dining QR App',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tableName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: requestColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: requestColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          requestTitle.toUpperCase(),
                          style: TextStyle(color: requestColor, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Requested by: $customerName',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss', style: TextStyle(color: Color(0xFF64748B))),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.table_restaurant_outlined, size: 18),
              label: const Text(
                'Open Captain Console Direct',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CaptainDashboardScreen()),
                );
              },
            ),
          ],
        );
      },
    ).then((_) {
      _isDiningAlertOpen = false;
    });
  }

  Future<void> _fetchAndCheckCustomerOrders() async {
    if (!ModuleCapability.hasRetail(_businessModule)) return;
    try {
      final res = await ApiClient.get('/api/delivery/retailer/orders?today=true', silent: true);
      if (res['success'] == true && res['data'] is List) {
        final List<dynamic> orders = res['data'];

        // Initial fetch: mark existing orders as known so we don't spam popups on launch
        if (!_hasInitializedCustomerOrders) {
          for (final ord in orders) {
            final id = ord['id']?.toString() ?? '';
            if (id.isNotEmpty) _seenCustomerOrderIds.add(id);
          }
          _hasInitializedCustomerOrders = true;
          return;
        }

        // Find newly placed customer app orders
        final newOrders = orders.where((ord) {
          final id = ord['id']?.toString() ?? '';
          final status = (ord['status'] ?? '').toString().toUpperCase().trim();
          final isPending = status == 'PENDING' || status == 'NEW' || status == 'PLACED' || status == 'WAITING_CONFIRMATION';
          return id.isNotEmpty && !_seenCustomerOrderIds.contains(id) && isPending;
        }).toList();

        if (newOrders.isNotEmpty && !_isCustomerOrderAlertOpen && mounted) {
          for (final ord in newOrders) {
            final id = ord['id']?.toString() ?? '';
            if (id.isNotEmpty) _seenCustomerOrderIds.add(id);
          }
          _showNewCustomerOrderDialog(newOrders.first, totalNewCount: newOrders.length);
        }
      }
    } catch (_) {}
  }

  void _showNewCustomerOrderDialog(dynamic order, {int totalNewCount = 1}) {
    if (_isCustomerOrderAlertOpen || !mounted) return;
    _isCustomerOrderAlertOpen = true;

    final orderNo = order['sale_order_no'] ?? order['order_number'] ?? '#ORD-${order['id']}';
    final customerName = order['customer_name'] ?? order['name'] ?? 'Online Customer';
    final customerPhone = order['customer_phone'] ?? order['phone'] ?? '';
    final totalAmount = double.tryParse((order['total_amount'] ?? order['net_amount'] ?? 0).toString()) ?? 0.0;
    final paymentMode = (order['payment_mode'] ?? order['payment_type'] ?? 'COD').toString().toUpperCase();
    final deliveryAddress = order['delivery_address'] ?? order['address'] ?? '';
    final items = (order['items'] is List) ? (order['items'] as List) : [];
    final itemsCount = items.isNotEmpty ? items.length : (int.tryParse((order['total_items'] ?? 1).toString()) ?? 1);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'New Customer Order!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        if (totalNewCount > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '+$totalNewCount new',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Received from Customer Mobile App',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$orderNo',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Text(
                              'PENDING',
                              style: TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 15, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              customerPhone.isNotEmpty ? '$customerName ($customerPhone)' : customerName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shopping_basket_outlined, size: 15, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                '$itemsCount item${itemsCount > 1 ? "s" : ""}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.payment_outlined, size: 15, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                paymentMode,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                          Text(
                            '$_currencyPrefix ${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                      if (deliveryAddress.toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                deliveryAddress.toString().trim(),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss', style: TextStyle(color: Color(0xFF64748B))),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text(
                'Open Retailer Console Direct',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RetailerConsoleScreen()),
                );
              },
            ),
          ],
        );
      },
    ).then((_) {
      _isCustomerOrderAlertOpen = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _currentTime = DateTimeService.instance.nowInTimeZone;
      _startAppBarTimer();
      _startCustomerOrderPolling();
      _loadNotificationPreference();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _appBarTimer?.cancel();
      _customerOrderPollTimer?.cancel();
      _notificationTimer?.cancel();
      _appBarTimer = null;
      _customerOrderPollTimer = null;
      _notificationTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DateTimeService.instance.removeListener(_onTimeZoneChanged);
    _appBarTimer?.cancel();
    _customerOrderPollTimer?.cancel();
    _dataProtectionTimer?.cancel();
    _notificationTimer?.cancel();
    _liveHeartbeatTimer?.cancel();
    super.dispose();
  }

  Future<bool?> _showConfirmSyncDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Sync'),
        content: const Text('Proceed to replace data from online to local?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSync() async {
    setState(() => _isSyncing = true);

    try {
      final success = await BackupService.syncLatest();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _verifyDataProtection();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sync database. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _performUpload() async {
    setState(() => _isSyncing = true);

    try {
      final success = await BackupService.uploadLatest();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database backup uploaded to cloud successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _verifyDataProtection();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Failed to upload backup to cloud. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _loadUserRole() async {
    final role = await TokenStorage.getRole();

    if (mounted) {
      setState(() {
        _userRole = role!;
      });
    }
  }

  Future<void> _verifyDataProtection() async {
    if (!AppConfig.isLocalServer) return;

    final statusMap = await BackupService.checkDetailedStatus();
    final alertStatus = statusMap['alert'] ?? 'NONE';
    final lastSync = statusMap['lastSyncTime'];

    if (lastSync != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(lastSync as int);
      _lastUploadDateTime = dt;
      _lastUploadTime = DateFormat('dd-MMM-yyyy hh:mm a').format(dt);
    } else {
      _lastUploadDateTime = null;
      _lastUploadTime = 'Never';
    }

    if (!mounted) return;
    setState(() {});

    if (alertStatus == 'ENABLE_PROMPT') {
      _showEnableCloudDialog();
    } else if (alertStatus == 'SYNC_FAILED') {
      _showSyncWarningDialog();
    }
  }

  int get _hoursSinceLastUpload {
    if (_lastUploadDateTime == null) return 999;
    return DateTime.now().difference(_lastUploadDateTime!).inHours;
  }

  Widget _buildBackupStatusBanner() {
    if (!AppConfig.isLocalServer) return const SizedBox.shrink();

    final hours = _hoursSinceLastUpload;
    final isSafe = hours < 12;
    final bgColor = isSafe ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final borderColor =
        isSafe ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    final textColor =
        isSafe ? const Color(0xFF166534) : const Color(0xFF991B1B);
    final iconColor =
        isSafe ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isSafe ? Icons.cloud_done : Icons.cloud_off,
            color: iconColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Enterprise Data Sync Status",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Last Upload: $_lastUploadTime${hours == 999 ? ' (Never synced)' : ' ($hours hours ago)'}",
                  style: TextStyle(
                    color: textColor.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isSafe) ...[
            const SizedBox(width: 12),
            _isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
                    ),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _performUpload,
                    icon: const Icon(Icons.cloud_upload, size: 16),
                    label: const Text(
                      "Upload Data",
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadDashboardHierarchy() async {
    final data = await _dashboardTransferCtrl.fetchHierarchy();
    if (mounted) {
      setState(() {
        _dashboardHierarchyData = data;
        final currentOutletId = data?['current_outlet']?['id'];
        if (_selectedDashboardOutletId == null && currentOutletId != null) {
          _selectedDashboardOutletId = currentOutletId;
          _loadDashboard();
        }
      });
    }
  }

  Widget _buildDashboardOutletScopeSelector() {
    final outlets = (_dashboardHierarchyData?['all_outlets'] as List?) ?? [];
    if (outlets.length <= 1) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.storefront, color: Colors.blue),
            const SizedBox(width: 10),
            const Text('Dashboard View Scope:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: _selectedDashboardOutletId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: -1,
                      child: Text('🌐 All Linked Outlets (Combined Enterprise Metrics)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    ...outlets.map<DropdownMenuItem<int?>>((o) {
                      return DropdownMenuItem<int?>(
                        value: o['id'],
                        child: Text('🏬 ${o['outlet_name']} (${o['outlet_code']})', style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedDashboardOutletId = val;
                    });
                    _loadDashboard();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDirectOutletLogin(Map<String, dynamic> targetOutlet) async {
    final outletName = targetOutlet['outlet_name'] ?? 'Outlet';
    final outletCode = targetOutlet['outlet_code'] ?? '';
    final targetId = targetOutlet['id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.swap_horizontal_circle, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text('Direct Switch to $outletName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          'Login directly to $outletName ($outletCode) without entering user ID and password?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.login_outlined),
            label: const Text('Direct Login'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logging in directly to $outletName ($outletCode)...')),
        );
      }

      await AuthService.switchOutlet(targetId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to $outletName ($outletCode) successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FutureBuilder<Widget>(
            future: HomeRouteHelper.resolve(),
            builder: (context, snapshot) =>
                snapshot.data ??
                const Scaffold(
                    body: Center(child: CircularProgressIndicator())),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to switch outlet: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildLinkedOutletsDirectoryCard() {
    final outlets = (_dashboardHierarchyData?['all_outlets'] as List?) ?? [];
    if (outlets.length <= 1) return const SizedBox.shrink();
    final currentOutlet = _dashboardHierarchyData?['current_outlet'];
    final currentOutletId = currentOutlet?['id'];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_outlined, color: Colors.blue),
                const SizedBox(width: 10),
                const Text(
                  'Linked Outlets Contact & Direct Login',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${outlets.length} Outlets Linked',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: outlets.map<Widget>((o) {
                final isMaster = o['is_master'] == true ||
                    o['is_master'] == 1 ||
                    o['is_master'] == '1' ||
                    (o['outlet_role']?.toString().toUpperCase() == 'MASTER') ||
                    o['parent_outlet_id'] == null;
                final isCurrent = currentOutletId != null && o['id'] == currentOutletId;
                final phone = o['contact_phone'] ?? '';
                final email = o['contact_email'] ?? '';

                return Container(
                  width: 280,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent ? Colors.blue.withOpacity(0.04) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isCurrent ? Colors.blue.withOpacity(0.3) : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isMaster ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                            child: Icon(
                              isMaster ? Icons.star : Icons.store,
                              size: 16,
                              color: isMaster ? Colors.purple : Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              o['outlet_name'] ?? 'Outlet',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isMaster ? Colors.purple.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isMaster ? 'MASTER' : 'BRANCH',
                              style: TextStyle(
                                color: isMaster ? Colors.purple : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Code: ${o['outlet_code']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      if (phone.toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 12, color: Colors.blueGrey),
                            const SizedBox(width: 4),
                            Text('$phone', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                      if (email.toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.email, size: 12, color: Colors.blueGrey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '$email',
                                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (isCurrent)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 14, color: Colors.green),
                              SizedBox(width: 6),
                              Text('Active Session', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              foregroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => _handleDirectOutletLogin(o),
                            icon: const Icon(Icons.login_outlined, size: 14),
                            label: const Text('⚡ Direct Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNightAuditPendingBanner(NightAuditController nightAuditCtrl) {
    if (!ModuleCapability.hasBilling(_businessModule)) return const SizedBox.shrink();
    final validation = nightAuditCtrl.validationData;
    final bool isOverdue = validation?['isOverdue'] == true;
    final String businessDate = nightAuditCtrl.currentBusinessDay?['business_date'] ?? '';

    if (!isOverdue) return const SizedBox.shrink();

    final bool isClinic = ModuleCapability.hasClinic(_businessModule) && !ModuleCapability.hasRetail(_businessModule);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isClinic ? Icons.payments_rounded : Icons.nightlight_round,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isClinic
                      ? '⚠️ Reception & Pharmacy Cash Handover Overdue (Business Date: $businessDate)'
                      : '⚠️ Night Audit Overdue (Business Date: $businessDate)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isClinic
                      ? 'Day-end cash collection & handover from reception desk & pharmacy counter is pending. Please complete Cash Handover & Day Closing now to open today.'
                      : 'End of Day audit for yesterday was not executed. Please run Night Audit now to close the date & open today.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78350F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A1A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NightAuditScreen()),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(
              isClinic ? 'Handover Cash' : 'Run Now',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

// =====================================================================
  // CLOUD OPT-IN
  // =====================================================================
  void _showEnableCloudDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents accidental dismissal
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero, // We use custom padding inside
        content: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: 400), // Keeps it looking good on Desktop/Web
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Header Section ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_done_outlined,
                        size: 56, color: Colors.blue.shade700),
                    const SizedBox(height: 16),
                    Text(
                      'Secure Your Data',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // --- Body Section ---
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  'Your inventory data is currently stored only on this device. '
                  'Enable automatic Google Drive backups to ensure your business data is protected against hardware failure or loss.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, height: 1.5, color: Colors.black87),
                ),
              ),
              // --- Action Buttons ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Remind Me Later',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            final success = await BackupService.toggleCloudSync(true);
                            if (mounted) {
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cloud backup enabled and synchronized successfully!'),
                                    backgroundColor: Color(0xFF059669),
                                  ),
                                );
                                _verifyDataProtection();
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.security, size: 18),
                        label: const Text('Enable Backup'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  //  SYNC WARNING
  // =====================================================================
  void _showSyncWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Header Section ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 56, color: Colors.orange.shade700),
                    const SizedBox(height: 16),
                    Text(
                      'Action Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // --- Body Section ---
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  'Your data has not successfully synced to the cloud in over 24 hours. '
                  'Please check your internet connection to ensure your store data remains safely backed up.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, height: 1.5, color: Colors.black87),
                ),
              ),
              // --- Action Buttons ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.orange.shade700,
                    ),
                    child: const Text('I Understand'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadNotificationPreference() async {
    final value = await LocalPreferences.getShowNotifications();
    if (!mounted) return;
    setState(() => _showNotifications = value);
  }

  Future<void> _loadPropertyInfo() async {
    await propertyCtrl.load();
    property = propertyCtrl.data;
    if (mounted) setState(() {});
  }

  Future<void> loadUser() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version;
    final u = await UserProfiledata.load();
    final perms = await TokenStorage.getPermissions();
    final role = await TokenStorage.getRole() ?? u?.role ?? '';
    PermissionService.init(role: role, permissions: perms);
    try {
      setState(() {
        user = u;
      });

      var token = await TokenStorage.read();

      final bool isTokenValid = token != null && !TokenStorage.isExpired(token);

      if (!isTokenValid) {
        return;
      }

      _notificationTimer?.cancel();
      _checkNotifications();
      _notificationTimer =
          Timer.periodic(const Duration(minutes: 1), (timer) async {
        await _checkNotifications();
      });
    } catch (e) {
      _notificationTimer?.cancel();
    }
  }

  Future<void> _checkNotifications() async {
    final allowNotifications = await LocalPreferences.getShowNotifications();
    if (!allowNotifications) return;
    try {
      final token = await TokenStorage.read();
      if (token == null || TokenStorage.isExpired(token)) return;

      final res = await ApiClient.get('/api/notifications', silent: true);
      if (res != null && res['data'] is List) {
        final allowExpiryAlerts = await LocalPreferences.getShowExpiryAlerts();
        final lastExpiryAlertTimestamp = await LocalPreferences.getLastExpiryAlertTimestamp();
        final now = DateTime.now().millisecondsSinceEpoch;
        const sixHoursMs = 6 * 60 * 60 * 1000;
        bool expiryAlertShownThisCycle = false;

        for (final n in res['data']) {
          final id = n['id'] as int? ?? 0;
          if (id > 0 && n['is_read'] == false) {
            final key = 'sys_notif_$id';
            final title = n['title']?.toString() ?? 'Notification';
            final message = n['message']?.toString() ?? '';
            final isExpiry = title.toLowerCase().contains('expiry') || n['module']?.toString() == 'EXPIRY_ALERT';

            if (!_shownNotificationIds.contains(id)) {
              _shownNotificationIds.add(id);

              if (isExpiry) {
                if (!allowExpiryAlerts) {
                  // User turned off expiry alerts
                  continue;
                }
                if (expiryAlertShownThisCycle || (now - lastExpiryAlertTimestamp < sixHoursMs)) {
                  // 6-hour interval hasn't elapsed or already triggered in this loop
                  continue;
                }
              }

              await NotificationService.show(
                id,
                title,
                message,
                uniqueKey: key,
              );

              if (mounted && (title.contains('Appointment') ||
                  title.contains('Reservation') ||
                  isExpiry)) {

                if (isExpiry) {
                  expiryAlertShownThisCycle = true;
                  await LocalPreferences.setLastExpiryAlertTimestamp(now);
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Every 6 hrs',
                                  style: TextStyle(fontSize: 10, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  await LocalPreferences.setShowExpiryAlerts(false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Expiry alerts disabled. You can re-enable anytime in Settings.'),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                },
                                child: const Text(
                                  'Disable Alerts',
                                  style: TextStyle(color: Colors.white70, fontSize: 11, decoration: TextDecoration.underline),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.deepOrange.shade800,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ExpiryTrackerScreen()),
                                  );
                                },
                                child: const Text('View Batches', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      backgroundColor: Colors.deepOrange.shade800,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 10),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('$title: $message',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.teal.shade700,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    try {
      _checkNotifications();
      Future.delayed(const Duration(seconds: 1));
      final data = await dashboardCtrl.load(
        outletId: _selectedDashboardOutletId != null ? _selectedDashboardOutletId.toString() : 'ALL',
      );

      int safeInt(dynamic value) {
        if (value is int) return value;
        if (value is num) return value.round();
        return double.tryParse(value?.toString() ?? '')?.round() ?? 0;
      }

      double safeDouble(dynamic value) {
        if (value is double) return value;
        if (value is num) return value.toDouble();
        return double.tryParse(value?.toString() ?? '') ?? 0;
      }

      setState(() {
        // KPI
        todayIn = safeInt(data['kpis']['todayIn']);
        todayOut = safeInt(data['kpis']['todayOut']);
        lowStock = safeInt(data['kpis']['lowStock']);
        stockValue = safeDouble(data['kpis']['stockValue']);
        totalRevenue = safeDouble(data['kpis']['totalRevenue']);
        totalProfit = safeDouble(data['kpis']['grossProfit']);
        totalLoss = safeDouble(data['kpis']['grossLoss']);
        cogsTotal = safeDouble(data['kpis']['cogsTotal']);
        grossMarginPercent = safeDouble(data['kpis']['grossMarginPercent']);
        expenseTotal = safeDouble(data['kpis']['expenseTotal']);
        withdrawalTotal = safeDouble(data['kpis']['withdrawalTotal']);
        customerOutstanding = safeDouble(data['kpis']['customerOutstanding']);
        supplierOutstanding = safeDouble(data['kpis']['supplierOutstanding']);
        cashInTotal = safeDouble(data['kpis']['cashInTotal']);
        cashOutTotal = safeDouble(data['kpis']['cashOutTotal']);
        cashNetTotal = safeDouble(data['kpis']['cashNetTotal']);
        netOperatingProfit = safeDouble(data['kpis']['netOperatingProfit']);
        netSubscription = safeDouble(data['kpis']['netSubscription']);
        netDebit = safeDouble(data['kpis']['netDebit']);
        todaySubscriptionQty = safeDouble(data['kpis']['todaySubscriptionQty']);
        todaySubscriptionAmount =
            safeDouble(data['kpis']['todaySubscriptionAmount']);
        todayDiscount = safeDouble(data['kpis']['todayDiscount']);
        todayRevenue = safeDouble(data['kpis']['todayRevenue']);
        todayCollection = safeDouble(data['kpis']['todayCollection']);
        todayCogs = safeDouble(data['kpis']['todayCogs']);
        todayGrossProfit = safeDouble(data['kpis']['todayGrossProfit']);
        todayGrossLoss = safeDouble(data['kpis']['todayGrossLoss']);
        todayExpenses = safeDouble(data['kpis']['todayExpenses']);
        todayNetProfit = safeDouble(data['kpis']['todayNetProfit']);
        todayNetLoss = safeDouble(data['kpis']['todayNetLoss']);
        todayGst = safeDouble(data['kpis']['todayGst']);
        todayTaxableRevenue = safeDouble(data['kpis']['todayTaxableRevenue']);
        if (todayTaxableRevenue <= 0 && todayRevenue > 0) {
          todayTaxableRevenue = todayRevenue - todayGst;
        }

        // Low stock list
        lowStockItems = List<String>.from(data['lowStockItems']);

        // Issue vs Receive
        issueReceive7 = (data['issueReceive7Days'] as List)
            .map((e) => _TxnDay(
                  e['day'],
                  safeDouble(e['received']),
                  safeDouble(e['issued']),
                ))
            .toList();

        // Department issue
        deptIssue = (data['departmentIssue'] as List)
            .map((e) => _DeptIssue(
                  e['dept'] ?? "HK",
                  safeDouble(e['qty']),
                ))
            .toList();

        // Damage trend
        damage7 = (data['damageTrend7Days'] as List)
            .map((e) => _DamageDay(
                  e['day'],
                  safeDouble(e['qty']),
                ))
            .toList();

        // Category stock
        categoryStock = (data['categoryStock'] as List)
            .map((e) => _CategoryStock(
                  e['category'],
                  safeInt(e['percent']),
                ))
            .toList();

        // Supplier payments
        supplierPayments = (data['supplierPayments'] as List)
            .map((e) => _SupplierPayment(
                  e['supplier'],
                  safeDouble(e['paid']),
                  safeDouble(e['unpaid']),
                ))
            .toList();

        // Unpaid suppliers
        unpaidSuppliers = (data['unpaidSuppliers'] as List)
            .map((e) => _UnpaidSupplier(
                  e['supplier'],
                  safeDouble(e['amount']),
                ))
            .toList();

        topHeatmapItems = (data['heatmapTopItems'] as List? ?? [])
            .map((e) => _HeatmapItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        monthlyTransactionTypes = (data['monthlyTransactionTypes'] as List? ??
                [])
            .map((e) =>
                _TransactionTypeSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        final comparisonData =
            Map<String, dynamic>.from(data['comparisons'] as Map? ?? {});
        growthComparisons = {
          'day': _GrowthComparison.fromJson(
            Map<String, dynamic>.from(
              comparisonData['day_to_yesterday'] as Map? ?? {},
            ),
          ),
          'week': _GrowthComparison.fromJson(
            Map<String, dynamic>.from(
              comparisonData['week_to_previous_week'] as Map? ?? {},
            ),
          ),
          'month': _GrowthComparison.fromJson(
            Map<String, dynamic>.from(
              comparisonData['month_to_previous_month'] as Map? ?? {},
            ),
          ),
          'year': _GrowthComparison.fromJson(
            Map<String, dynamic>.from(
              comparisonData['year_to_previous_year'] as Map? ?? {},
            ),
          ),
        };
      });
      _checkLuckyDrawCampaignStatus();
      if (ModuleCapability.hasHrms(_businessModule)) {
        _loadHrmsDashboardData();
      }
      if (ModuleCapability.hasClinic(_businessModule)) {
        _loadClinicDashboardData();
      }
    } catch (e) {
      if (e
              .toString()
              .toLowerCase()
              .contains("SESSION_EXPIRED".toLowerCase()) ||
          e.toString().toLowerCase().contains("INVALID_TOKEN".toLowerCase())) {
        await TokenStorage.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("SESSION_EXPIRED")),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    }
  }

  Future<void> _checkLuckyDrawCampaignStatus() async {
    try {
      final res = await ApiClient.get('/api/lucky-draw/campaigns/active');
      if (res['success'] == true && res['data'] != null) {
        final status = res['data']['status']?.toString();
        final name = res['data']['name']?.toString() ?? 'Lucky Draw';
        if (status == 'PENDING_RESULT') {
          setState(() {
            _hasPendingDraw = true;
            _pendingCampaignName = name;
          });
          return;
        }
      }
      setState(() {
        _hasPendingDraw = false;
        _pendingCampaignName = '';
      });
    } catch (_) {}
  }

  Widget _buildLuckyDrawPendingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lucky Draw Pending Winner Declaration!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please declare the winner for campaign "$_pendingCampaignName" to reset counters and resume raffle ticket issuance at POS checkout.',
                  style: const TextStyle(
                    color: Color(0xFF7F1D1D),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LuckyDrawCampaignScreen()),
              );
            },
            icon: const Icon(Icons.casino_outlined, size: 18),
            label: const Text(
              'Draw Winner',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSessionTime() async {
    final loginTime = await TokenStorage.getLoginTime();
    if (mounted) {
      setState(() => _loginTime = loginTime);
    }
  }

  String get sessionDuration {
    final d = DateTime.now().difference(_loginTime);
    if (d.inDays > 0) {
      return '${d.inDays}d ${d.inHours % 24}h';
    }
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
  }

  void _handleLynxAction(String actionType, Map<String, dynamic>? payload) {
    if (actionType == 'OPEN_NOTES') {
      StickyNotesModal.show(context, _notesCtrl);
      return;
    }
    AiNavigationRegistry.navigate(context, actionType, payload);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      drawer: _buildInventoryDrawer(),
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _dashboardTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd-MMM-yyyy hh:mm:ss a').format(_currentTime),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF60A5FA)
                    : const Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
        actions: [
          if (_userRole == 'ADMIN' && AppConfig.isLocalServer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _isSyncing
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.cloud_download),
                      tooltip: 'Sync Latest Data',
                      onPressed: () async {
                        final confirm = await _showConfirmSyncDialog();
                        if (confirm == true) {
                          await _performSync();
                        }
                      },
                    ),
            ),
          IconButton(
              tooltip: 'Sticky Notes & Reminders',
              onPressed: () {
                StickyNotesModal.show(context, _notesCtrl);
              },
              icon: const Icon(Icons.sticky_note_2_rounded, color: Color(0xFFD97706))),
          IconButton(
              tooltip: 'LYNX ASSIST (AI Companion)',
              onPressed: () {
                LynxAssistModal.show(context, onActionTriggered: _handleLynxAction);
              },
              icon: const Icon(Icons.smart_toy_rounded, color: Color(0xFFE53935))),
          IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MainDashboardScreen()));
              },
              icon: const Icon(Icons.refresh)),
          IconButton(
              tooltip: _showNotifications ? 'Notifications (Enabled)' : 'Notifications (Disabled)',
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationScreen()));
                _loadNotificationPreference();
              },
              icon: Icon(
                _showNotifications ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                color: _showNotifications ? const Color(0xFF2563EB) : Colors.grey,
              )),
          IconButton(
              tooltip: 'Logout',
              onPressed: () async {
                await TokenStorage.clear();
                _notificationTimer?.cancel();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false);
              },
              icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabExpanded) ...[
            // 1. Live Support
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton.extended(
                heroTag: 'support_helpdesk_fab',
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.support_agent_rounded, size: 20),
                label: const Text('Live Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  setState(() => _isFabExpanded = false);
                  SupportHelpdeskDialog.show(context);
                },
              ),
            ),
            // 2. B2B Community & Supplier Chat
            Consumer<CommunityController>(
              builder: (context, commCtrl, _) {
                if (!commCtrl.isMessagingEnabled) {
                  return const SizedBox.shrink();
                }
                final unread = commCtrl.totalUnreadCount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FloatingActionButton.extended(
                    heroTag: 'community_chat_fab',
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    icon: const Icon(Icons.forum_rounded, size: 20),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('B2B Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        if (unread > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onPressed: () {
                      setState(() => _isFabExpanded = false);
                      CloudFeatureGate.navigate(
                        context,
                        featureName: 'B2B Merchant Community & Chat',
                        featureDescription:
                            'Real-time merchant-to-merchant messaging, wholesale inquiry channels, and direct supplier communication.',
                        featureIcon: Icons.forum_rounded,
                        destination: const CommunityHubScreen(),
                      );
                    },
                  ),
                );
              },
            ),
            // 3. Sticky Notes & Reminders
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton.extended(
                heroTag: 'sticky_notes_fab',
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.sticky_note_2_rounded, size: 20),
                label: AnimatedBuilder(
                  animation: _notesCtrl,
                  builder: (context, _) {
                    final count = _notesCtrl.activeRemindersCount;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Sticky Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                onPressed: () {
                  setState(() => _isFabExpanded = false);
                  StickyNotesModal.show(context, _notesCtrl);
                },
              ),
            ),
            // 4. LYNX ASSIST Floating AI Button
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                heroTag: 'lynx_assist_fab',
                backgroundColor: const Color(0xFFC81E1E),
                foregroundColor: Colors.white,
                elevation: 6,
                icon: const Icon(Icons.smart_toy_rounded, size: 20),
                label: const Text('LYNX ASSIST', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                onPressed: () {
                  setState(() => _isFabExpanded = false);
                  LynxAssistModal.show(context, onActionTriggered: _handleLynxAction);
                },
              ),
            ),
          ],
          // Master Expandable Floating Action Button
          Consumer<CommunityController>(
            builder: (context, commCtrl, _) {
              final unread = commCtrl.isMessagingEnabled ? commCtrl.totalUnreadCount : 0;
              final reminders = _notesCtrl.activeRemindersCount;
              final totalAlerts = unread + reminders;

              return FloatingActionButton(
                heroTag: 'master_expandable_fab',
                backgroundColor: _isFabExpanded ? const Color(0xFF1E293B) : const Color(0xFFC81E1E),
                foregroundColor: Colors.white,
                elevation: 6,
                tooltip: _isFabExpanded ? 'Close Quick Actions' : 'LYNX Quick Actions',
                onPressed: () {
                  setState(() => _isFabExpanded = !_isFabExpanded);
                },
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedRotation(
                      turns: _isFabExpanded ? 0.125 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isFabExpanded ? Icons.close_rounded : Icons.apps_rounded,
                        size: 26,
                      ),
                    ),
                    if (!_isFabExpanded && totalAlerts > 0)
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '$totalAlerts',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildScheduledMaintenanceNoticeBanner(),
                    const LicenseWarningBanner(),
                    if (ModuleCapability.hasBilling(_businessModule))
                      Consumer<NightAuditController>(
                        builder: (context, nightAuditCtrl, _) {
                          return _buildNightAuditPendingBanner(nightAuditCtrl);
                        },
                      ),
                    _buildBackupStatusBanner(),
                    _buildDashboardOutletScopeSelector(),
                    _buildLinkedOutletsDirectoryCard(),
                    if (_hasPendingDraw && ModuleCapability.isLuckyDrawAllowed(_businessModule)) ...[
                      _buildLuckyDrawPendingBanner(),
                      const SizedBox(height: 12),
                    ],
                    if (ModuleCapability.isHrmsOnly(_businessModule)) ...[
                      _buildHrmsDashboard(isWide: isWide),
                    ] else if (ModuleCapability.isClinicOnly(_businessModule)) ...[
                      _buildClinicDashboard(isWide: isWide),
                    ] else ...[
                      if (ModuleCapability.hasInventory(_businessModule)) _kpiRow(),
                      const SizedBox(height: 12),
                      if (ModuleCapability.hasInventory(_businessModule)) _lowStockAlert(),
                      const SizedBox(height: 12),
                      if (ModuleCapability.hasBilling(_businessModule)) _ownerAnalyticsSection(),
                      const SizedBox(height: 12),
                      if (ModuleCapability.hasAccounting(_businessModule) || ModuleCapability.hasBilling(_businessModule)) _financialOverviewSection(),
                      const SizedBox(height: 12),
                      if (ModuleCapability.hasInventory(_businessModule)) SizedBox(
                        height: 760,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _card(_issueReceiveChart()),
                                    const SizedBox(height: 12),
                                    _card(_damageChart()),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: isWide ? 420 : 320,
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _card(_deptIssueChart()),
                                    const SizedBox(height: 12),
                                    _card(_categoryStockChart()),
                                    const SizedBox(height: 12),
                                    _card(_supplierPaidUnpaidChart()),
                                    const SizedBox(height: 12),
                                    _card(_supplierValueChart()),
                                    const SizedBox(height: 12),
                                    _card(_unpaidSupplierList()),
                                  ],
                                ),
                              ),
                            )
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

  Widget _ownerAnalyticsSection() {
    final day = growthComparisons['day'];
    final week = growthComparisons['week'];
    final month = growthComparisons['month'];
    final year = growthComparisons['year'];

    return Column(
      children: [
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisExtent: 68,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          children: [
            _statCard(
              'Today Revenue (No Sub)',
              _formatMoney(todayRevenue - todaySubscriptionAmount),
              Icons.payments_outlined,
              const Color(0xFF2563EB),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SalesReportScreen(),
                  ),
                );
              },
            ),
            _statCard(
              'Today Revenue (With Sub)',
              _formatMoney(todayRevenue),
              Icons.payments_outlined,
              const Color(0xFF0EA5E9),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SalesReportScreen(),
                  ),
                );
              },
            ),
            _statCard(
              'Today COGS',
              _formatMoney(todayCogs),
              Icons.shopping_bag_outlined,
              const Color(0xFFF97316),
              showInfoIcon: true,
              onTap: () => _showProfitFormulaDialog(context),
            ),
            (todayNetProfit >= 0 && todayNetLoss == 0)
                ? _statCard(
                    'Net Profit',
                    _formatMoney(todayNetProfit),
                    Icons.trending_up,
                    const Color(0xFF16A34A),
                    showInfoIcon: true,
                    onTap: () => _showProfitFormulaDialog(context),
                  )
                : _statCard(
                    'Net Loss',
                    _formatMoney(todayNetLoss),
                    Icons.trending_down,
                    const Color(0xFFDC2626),
                    showInfoIcon: true,
                    onTap: () => _showProfitFormulaDialog(context),
                  ),
            _statCard(
              'Month Growth',
              '${month?.growthPercent.toStringAsFixed(1) ?? '0.0'}%',
              Icons.auto_graph,
              const Color(0xFF7C3AED),
            ),
            _statCard(
              'Today Subscription Sale',
              _formatMoney(todaySubscriptionAmount),
              Icons.subscriptions_outlined,
              const Color(0xFF0EA5E9),
            ),
            _statCard(
              'Today Discount',
              _formatMoney(todayDiscount),
              Icons.percent_outlined,
              const Color(0xFFF59E0B),
            ),
            _statCard(
              'Today Collection',
              _formatMoney(todayCollection),
              Icons.savings_outlined,
              const Color(0xFF6366F1),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CashLedgerScreen(),
                  ),
                );
              },
            ),
            _statCard(
              'Today $_taxTerm',
              _formatMoney(todayGst),
              Icons.account_balance_outlined,
              const Color(0xFFE11D48),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            if (width < 700) {
              return Column(
                children: [
                  _comparisonChartCard('Day vs Yesterday', day),
                  const SizedBox(height: 12),
                  _comparisonChartCard('Week vs Previous Week', week),
                  const SizedBox(height: 12),
                  _comparisonChartCard('Month vs Previous Month', month),
                  const SizedBox(height: 12),
                  _comparisonChartCard('Year vs Previous Year', year),
                ],
              );
            } else {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _comparisonChartCard('Day vs Yesterday', day)),
                      const SizedBox(width: 12),
                      Expanded(child: _comparisonChartCard('Week vs Previous Week', week)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _comparisonChartCard('Month vs Previous Month', month)),
                      const SizedBox(width: 12),
                      Expanded(child: _comparisonChartCard('Year vs Previous Year', year)),
                    ],
                  ),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 12),
        _topItemHeatmapCard(),
      ],
    );
  }

  Widget _financialOverviewSection() {
    final financialPoints = [
      _PeriodPoint('Gross Profit', totalProfit),
      _PeriodPoint('COGS', cogsTotal),
      _PeriodPoint('Gross Loss', totalLoss),
      _PeriodPoint('Expenses', expenseTotal),
      _PeriodPoint('Withdrawals', withdrawalTotal),
      _PeriodPoint('Customer Due', customerOutstanding),
      _PeriodPoint('Supplier Due', supplierOutstanding),
      _PeriodPoint('Net Collection', cashInTotal),
      _PeriodPoint('Net Subscription', netSubscription),
      _PeriodPoint('Net Debit', netDebit),
      _PeriodPoint('Net Operating Profit', netOperatingProfit),
    ];

    Color resolveMetricColor(String label) {
      switch (label) {
        case 'Gross Profit':
          return const Color(0xFF16A34A);
        case 'COGS':
          return const Color(0xFFF97316);
        case 'Gross Loss':
          return const Color(0xFFDC2626);
        case 'Expenses':
          return const Color(0xFF8B5CF6);
        case 'Withdrawals':
          return const Color(0xFFEF4444);
        case 'Customer Due':
          return const Color(0xFF0EA5E9);
        case 'Supplier Due':
          return const Color(0xFF64748B);
        case 'Net Collection':
          return const Color(0xFF16A34A);
        case 'Net Subscription':
          return const Color(0xFF0EA5E9);
        case 'Net Debit':
          return const Color(0xFFDC2626);
        case 'Net Operating Profit':
          return netOperatingProfit >= 0
              ? const Color(0xFF16A34A)
              : const Color(0xFFDC2626);
        default:
          return const Color(0xFF2563EB);
      }
    }

    final transactionSeries = [...monthlyTransactionTypes]
      ..sort((a, b) => b.net.abs().compareTo(a.net.abs()));

    return Column(
      children: [
        _chartCard(
          'Financial Overview',
          'Current month business snapshot',
          SfCartesianChart(
            primaryXAxis: const CategoryAxis(),
            legend: const Legend(isVisible: false),
            series: [
              ColumnSeries<_PeriodPoint, String>(
                dataSource: financialPoints,
                xValueMapper: (d, _) => d.label,
                yValueMapper: (d, _) => d.value.abs(),
                pointColorMapper: (d, _) => resolveMetricColor(d.label),
                dataLabelSettings: const DataLabelSettings(isVisible: true),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
          height: 340,
        ),
        // const SizedBox(height: 12),
        // _chartCard(
        //   'Monthly Transaction Types',
        //   'Credited vs debited by ledger type',
        //   SingleChildScrollView(
        //     scrollDirection: Axis.horizontal,
        //     child: SizedBox(
        //       width: transactionSeries.isEmpty ? 700.0 : transactionSeries.length * 140.0,
        //       child: SfCartesianChart(
        //         primaryXAxis: const CategoryAxis(),
        //         legend: const Legend(isVisible: true),
        //         series: [
        //           ColumnSeries<_TransactionTypeSummary, String>(
        //             name: 'Credited',
        //             dataSource: transactionSeries,
        //             xValueMapper: (d, _) => d.transactionLabel,
        //             yValueMapper: (d, _) => d.credited,
        //             color: const Color(0xFF16A34A),
        //             dataLabelSettings: const DataLabelSettings(isVisible: true),
        //           ),
        //           ColumnSeries<_TransactionTypeSummary, String>(
        //             name: 'Debited',
        //             dataSource: transactionSeries,
        //             xValueMapper: (d, _) => d.transactionLabel,
        //             yValueMapper: (d, _) => d.debited,
        //             color: const Color(0xFFDC2626),
        //             dataLabelSettings: const DataLabelSettings(isVisible: true),
        //           ),
        //         ],
        //       ),
        //     ),
        //   ),
        //   height: 420,
        // ),
      ],
    );
  }

  Widget _transactionTypeSummaryCard() {
    final rows = [...monthlyTransactionTypes]
      ..sort((a, b) => b.net.abs().compareTo(a.net.abs()));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Transaction Type Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Which ledger types are higher this month: credited, debited, and net flow.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: const [
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Credited')),
                DataColumn(label: Text('Debited')),
                DataColumn(label: Text('Net')),
                DataColumn(label: Text('Count')),
              ],
              rows: rows
                  .map(
                    (entry) => DataRow(
                      cells: [
                        DataCell(Text(entry.transactionLabel)),
                        DataCell(
                            Text(_formatMoney(entry.credited))),
                        DataCell(
                            Text(_formatMoney(entry.debited))),
                        DataCell(
                          Text(
                            _formatMoney(entry.net),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: entry.net >= 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        DataCell(Text(entry.count.toString())),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfitFormulaDialog(BuildContext context) {
    final double taxableRev = (todayTaxableRevenue > 0) ? todayTaxableRevenue : (todayRevenue - todayGst);
    final double netGrossProfit = (todayGrossProfit > 0 || todayGrossLoss > 0)
        ? (todayGrossProfit - todayGrossLoss)
        : (taxableRev - todayCogs);
    final bool isGrossProfit = netGrossProfit >= 0;
    final double displayGrossAmount = netGrossProfit.abs();

    final double calculatedNetProfit = netGrossProfit - todayExpenses;
    final bool isNetProfit = calculatedNetProfit >= 0;
    final double displayNetAmount = calculatedNetProfit.abs();
    final String taxName = _taxTerm;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isNetProfit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNetProfit ? Icons.trending_up : Icons.trending_down,
                color: isNetProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Profit & Loss Formula',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How Profit & Loss is calculated in Famalth Lynx:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📐 GROSS PROFIT FORMULA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gross Profit = Today Revenue (Excl. $taxName) - Today COGS',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                    const Divider(height: 16),
                    const Text(
                      '🔻 GROSS LOSS FORMULA (When Cost > Revenue)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gross Loss = Today COGS - Today Revenue (Excl. $taxName)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                    const Divider(height: 16),
                    const Text(
                      '📈 NET PROFIT FORMULA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Net Profit = Today Revenue (Excl. $taxName) - Today COGS - Operating Expenses\n(Net Profit = Gross Profit - Operating Expenses)',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 TAX & $taxName HANDLING NOTE:',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Same universal formula applies for Taxable, Non-Taxable, Inclusive, & Exclusive $taxName sales.\n'
                      '• $taxName collected is a government liability, NOT revenue. For Inclusive $taxName, tax is deducted before calculating Gross Profit.\n'
                      '• COGS = Sold Quantity × Item Purchase Cost Rate.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Live Today Component Values:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              if (todayDiscount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('• Gross Sale (Excl. $taxName):', style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                    Text(_formatMoney(taxableRev + todayDiscount, decimals: 2), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('• Less Discount Given:', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                    Text('- ${_formatMoney(todayDiscount, decimals: 2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('• Today Net Revenue (Excl. $taxName):', style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                  Text(_formatMoney(taxableRev, decimals: 2), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('• Today COGS (Cost of Goods):', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                  Text(_formatMoney(todayCogs, decimals: 2), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFC2410C))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('• Less Operating Expenses:', style: TextStyle(fontSize: 12.5, color: Color(0xFF8B5CF6))),
                  Text('- ${_formatMoney(todayExpenses, decimals: 2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isGrossProfit ? '• Calculated Gross Profit:' : '• Calculated Gross Loss:',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatMoney(displayGrossAmount, decimals: 2),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isGrossProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNetProfit ? '• Calculated Net Profit:' : '• Calculated Net Loss:',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatMoney(displayNetAmount, decimals: 2),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isNetProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '📌 Formula Breakdown: Net Profit = Today Net Revenue (${_formatMoney(taxableRev, decimals: 2)}) - Today COGS (${_formatMoney(todayCogs, decimals: 2)}) - Operating Expenses (${_formatMoney(todayExpenses, decimals: 2)})',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      {VoidCallback? onTap, bool showInfoIcon = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (showInfoIcon)
                            Icon(Icons.info_outline, size: 13, color: color.withOpacity(0.8)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _comparisonChartCard(String title, _GrowthComparison? comparison) {
    final current = comparison?.current?.sales ?? 0;
    final previous = comparison?.previous?.sales ?? 0;
    final growth = comparison?.growthPercent ?? 0;
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Growth: ${growth.toStringAsFixed(1)}%',
              style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Expanded(
            child: SfCartesianChart(
              primaryXAxis: const CategoryAxis(),
              legend: const Legend(isVisible: true),
              series: [
                ColumnSeries<_PeriodPoint, String>(
                  name: 'Current',
                  dataSource: [
                    _PeriodPoint('Sales', current),
                  ],
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.value,
                  color: const Color(0xFF2563EB),
                ),
                ColumnSeries<_PeriodPoint, String>(
                  name: 'Previous',
                  dataSource: [
                    _PeriodPoint('Sales', previous),
                  ],
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.value,
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topItemHeatmapCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 Item Sale Heatmap (Today)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Morning, afternoon, evening, and night sales by item for today.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: const [
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Brand')),
                DataColumn(label: Text('Morning')),
                DataColumn(label: Text('Afternoon')),
                DataColumn(label: Text('Evening')),
                DataColumn(label: Text('Night')),
                DataColumn(label: Text('Total')),
              ],
              rows: topHeatmapItems
                  .map(
                    (item) => DataRow(
                      cells: [
                        DataCell(Text(item.itemName)),
                        DataCell(
                            Text(item.brand.isNotEmpty ? item.brand : '—')),
                        DataCell(_heatCell(item.zones['MORNING']?.sales ?? 0)),
                        DataCell(
                            _heatCell(item.zones['AFTERNOON']?.sales ?? 0)),
                        DataCell(_heatCell(item.zones['EVENING']?.sales ?? 0)),
                        DataCell(_heatCell(item.zones['NIGHT']?.sales ?? 0)),
                        DataCell(
                          Text(
                            _formatMoney(item.totalSales),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heatCell(double value) {
    final amount = value.abs();
    final intensity = (amount / 10000).clamp(0.0, 1.0);
    final color = Color.lerp(
            const Color(0xFFE0F2FE), const Color(0xFF0EA5E9), intensity) ??
        const Color(0xFFE0F2FE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _formatMoney(amount),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: intensity > 0.55 ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
    );
  }

  // ================= SUPPLIER CHARTS =================

  Widget _supplierPaidUnpaidChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Vendor Paid vs Unpaid'),
      primaryXAxis: const CategoryAxis(),
      legend: const Legend(isVisible: true),
      series: [
        ColumnSeries<_SupplierPayment, String>(
          name: 'Paid',
          dataSource: supplierPayments,
          xValueMapper: (d, _) => d.supplier,
          yValueMapper: (d, _) => d.paid,
        ),
        ColumnSeries<_SupplierPayment, String>(
          name: 'Unpaid',
          dataSource: supplierPayments,
          xValueMapper: (d, _) => d.supplier,
          yValueMapper: (d, _) => d.unpaid,
        ),
      ],
    );
  }

  Widget _supplierValueChart() {
    return SfCircularChart(
      title: const ChartTitle(text: 'Vendor Value Share'),
      legend: const Legend(isVisible: true),
      series: [
        DoughnutSeries<_SupplierPayment, String>(
          dataSource: supplierPayments,
          xValueMapper: (d, _) => d.supplier,
          yValueMapper: (d, _) => d.paid + d.unpaid,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _unpaidSupplierList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Unpaid Vendors',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...unpaidSuppliers.map(
          (e) => ListTile(
            leading: const Icon(Icons.warning_amber, color: Colors.red),
            title: Text(e.supplier),
            trailing: Text(
              _formatMoney(e.amount),
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _userDetailRow(IconData icon, String label, String value, bool isDark, {bool isGreen = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: isGreen ? const Color(0xFF10B981) : (isDark ? Colors.white60 : const Color(0xFF64748B))),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isGreen ? const Color(0xFF059669) : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- ACTIVE ANNOUNCEMENTS POPUP & OFFER MODAL ---
  Future<void> _checkActiveAnnouncements() async {
    try {
      final res = await ApiClient.get('/api/v1/control-plane/announcements/active', silent: true);
      if (res != null && res['success'] == true && mounted) {
        final list = (res['data'] as List<dynamic>?) ?? [];
        if (list.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          Map<String, dynamic>? targetAnn;
          String? targetKey;

          for (final item in list) {
            final a = item as Map<String, dynamic>;
            final annId = (a['id'] ?? a['title'] ?? '').toString();
            final dismissKey = 'dismissed_announcement_$annId';
            if (prefs.getBool(dismissKey) != true) {
              targetAnn = a;
              targetKey = dismissKey;
              break;
            }
          }

          if (targetAnn == null || !mounted) return;

          final ann = targetAnn;
          final dismissKey = targetKey!;
          final title = ann['title'] ?? 'Notice';
          final message = ann['message'] ?? '';
          final type = ann['type'] ?? 'OFFER';
          final actionUrl = (ann['action_url'] ?? ann['action_link'])?.toString();

          Color badgeColor = const Color(0xFF0284C7);
          if (type == 'OFFER') badgeColor = const Color(0xFF8B5CF6);
          if (type == 'ALERT') badgeColor = const Color(0xFFEF4444);
          if (type == 'MAINTENANCE') badgeColor = const Color(0xFFF59E0B);

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(type == 'OFFER' ? Icons.campaign_rounded : Icons.info_rounded, color: badgeColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4),
                  ),
                  if (actionUrl != null && actionUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, color: Color(0xFF0284C7), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              actionUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF0284C7), fontSize: 12, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await prefs.setBool(dismissKey, true);
                  },
                  child: const Text('Dismiss', style: TextStyle(color: Color(0xFF64748B))),
                ),
                if (actionUrl != null && actionUrl.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: badgeColor, foregroundColor: Colors.white),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await prefs.setBool(dismissKey, true);
                      launchUrl(Uri.parse(actionUrl), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                    label: const Text('Open Offer Link', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          );
        }
      }
    } catch (_) {}
  }

  // --- COMPLETE CLIENT PROFILE & SUBSCRIPTION DIALOG ---
  void _showUserDetailDialog(
    BuildContext context,
    String fullUserName,
    String fullEmail,
    String role,
    String propertyName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final displayId = fullUserName.isNotEmpty ? fullUserName : 'admin';

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.account_box_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Client Profile & Software Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Identity Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'OPERATOR IDENTITY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: displayId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('User ID "$displayId" copied to clipboard!'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.copy_rounded, size: 14, color: theme.colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Copy',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          displayId,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _userDetailRow(Icons.shield_outlined, 'Role', role.isNotEmpty ? role.toUpperCase() : 'ADMIN', isDark),
                            const Spacer(),
                            _userDetailRow(Icons.timer_outlined, 'Uptime', sessionDuration, isDark, isGreen: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Remote Control Plane License & Telemetry
                  FutureBuilder<dynamic>(
                    future: ApiClient.get('/api/v1/control-plane/license-and-rm-status?outlet_code=${user?.outletCode ?? ""}'),
                    builder: (fCtx, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final res = snapshot.data;
                      final data = (res != null && res['success'] == true) ? (res['data'] as Map<String, dynamic>?) : null;
                      if (data == null) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: const Text('License server offline or credentials pending sync.', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                        );
                      }

                      final hasRealLic = data['hasActiveLicense'] == true || (data['validTill'] != null && data['validTill'].toString().isNotEmpty);
                      final isPaid = data['paymentStatus'] == 'PAID';
                      final daysLeft = data['daysLeft'] ?? 0;
                      final validTill = data['validTill']?.toString().split('T').first ?? (hasRealLic ? 'Active' : 'Unassigned');
                      final startDate = data['softwareStartDate']?.toString().split('T').first ?? 'Standard';
                      final nextPayDate = data['nextPaymentDate']?.toString().split('T').first ?? validTill;
                      final subtotal = data['subscriptionAmount'] ?? 0.0;
                      final taxRate = data['taxPercentage'] ?? 0.0;
                      final totalAmount = data['totalPaymentAmount'] ?? 0.0;
                      final graceDays = data['gracePeriodDays'] ?? 0;
                      final rm = data['relationshipManager'] as Map<String, dynamic>?;
                      final supportAgent = data['assignedSupportAgent'] as Map<String, dynamic>?;
                      final tenantId = data['tenantId'] ?? data['tenant']?['id'];
                      final resolvedOutletCode = (data['outletCode'] ?? user?.outletCode ?? '').toString();
                      final legalName = (data['legalName'] ?? propertyName).toString();
                      final contactEmail = (data['contactEmail'] ?? fullEmail).toString();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Outlet & Registered Client Identity
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'REGISTERED CLIENT & OUTLET',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                      ),
                                    ),
                                    if (resolvedOutletCode.isNotEmpty)
                                      InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: resolvedOutletCode));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Outlet Code "$resolvedOutletCode" copied!'),
                                              duration: const Duration(seconds: 2),
                                              backgroundColor: const Color(0xFF10B981),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.copy_rounded, size: 12, color: theme.colorScheme.primary),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Copy Code',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.storefront_rounded, size: 16, color: theme.colorScheme.primary),
                                    const SizedBox(width: 6),
                                    SelectableText(
                                      resolvedOutletCode.isNotEmpty ? resolvedOutletCode : 'OUTLET-ASSIGNED',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (legalName.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text('•', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          legalName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (contactEmail.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.email_outlined, size: 14, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: SelectableText(
                                          contactEmail,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 2. Subscription Terms Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Software Subscription Terms', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                                      ),
                                      child: Text(
                                        isPaid ? 'PAID / ACTIVE' : 'PAYMENT PENDING',
                                        style: TextStyle(
                                          color: isPaid ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('• Software Start: $startDate', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                Text('• License Renewal: $validTill ($daysLeft days remaining)', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                Text('• Next Payment Due: $nextPayDate', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                                if (subtotal > 0 || totalAmount > 0)
                                  Text(
                                    '• Admin Plan Amount: ₹$subtotal + GST ($taxRate%) = ₹$totalAmount',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                  ),
                                Text('• Grace Period: $graceDays Days after expiry', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 3. Download Invoice Button
                          if (tenantId != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                final url = '${ApiClient.baseUrl}/api/v1/control-plane/invoices/download/$tenantId';
                                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(Icons.receipt_long_rounded, size: 16),
                              label: const Text('Download Latest Tax Invoice (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            ),
                          const SizedBox(height: 14),

                          // 4. Assigned Relationship Manager (Only display when real RM is explicitly assigned by software owner)
                          if (rm != null &&
                              (rm['full_name'] != null || rm['fullName'] != null) &&
                              (rm['full_name']?.toString().trim().isNotEmpty == true || rm['fullName']?.toString().trim().isNotEmpty == true) &&
                              !((rm['full_name'] ?? rm['fullName'] ?? '').toString().toLowerCase().contains('amit')) &&
                              rm['rm_code'] != 'RM-101') ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Assigned Relationship Manager', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                if (rm['rmCode'] != null || rm['rm_code'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      (rm['rmCode'] ?? rm['rm_code'] ?? '').toString(),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    child: const Icon(Icons.person, color: Color(0xFF10B981), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text((rm['full_name'] ?? rm['fullName'] ?? 'Account Manager').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                        if (rm['designation'] != null && rm['designation'].toString().isNotEmpty)
                                          Text(
                                            rm['designation'].toString(),
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF059669)),
                                          ),
                                        Text(rm['email'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  if (rm['phone'] != null && rm['phone'].toString().trim().isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.call, color: Color(0xFF10B981), size: 18),
                                      tooltip: 'Call RM',
                                      onPressed: () => launchUrl(Uri.parse('tel:${rm['phone']}')),
                                    ),
                                  if ((rm['whatsappNumber'] != null && rm['whatsappNumber'].toString().trim().isNotEmpty) ||
                                      (rm['whatsapp_number'] != null && rm['whatsapp_number'].toString().trim().isNotEmpty) ||
                                      (rm['phone'] != null && rm['phone'].toString().trim().isNotEmpty))
                                    IconButton(
                                      icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF22C55E), size: 18),
                                      tooltip: 'WhatsApp RM',
                                      onPressed: () {
                                        final wa = (rm['whatsappNumber'] ?? rm['whatsapp_number'] ?? rm['phone'] ?? '').toString().replaceAll('+', '').replaceAll(' ', '').replaceAll('-', '');
                                        launchUrl(Uri.parse('https://wa.me/$wa'), mode: LaunchMode.externalApplication);
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],

                          // Assigned Support Agent
                          if (supportAgent != null) ...[
                            const SizedBox(height: 12),
                            const Text('Assigned Support Agent', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                    child: const Icon(Icons.support_agent_rounded, color: Color(0xFF8B5CF6), size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(supportAgent['full_name'] ?? 'Support Specialist', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                        Text(supportAgent['email'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  if (supportAgent['phone'] != null)
                                    IconButton(
                                      icon: const Icon(Icons.call, color: Color(0xFF8B5CF6), size: 18),
                                      tooltip: 'Call Support',
                                      onPressed: () => launchUrl(Uri.parse('tel:${supportAgent['phone']}')),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ================= DRAWER =================
  IconData _getCategoryIcon(String name) {
    switch (name) {
      case 'Billing':
        return Icons.receipt_long_outlined;
      case 'Operations':
        return Icons.business_center_outlined;
      case 'Modify':
        return Icons.edit_outlined;
      case 'Masters':
      case 'Masters & Departments':
        return Icons.folder_shared_outlined;
      case 'HR & Payroll':
        return Icons.people_outline;
      case 'Restaurant (Beta)':
        return Icons.restaurant_menu;
      case 'Clinic & Health (Beta)':
      case 'Clinic & Health':
        return Icons.medical_services_outlined;
      case 'Finance & Accounting (Beta)':
      case 'Finance & Accounting':
      case 'Finance & Expenses':
      case 'Finance':
        return Icons.account_balance_outlined;
      case 'Stock View':
        return Icons.inventory_2_outlined;
      case 'Reports':
        return Icons.analytics_outlined;
      case 'Developer & Integrations':
        return Icons.integration_instructions_rounded;
      default:
        return Icons.settings_outlined;
    }
  }

  Widget _buildInventoryDrawer() {
    final userName = user?.username ?? "";
    final userRole = user?.role ?? "";
    final userEmail = user?.name ?? "";
    PropertyInfo? propInfo;
    try {
      propInfo = Provider.of<PropertyInfoController>(context).data;
    } catch (_) {
      propInfo = property ?? propertyCtrl.data;
    }
    final propertyDisplayName = (propInfo?.propertyName.trim().isNotEmpty == true)
        ? propInfo!.propertyName.trim()
        : ((property?.propertyName.trim().isNotEmpty == true)
            ? property!.propertyName.trim()
            : ((propertyCtrl.data?.propertyName.trim().isNotEmpty == true)
                ? propertyCtrl.data!.propertyName.trim()
                : (user?.propertyName?.trim().isNotEmpty == true
                    ? user!.propertyName!.trim()
                    : '')));
    final hotelName = propertyDisplayName;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    final List<Map<String, dynamic>> allDrawerItems = [
      // Billing Section (Primary Navigation for Cashiers & Staff)
      {
        'category': 'Billing',
        'icon': Icons.point_of_sale,
        'label': 'Billing (POS)',
        'permission': 'RETAIL_SALES',
        'keywords': ['sale', 'sales', 'retail sale', 'retail sales', 'pos', 'billing', 'bill', 'billing pos', 'counter billing', 'invoice', 'make bill', 'pos sale', 'retail'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleScreen())),
      },
      {
        'category': 'Billing',
        'icon': Icons.drafts_outlined,
        'label': 'Draft & Hold Bills',
        'permission': 'RETAIL_SALES',
        'keywords': ['draft', 'drafts', 'hold bill', 'hold bills', 'unsettled bill', 'draft sale', 'pending bill', 'table bill', 'sale', 'sales'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleScreen(openDraftsOnLaunch: true))),
      },
      {
        'category': 'Billing',
        'icon': Icons.receipt_long_outlined,
        'label': 'Reprint / Modify Bills',
        'permission': 'REPRINT_SALES_BILL',
        'keywords': ['reprint', 'modify bill', 'sales bill', 'reprint bill', 'sale bill', 'sale', 'sales'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReprintModifyScreen())),
      },

      // Operations
      {
        'category': 'Operations',
        'icon': Icons.shopping_bag_outlined,
        'label': 'Customer App (Delivery)',
        'permission': 'CUSTOMER_APP',
        'isBeta': true,
        'onTap': () => CloudFeatureGate.navigate(
          context,
          featureName: 'Customer Ordering App',
          featureDescription:
              'Multi-device consumer mobile ordering with real-time checkout and live GPS delivery tracking.',
          featureIcon: Icons.shopping_bag_outlined,
          destination: const CustomerAppScreen(),
        ),
      },
      {
        'category': 'Operations',
        'icon': Icons.admin_panel_settings_outlined,
        'label': 'Supplier / Retailer Console',
        'permission': 'RETAILER_CONSOLE',
        'isBeta': true,
        'onTap': () => CloudFeatureGate.navigate(
          context,
          featureName: 'Supplier / Retailer Console',
          featureDescription:
              'Merchant operations console for managing omnichannel online delivery orders, live catalog, and dispatch.',
          featureIcon: Icons.admin_panel_settings_outlined,
          destination: const RetailerConsoleScreen(),
        ),
      },
      {
        'category': 'Operations',
        'icon': Icons.delivery_dining_outlined,
        'label': 'Rider Delivery Portal',
        'permission': 'RIDER_PORTAL',
        'isBeta': true,
        'onTap': () => CloudFeatureGate.navigate(
          context,
          featureName: 'Rider Delivery Portal',
          featureDescription:
              'Real-time delivery agent portal with live GPS location broadcasts and order fulfillment status.',
          featureIcon: Icons.delivery_dining_outlined,
          destination: const RiderConsoleScreen(),
        ),
      },
      {
        'category': 'Operations',
        'icon': Icons.storefront_rounded,
        'label': 'B2B Wholesale Marketplace',
        'permission': 'PURCHASE_ORDER',
        'onTap': () => CloudFeatureGate.navigate(
          context,
          featureName: 'B2B Wholesale Marketplace',
          featureDescription:
              'Wholesale merchant marketplace to discover regional verified vendors and place wholesale purchase orders online.',
          featureIcon: Icons.storefront_rounded,
          destination: const B2BMarketplaceScreen(),
        ),
      },
      {
        'category': 'Operations',
        'icon': Icons.forum_rounded,
        'label': 'Merchant Community & Chat',
        'subLabel': 'Regional merchant channels & 1-on-1 private messaging',
        'keywords': ['community', 'chat', 'direct message', 'regional channel', 'merchant chat', 'whatsapp'],
        'onTap': () => CloudFeatureGate.navigate(
          context,
          featureName: 'B2B Merchant Community & Chat',
          featureDescription:
              'Real-time merchant-to-merchant messaging, wholesale inquiry channels, and direct supplier communication.',
          featureIcon: Icons.forum_rounded,
          destination: const CommunityHubScreen(),
        ),
      },
      {
        'category': 'Operations',
        'icon': Icons.shopping_cart_checkout,
        'label': 'Vendor Purchase Order (PO)',
        'permission': 'PURCHASE_ORDER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrderScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.download_rounded,
        'label': 'Vendor Receive Order (GRN)',
        'permission': 'STOCK_IN',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoodsReceivingScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.hourglass_bottom_rounded,
        'label': 'Receiving Expiry & Batch Tracker',
        'subLabel': 'Shelf-life intelligence, batch ledgers & expiry risk across Retail, Restaurant, Store & Clinic',
        'permission': 'INVENTORY_MANAGEMENT',
        'keywords': ['expiry', 'batch', 'shelf life', 'receiving ledger', 'grn expiry', 'restaurant expiry', 'retail expiry', 'store expiry'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpiryTrackerScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.upload,
        'label': 'Stock Dispatch',
        'permission': 'STOCK_OUT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockIssueScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.request_page_outlined,
        'label': 'Material Requisition / Request Item',
        'permission': 'ITEM_REQUEST',
        'keywords': ['material requisition', 'request item', 'stock request', 'department request', 'inventory request'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockRequestScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.swap_horiz,
        'label': 'Stock Transfer',
        'permission': 'STOCK_TRANSFER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockTransferScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.local_shipping,
        'label': 'Inter-Outlet Stock Dispatch',
        'subLabel': 'Dispatch stock from current outlet to a child outlet',
        'permission': 'STOCK_TRANSFER',
        'keywords': ['inter outlet stock dispatch', 'dispatch to child outlet', 'outlet transfer dispatch', 'stock dispatch', 'outlet dispatch'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockDispatchScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.call_received,
        'label': 'Receive Stock at Child Outlet',
        'subLabel': 'Confirm receipt and credit stock at destination outlet',
        'permission': 'STOCK_TRANSFER',
        'keywords': ['receive stock child outlet', 'receive outlet stock', 'credit child outlet stock', 'inbound outlet transfer', 'receive dispatch'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockReceiveScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.build,
        'label': 'Product Assembly',
        'permission': 'PRODUCT_ASSEMBLY',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssemblyScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.undo,
        'label': 'Return Department Items',
        'permission': 'RETURN_ISSUE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnIssueScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.assignment_return,
        'label': 'Return Purchase to Vendor',
        'permission': 'SUPPLIER_RETURN',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierReturnScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.fact_check_outlined,
        'label': 'Stock Taking (Physical Audit)',
        'subLabel': 'Count physical stock, calculate variance, and reconcile inventory',
        'permission': 'STOCK_OUT',
        'keywords': ['stock taking', 'stock take', 'physical count', 'inventory audit', 'stock audit', 'variance', 'stock balance', 'reconcile'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockTakingScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.warning_amber,
        'label': 'Damage Items',
        'permission': 'DAMAGE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DamageItemScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.payment,
        'label': 'Vendor Payment',
        'permission': 'SUPPLIER_PAYMENT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierPaymentScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.account_balance_wallet,
        'label': 'Vendor Return Refund',
        'permission': 'SUPPLIER_RETURN_REFUND',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierReturnRefundScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.assignment_return_outlined,
        'label': 'Pending Refunds',
        'permission': 'PENDING_REFUNDS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RefundPendingReportScreen())),
      },
      if (userRole == 'ADMIN')
        {
          'category': 'Operations',
          'icon': Icons.verified_user_outlined,
          'label': 'Approval Center',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovalCenterScreen())),
        },
      {
        'category': 'Operations',
        'icon': Icons.history_edu,
        'label': 'My Submissions Status',
        'permission': 'SUBMISSIONS_STATUS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmittedStatusScreen())),
      },

      // Modify
      if (PermissionService.can('MODIFY_REQUEST') || PermissionService.can('REPRINT_REQUEST'))
        {
          'category': 'Modify',
          'icon': Icons.edit_note,
          'label': 'Modify Request',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestModifyScreen())),
        },
      if (PermissionService.can('MODIFY_PURCHASE') || PermissionService.can('REPRINT_PURCHASE'))
        {
          'category': 'Modify',
          'icon': Icons.assignment,
          'label': 'Modify Purchase Order',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrderModifyScreen())),
        },
      if (PermissionService.can('MODIFY_RECEIVING') || PermissionService.can('REPRINT_RECEIVING'))
        {
          'category': 'Modify',
          'icon': Icons.inventory_2,
          'label': 'Modify Receiving (GRN)',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModifyReceivingScreen())),
        },
      if (PermissionService.can('RETAIL_SALES') || PermissionService.can('REPRINT_SALES_BILL'))
        {
          'category': 'Modify',
          'icon': Icons.receipt_long,
          'label': 'Reprint / Modify Sales Bill',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReprintModifyScreen())),
        },
      if (PermissionService.can('MODIFY_ISSUE') || PermissionService.can('REPRINT_ISSUE'))
        {
          'category': 'Modify',
          'icon': Icons.outbox,
          'label': 'Modify Stock Dispatch',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IssueModifyScreen())),
        },

      // Masters & Departments
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.inventory_2_outlined,
        'label': 'Item Master',
        'permission': 'ITEM_MASTER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemMasterScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.store,
        'label': 'Vendor Master',
        'permission': 'SUPPLIER_MASTER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierMasterScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.settings_suggest_outlined,
        'label': 'Document Sequence Settings',
        'permission': 'NUMBERING_SETTINGS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentSequenceScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.checklist_rounded,
        'label': 'Store Setup Checklist & Guide',
        'permission': 'PROPERTY_INFORMATION',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OutletSetupChecklistScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.edit_location_alt_outlined,
        'label': 'Outlet Detail Modification',
        'permission': 'PROPERTY_INFORMATION',
        'keywords': ['property info', 'property information', 'store info', 'store details', 'outlet details', 'company details', 'modify outlet details', 'outlet settings', 'store name', 'business address'],
        'onTap': () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const OutletDetailModificationScreen()));
          _loadPropertyInfo();
        },
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.account_tree_rounded,
        'label': 'Master & Child Outlets Setup',
        'permission': 'PROPERTY_INFORMATION',
        'keywords': ['master child outlet', 'link outlet', 'create child outlet', 'make child outlet', 'outlet hierarchy', 'branch setup'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OutletHierarchyLinkingScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.location_on_outlined,
        'label': _isHospitalityBusiness ? 'Department' : 'Location',
        'permission': 'STOCK_LOCATION',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockLocationScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.supervised_user_circle,
        'label': 'User Management',
        'permission': 'USER_MANAGEMENT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.stars_outlined,
        'label': 'Loyalty Program',
        'permission': 'LOYALTY_PROGRAM',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoyaltyMasterConfigScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.chat_bubble_outline,
        'label': 'WhatsApp Integration',
        'permission': 'WHATSAPP_INTEGRATION',
        'isBeta': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WhatsAppDashboardScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.email_outlined,
        'label': 'SMTP Email Setup',
        'permission': 'SMTP_SETTINGS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmtpSettingsScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.phone_android,
        'label': 'Payment & Settlement Management',
        'subLabel': 'Payment Methods, Settlement Mode (Direct / Pre-Bill), UPI, Stripe, Square, PayPal, M-Pesa',
        'permission': 'PAYMENT_MODES',
        'keywords': ['payment gateways', 'upi', 'stripe', 'square', 'razorpay', 'paypal', 'mpesa', 'daraja', 'settlement', 'digital wallet', 'india', 'usa', 'europe', 'germany', 'kenya'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentGatewaysScreen())),
      },

      // HR & Payroll
      {
        'category': 'HR & Payroll',
        'icon': Icons.people_outline,
        'label': 'Employee Management',
        'permission': 'HR_EMPLOYEES',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeScreen())),
      },
      {
        'category': 'HR & Payroll',
        'icon': Icons.access_time,
        'label': 'Attendance & Leaves',
        'permission': 'HR_ATTENDANCE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
      },
      {
        'category': 'HR & Payroll',
        'icon': Icons.account_balance_wallet_outlined,
        'label': 'Payroll',
        'permission': 'HR_PAYROLL',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen())),
      },
      {
        'category': 'HR & Payroll',
        'icon': Icons.tune_outlined,
        'label': 'HR Masters',
        'permission': 'HR_MASTERS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmsMastersScreen())),
      },

      // Restaurant (Beta)
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.restaurant_menu,
        'label': 'Captain Console',
        'isBeta': true,
        'permission': 'RESTAURANT_CONSOLE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptainDashboardScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.room_service_outlined,
        'label': 'Waiter Floor Terminal',
        'subLabel': 'Post kitchen orders, print bills, and track running & settled tickets',
        'isBeta': true,
        'permission': 'RESTAURANT_CONSOLE',
        'keywords': ['waiter', 'waiter app', 'table order', 'kot', 'kitchen order', 'proforma', 'running orders', 'floor app'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaiterAppScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.map_outlined,
        'label': 'Floor Designer',
        'isBeta': true,
        'permission': 'RESTAURANT_FLOOR_DESIGN',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FloorPlanConfigurator())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.soup_kitchen_outlined,
        'label': 'Kitchen KDS Queue',
        'isBeta': true,
        'permission': 'RESTAURANT_KDS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KdsScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.receipt_long_outlined,
        'label': 'KOT Order History',
        'subLabel': 'Kitchen order tickets audit logs, reprints & cancellation reasons',
        'isBeta': true,
        'permission': 'RESTAURANT_CONSOLE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KotsHistoryScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.qr_code_2_outlined,
        'label': 'Table QR Designer',
        'subLabel': 'Design & print branded QR standees with custom styles & cutlery icons',
        'isBeta': true,
        'permission': 'RESTAURANT_SETUP',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TableQrDesignerScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.event_seat_outlined,
        'label': 'Table Reservations',
        'subLabel': 'Guest booking calendar, time slot scheduling & table allocation',
        'isBeta': true,
        'permission': 'RESTAURANT_SETUP',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TableReservationScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.mobile_friendly_outlined,
        'label': 'Customer QR Dining (Preview)',
        'subLabel': 'Swiggy/Zomato style customer self-ordering, cart & digital bill self-pay',
        'isBeta': true,
        'permission': 'RESTAURANT_CONSOLE',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TableDiningScreen(
              tableName: 'Table 1',
              tableId: '1',
              outletId: _selectedDashboardOutletId != null ? _selectedDashboardOutletId.toString() : (user?.outletId.toString() ?? '1'),
            ),
          ),
        ),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.settings_applications_outlined,
        'label': 'Restaurant Setup',
        'isBeta': true,
        'permission': 'RESTAURANT_SETUP',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantSetupScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.analytics_outlined,
        'label': 'Restaurant Analytics & Reports',
        'isBeta': true,
        'permission': 'RESTAURANT_ANALYTICS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantAnalyticsReportsScreen())),
      },

      // Clinic & Health (Beta) Module
      {
        'category': 'Clinic & Health (Beta)',
        'icon': Icons.medical_services_outlined,
        'label': 'Doctor Appointments & Consultation',
        'subLabel': 'Patient consultation, Rx prescription auto-fill, vital signs & token queue',
        'isBeta': true,
        'permission': 'DOCTOR_CONSULTATION|CLINIC_APPOINTMENTS|PRESCRIPTIONS',
        'keywords': ['doctor', 'clinic', 'appointment', 'consultation', 'prescription', 'patient', 'token'],
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClinicDashboardScreen(
              initialTab: ClinicTab.doctor,
              userRole: user?.role,
              userPermissions: PermissionService.user?.permissions,
            ),
          ),
        ),
      },
      {
        'category': 'Clinic & Health (Beta)',
        'icon': Icons.point_of_sale_rounded,
        'label': 'Clinic Billing & Pharmacy POS',
        'subLabel': 'Prescription billing, direct medicine dispense & pharmacy cashier register',
        'isBeta': true,
        'permission': 'CLINIC_PHARMACY',
        'keywords': ['clinic billing', 'pharmacy pos', 'medicine billing', 'dispense', 'rx bill'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleScreen(businessModule: 'CLINIC'))),
      },
      {
        'category': 'Clinic & Health (Beta)',
        'icon': Icons.medication_liquid_rounded,
        'label': 'Medicines, Lab Tests & Services Master',
        'subLabel': 'Manage pharmaceutical formulations, lab investigation pricing & therapy catalog',
        'isBeta': true,
        'permission': 'ITEM_MASTER|CLINIC_PHARMACY',
        'keywords': ['medicine master', 'drug master', 'lab test master', 'clinical services', 'pharmacy items'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemMasterScreen(isClinicMode: true))),
      },
      {
        'category': 'Clinic & Health (Beta)',
        'icon': Icons.hourglass_bottom_rounded,
        'label': 'Receiving Expiry & Batch Tracker',
        'subLabel': 'Medicine expiry watch, batch-wise shelf life & supplier receiving ledger',
        'isBeta': true,
        'permission': 'INVENTORY_MANAGEMENT|CLINIC_PHARMACY',
        'keywords': ['expiry', 'batch', 'shelf life', 'receiving ledger', 'grn expiry', 'medicine expiry'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpiryTrackerScreen())),
      },
      {
        'category': 'Clinic & Health (Beta)',
        'icon': Icons.insights_rounded,
        'label': 'Clinic Operational Intelligence',
        'subLabel': 'Doctor workload, consultation revenue analytics & patient demographics',
        'isBeta': true,
        'permission': 'CLINIC_ANALYTICS',
        'keywords': ['clinic analytics', 'doctor workload', 'consultation fees', 'demographics', 'clinic kpi'],
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClinicDashboardScreen(
              initialTab: ClinicTab.analytics,
              userRole: user?.role,
              userPermissions: PermissionService.user?.permissions,
            ),
          ),
        ),
      },
      {
        'category': 'Clinic & Health (Beta)',
        'icon': Icons.badge_outlined,
        'label': 'Doctor Profiles & Public Directory Settings',
        'subLabel': 'Clinician fees, specialities, license registration numbers & public listing options',
        'isBeta': true,
        'permission': 'DOCTOR_CONSULTATION|CLINIC_APPOINTMENTS',
        'keywords': ['doctor profile', 'clinician', 'consultation fee', 'public doctor', 'license', 'registration'],
        'onTap': () => showDialog(context: context, builder: (_) => const ClinicDoctorManagementDialog()),
      },
      {
        'category': 'Clinic & Health (Beta)',
        'icon': Icons.public_rounded,
        'label': 'Explore Doctors & Online Patient Booking',
        'subLabel': 'Patient-facing portal for online appointment booking, doctor search & medical history',
        'isBeta': true,
        'permission': 'CLINIC_APPOINTMENTS',
        'keywords': ['online booking', 'explore doctors', 'patient portal', 'public appointment', 'telehealth'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublicAppointmentBookingScreen())),
      },
      {
        'category': 'Finance & Expenses',
        'icon': Icons.payments_outlined,
        'label': 'Regular Expenses',
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashLedgerScreen(initialIndex: 2))),
      },
      {
        'category': 'Finance & Expenses',
        'icon': Icons.schedule_outlined,
        'label': 'Recurring Expenses',
        'permission': 'RECURRING_EXPENSES',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringExpensesScreen())),
      },
      {
        'category': 'Finance & Expenses',
        'icon': Icons.local_shipping_outlined,
        'label': 'Delivery Challans',
        'permission': 'DELIVERY_CHALLANS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryChallanScreen())),
      },

      // Finance & Accounting (Beta) Section
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.account_balance,
        'label': 'Accounting Section Hub',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountingDashboardScreen())),
      },
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.receipt_long,
        'label': 'Accounting Vouchers',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountingVouchersScreen())),
      },
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.account_balance_wallet,
        'label': 'Company Bank Accounts',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankAccountsScreen())),
      },
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.balance,
        'label': 'Trial Balance Report',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrialBalanceScreen())),
      },
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.show_chart,
        'label': 'Profit & Loss Statement (P&L)',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfitLossScreen())),
      },
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.assessment,
        'label': 'Balance Sheet Statement',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BalanceSheetScreen())),
      },

      // Stock View
      {
        'category': 'Stock View',
        'icon': Icons.inventory_2,
        'label': 'Stock Balance',
        'permission': 'STOCK_BALANCE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockBalanceScreen())),
      },
      {
        'category': 'Stock View',
        'icon': Icons.hourglass_bottom,
        'label': 'Expiry & Batch Tracker',
        'permission': 'STOCK_BALANCE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpiryTrackerScreen())),
      },
      {
        'category': 'Stock View',
        'icon': Icons.warning,
        'label': 'Damage Summary',
        'permission': 'DAMAGE_SUMMARY',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DamageSummaryScreen())),
      },

      // Reports
      {
        'category': 'Reports',
        'icon': Icons.receipt_long,
        'label': 'Receiving Report',
        'permission': 'STOCK_IN_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockInReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.receipt,
        'label': 'Stock Dispatch Report',
        'permission': 'STOCK_OUT_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockOutReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.swap_horiz,
        'label': 'Stock Transfer Report',
        'permission': 'STOCK_TRANSFER_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockTransferReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.analytics,
        'label': 'Stock Transfer Progress Dashboard',
        'subLabel': 'Overall progress for all outlets or individual outlet view',
        'permission': 'STOCK_TRANSFER_REPORT',
        'keywords': ['stock transfer progress', 'inter outlet progress', 'overall outlet progress', 'individual outlet progress', 'transfer tracking'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferProgressDashboardScreen())),
      },
      if (_showRetailSalesReportSection) ...[
        {
          'category': 'Reports',
          'icon': Icons.point_of_sale,
          'label': 'Retail Sales Report',
          'permission': 'RETAIL_SALES_REPORT',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => SalesReportScreen(businessModule: _businessModule))),
        },
        {
          'category': 'Reports',
          'icon': Icons.water_drop,
          'label': 'Subscription Report',
          'permission': 'SUBSCRIPTION_REPORT',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionReportScreen())),
        },
      ],
      {
        'category': 'Reports',
        'icon': Icons.local_offer_outlined,
        'label': 'Scheme Report',
        'permission': 'SCHEME_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchemeReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.analytics_outlined,
        'label': 'Scheme Analysis',
        'permission': 'SCHEME_ANALYSIS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchemeAnalysisScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.workspace_premium_outlined,
        'label': 'Loyalty Report',
        'permission': 'LOYALTY_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoyaltyReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.insights_outlined,
        'label': 'Store Analysis',
        'permission': 'STORE_ANALYSIS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreAnalysisScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.confirmation_number_outlined,
        'label': 'Lucky Draw Campaigns',
        'permission': 'LUCKY_DRAW',
        'isBeta': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LuckyDrawCampaignScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.analytics_outlined,
        'label': 'Brand Analysis',
        'permission': 'BRAND_ANALYSIS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrandAnalysisScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.source_outlined,
        'label': 'Sale Source Analysis',
        'permission': 'SOURCE_ANALYSIS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourceAnalysisScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.percent_outlined,
        'label': 'Commission Report',
        'permission': 'COMMISSION_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommissionReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.payments_outlined,
        'label': 'Payment Method Analysis',
        'permission': 'PAYMENT_ANALYSIS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentAnalysisScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.auto_awesome,
        'label': 'AI Query Analytics',
        'permission': 'AI_QUERY_ANALYTICS',
        'isBeta': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiQueryAnalyticsScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.inventory,
        'label': 'Closing Report',
        'permission': 'CLOSING_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClosingReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.nightlight_round,
        'label': 'Night Audit (EOD)',
        'permission': 'NIGHT_AUDIT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NightAuditScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.receipt_long_outlined,
        'label': 'Stock Ledger Report',
        'permission': 'STOCK_LEDGER_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockLedgerReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.payment_outlined,
        'label': 'Vendor Payment Report',
        'permission': 'VENDOR_PAYMENT_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierPaymentsReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.store,
        'label': 'Vendor Purchase Order',
        'permission': 'PURCHASE_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.account_balance,
        'label': 'Finance & Reports',
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashLedgerScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.account_balance_wallet,
        'label': 'Accounting Section',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountingDashboardScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.refresh,
        'label': 'Return Report',
        'permission': 'RETURN_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnReportScreen())),
      },      {        'category': 'Reports',        'icon': Icons.assignment_return_outlined,        'label': 'Supplier Return Report',        'permission': 'SUPPLIER_RETURN',        'keywords': ['supplier return report', 'vendor return report', 'purchase return report'],        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierReturnReportScreen())),      },
      {
        'category': 'Reports',
        'icon': Icons.outbond_rounded,
        'label': 'Request Report',
        'permission': 'REQUEST_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.warehouse,
        'label': 'Damage Report',
        'permission': 'DAMAGE_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DamageReportSumScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.cloud_sync_rounded,
        'label': '🛒 Third-Party Orders',
        'isBeta': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThirdPartyOrdersReportScreen())),
      },

      /*
      // LYNX Innovation Hub (Hidden for future release)
      {
        'category': 'LYNX Innovation Hub',
        'icon': Icons.science_rounded,
        'label': '⚡ Feature Testing Hub',
        'subLabel': 'Test all features from Phase 1 to Plugins',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LynxFeatureTestingScreen())),
      },
      {
        'category': 'LYNX Innovation Hub',
        'icon': Icons.psychology_rounded,
        'label': '🤖 Autonomous AI Agent',
        'subLabel': 'Phase 5: Proactive Anomaly Proposals',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutonomousAgentScreen())),
      },
      {
        'category': 'LYNX Innovation Hub',
        'icon': Icons.speed_rounded,
        'label': '⚙️ Operations Intelligence',
        'subLabel': 'Phase 3: Sales Velocity & Expiry Watcher',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsIntelligenceScreen())),
      },
      {
        'category': 'LYNX Innovation Hub',
        'icon': Icons.bolt_rounded,
        'label': '⚡ Workflow Automation',
        'subLabel': 'Phase 4: Rule-based WhatsApp & PO engine',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkflowAutomationScreen())),
      },
      */

      // Developer & Integrations (Ecosystem, Marketplace, Dev Studio)
      {
        'category': 'Developer & Integrations',
        'icon': Icons.code_rounded,
        'label': '🔌 Developer & Webhooks',
        'subLabel': 'Developer Portal ➜ Open REST APIs, Webhooks, API Keys',
        'isBeta': true,
        'keywords': ['developer', 'webhooks', 'api keys', 'rest api', 'integrations'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperEcosystemScreen())),
      },
      {
        'category': 'Developer & Integrations',
        'icon': Icons.extension_rounded,
        'label': '🛍️ Add-on Plugin Marketplace',
        'subLabel': 'Plugins ➜ Payment Gateways, Flipkart Order Sync, Tally ERP',
        'isBeta': true,
        'keywords': ['plugins', 'marketplace', 'add-ons', 'payment gateway', 'flipkart', 'tally', 'razorpay'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginMarketplaceScreen())),
      },
      {
        'category': 'Developer & Integrations',
        'icon': Icons.terminal_rounded,
        'label': '🛠️ Plugin Developer Studio',
        'subLabel': 'Dev Studio ➜ Build, sandbox test, & deploy JS/TS plugins',
        'isBeta': true,
        'keywords': ['plugin studio', 'developer studio', 'typescript plugin', 'javascript plugin', 'custom plugin', 'code editor'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginDevStudioScreen())),
      },

      // System
      /*
      {
        'category': 'System',
        'icon': Icons.science_rounded,
        'label': '⚡ LYNX Feature Testing Hub',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LynxFeatureTestingScreen())),
      },
      */
      {
        'category': 'System',
        'icon': Icons.help_outline,
        'label': 'Help',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
      },
      {
        'category': 'System',
        'icon': Icons.settings,
        'label': 'Settings',
        'permission': 'SETTINGS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => loadUser()),
      },
      {
        'category': 'System',
        'icon': Icons.dns_rounded,
        'label': 'Storage & Backups',
        'permission': 'SETTINGS',
        'onTap': () {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const SizedBox(
                width: 440,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: StorageBackupCard(),
                ),
              ),
            ),
          );
        },
      },
      {
        'category': 'System',
        'icon': Icons.lock_reset,
        'label': 'Change Password',
        'onTap': () {
          Navigator.pop(context);
          _changePassword(userName);
        },
      },
      {
        'category': 'System',
        'icon': Icons.logout,
        'label': 'Logout',
        'onTap': () async {
          await TokenStorage.clear();
          _notificationTimer?.cancel();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false);
        },
      },
      if (PermissionService.can('SYSTEM_UPDATE'))
        {
          'category': 'System',
          'icon': Icons.system_update_alt,
          'label': 'Check for Updates',
          'permission': 'SYSTEM_UPDATE',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemUpdateScreen())),
        },
    ];

    final categories = [
      'LYNX Innovation Hub',
      'Billing',
      'Operations',
      'Modify',
      _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
      'HR & Payroll',
      'Restaurant (Beta)',
      'Clinic & Health (Beta)',
      'Finance & Accounting (Beta)',
      'Finance & Expenses',
      'Stock View',
      'Reports',
      'Developer & Integrations',
      'System',
    ];

    final isSearching = _drawerSearchQuery.trim().isNotEmpty;
    final searchQuery = _drawerSearchQuery.trim().toLowerCase();

    final List<Map<String, dynamic>> deepSearchRegistry = [
      // Settings / System
      {
        'category': 'System',
        'icon': Icons.delete_forever_outlined,
        'label': 'Clear Transaction Data',
        'subLabel': 'Settings ➜ Clear Transaction Data',
        'permission': 'SETTINGS',
        'keywords': ['clear transaction data', 'delete data', 'wipe data', 'reset data', 'reset database', 'clear transactional data', 'transaction clear', 'database wipe'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => loadUser()),
      },
      {
        'category': 'System',
        'icon': Icons.branding_watermark_outlined,
        'label': 'Show Brand Name in Print',
        'subLabel': 'Settings ➜ Show Brand Name in Print / Bills',
        'permission': 'SETTINGS',
        'keywords': ['show brand name', 'brand name in print', 'brand display', 'print brand name', 'toggle brand'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => loadUser()),
      },
      {
        'category': 'System',
        'icon': Icons.remove_shopping_cart_outlined,
        'label': 'Allow Negative Stock',
        'subLabel': 'Settings ➜ Allow Negative Stock Toggle',
        'permission': 'SETTINGS',
        'keywords': ['allow negative stock', 'negative inventory', 'out of stock billing', 'negative stock', 'stock setup'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => loadUser()),
      },
      {
        'category': 'System',
        'icon': Icons.email_outlined,
        'label': 'SMTP Email Setup',
        'subLabel': 'SMTP Email Setup ➜ outgoing mail server configurations',
        'permission': 'SETTINGS',
        'keywords': ['smtp email setup', 'mail server', 'email settings', 'smtp setup', 'outgoing mail server'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmtpSettingsScreen())),
      },

      // Restaurant Module
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.event_seat_outlined,
        'label': 'Table Bookings & Reservations',
        'subLabel': 'Restaurant Setup ➜ Reservations (Expected Arrivals)',
        'permission': 'RESTAURANT_SETUP',
        'keywords': ['table bookings', 'reservations', 'booking setup', 'expected arrivals', 'seated bookings', 'arrivals', 'book table'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantSetupScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.soup_kitchen_outlined,
        'label': 'Kitchen Order Preparation (KDS)',
        'subLabel': 'Kitchen KDS Queue ➜ Preparing, Ready, Served, Rejected status tracking',
        'permission': 'RESTAURANT_KDS',
        'keywords': ['kitchen queue', 'kds', 'kot queue', 'cooking status', 'chef console', 'order preparation', 'ready orders', 'serve orders'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KdsScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.table_bar_outlined,
        'label': 'Billing, Settle & Consolidation',
        'subLabel': 'Captain Console ➜ Table selection, checkout billing dialog',
        'permission': 'RESTAURANT_CONSOLE',
        'keywords': ['consolidated billing', 'settle bill', 'print bill', 'table billing', 'pos checkout', 'cashier dialog', 'billing checkout'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptainDashboardScreen())),
      },

      // Billing & Sales
      {
        'category': 'Billing',
        'icon': Icons.point_of_sale,
        'label': 'Billing (POS) / Retail Sale Screen',
        'subLabel': 'Billing ➜ POS Cashier Counter, Sales Billing, Invoice Generation',
        'permission': 'RETAIL_SALES',
        'keywords': ['sale', 'sales', 'retail sale', 'retail sales', 'pos', 'billing', 'bill', 'billing pos', 'counter billing', 'invoice', 'make bill', 'pos sale', 'retail', 'salescreen'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleScreen())),
      },
      // Operations & Sales
      {
        'category': 'Operations',
        'icon': Icons.point_of_sale_outlined,
        'label': 'Customer Database & Lists',
        'subLabel': 'Retail Sales ➜ Search customer, phone number registration',
        'permission': 'RETAIL_SALES',
        'keywords': ['customer data', 'customer phone', 'customer list', 'customer name', 'customer profile', 'loyalty points', 'customer database'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.storefront_rounded,
        'label': 'B2B Wholesale Marketplace',
        'subLabel': 'Browse verified vendors, order commodities at wholesale rates & auto-generate PO',
        'permission': 'PURCHASE_ORDER',
        'onTap': () => CloudFeatureGate.navigate(
          context,
          featureName: 'B2B Wholesale Marketplace',
          featureDescription:
              'Wholesale merchant marketplace to discover regional verified vendors and place wholesale purchase orders online.',
          featureIcon: Icons.storefront_rounded,
          destination: const B2BMarketplaceScreen(),
        ),
      },
      {
        'category': 'Operations',
        'icon': Icons.shopping_cart_checkout,
        'label': 'Create Purchase Order (PO)',
        'subLabel': 'Purchase Order ➜ create/modify supplier purchase orders',
        'permission': 'PURCHASE_ORDER',
        'keywords': ['purchase order', 'create po', 'vendor po', 'buy from supplier', 'purchase items'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrderScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.download,
        'label': 'Vendor Receive Order (GRN)',
        'subLabel': 'Vendor Receive Order ➜ inbound inventory receiving logs',
        'permission': 'STOCK_IN',
        'keywords': ['vendor receive order', 'vendor receive', 'vendor order', 'vendor received order', 'grn', 'goods receiving', 'receive vendor stock', 'goods receipt note', 'stock in', 'vendor invoice', 'receive goods from vendor'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoodsReceivingScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.hourglass_bottom_rounded,
        'label': 'Receiving Expiry & Batch Tracker',
        'subLabel': 'Operations ➜ Shelf life, batch ledgers, shorter-expiry detection & inventory risk (Retail, Restaurant, Store & Clinic)',
        'permission': 'INVENTORY_MANAGEMENT',
        'keywords': ['expiry', 'batch', 'shelf life', 'receiving ledger', 'grn expiry', 'restaurant expiry', 'retail expiry', 'store expiry'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpiryTrackerScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.upload,
        'label': 'Stock Dispatch (Stock Out)',
        'subLabel': 'Stock Dispatch ➜ outbound department issue orders',
        'permission': 'STOCK_OUT',
        'keywords': ['stock dispatch', 'issue stock', 'department issue', 'stock out', 'issue items'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockIssueScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.swap_horiz,
        'label': 'Stock Transfer Orders',
        'subLabel': 'Stock Transfer ➜ move inventory between warehouse locations',
        'permission': 'STOCK_TRANSFER',
        'keywords': ['stock transfer', 'warehouse transfer', 'location transfer', 'move stock'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockTransferScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.warning_amber,
        'label': 'Broken & Damaged Items Log',
        'subLabel': 'Damage Items ➜ record spoilage, broken, or expired stock',
        'permission': 'DAMAGE',
        'keywords': ['damage entry', 'broken items', 'expired stock', 'waste inventory', 'spoilage'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DamageItemScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.build,
        'label': 'Product Assembly (BOM)',
        'subLabel': 'Product Assembly ➜ Bill of Materials manufacturing items',
        'permission': 'PRODUCT_ASSEMBLY',
        'keywords': ['product assembly', 'bom', 'bill of materials', 'manufacture item', 'raw materials', 'assembling'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssemblyScreen())),
      },

      // Masters Setup
      {
        'category': 'Masters',
        'icon': Icons.settings_suggest_outlined,
        'label': 'Document Number Sequences',
        'subLabel': 'Document Sequence Settings ➜ prefixes for invoices, GRNs, KOTs',
        'permission': 'NUMBERING_SETTINGS',
        'keywords': ['numbering settings', 'document sequences', 'kot numbering prefix', 'invoice prefix', 'grn prefix sequence'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentSequenceScreen())),
      },
      {
        'category': 'Masters',
        'icon': Icons.supervised_user_circle,
        'label': 'User Management & Roles',
        'subLabel': 'User Management ➜ create user, reset passwords, set permissions',
        'permission': 'USER_MANAGEMENT',
        'keywords': ['user management', 'create user', 'reset password', 'permission setup', 'staff roles', 'access control'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
      },
      {
        'category': 'Masters',
        'icon': Icons.stars_outlined,
        'label': 'Loyalty Rewards Program',
        'subLabel': 'Loyalty Program ➜ configurations, cashback & rewards configuration',
        'permission': 'LOYALTY_PROGRAM',
        'keywords': ['loyalty program', 'loyalty points system', 'points configuration', 'cashback rewards', 'member points'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoyaltyMasterConfigScreen())),
      },
      {
        'category': 'Masters',
        'icon': Icons.chat_bubble_outline,
        'label': 'WhatsApp API Settings',
        'subLabel': 'WhatsApp Integration ➜ automatic alerts and template setup',
        'permission': 'WHATSAPP_INTEGRATION',
        'keywords': ['whatsapp integration', 'message templates', 'whatsapp api key', 'broadcast', 'automatic invoice alerts'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WhatsAppDashboardScreen())),
      },

      // HR & Payroll
      {
        'category': 'HR & Payroll',
        'icon': Icons.people_outline,
        'label': 'Staff & Employee Profiles',
        'subLabel': 'Employee Management ➜ add staff, edit salary structures',
        'permission': 'HR_EMPLOYEES',
        'keywords': ['employee management', 'staff profiles', 'salary details', 'hr profile', 'create employee'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeScreen())),
      },
      {
        'category': 'HR & Payroll',
        'icon': Icons.access_time,
        'label': 'Staff Attendance & Leaves',
        'subLabel': 'Attendance & Leaves ➜ mark attendance, submit leaves',
        'permission': 'HR_ATTENDANCE',
        'keywords': ['attendance log', 'leave application', 'mark leave', 'staff checkin', 'shift times'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
      },
      {
        'category': 'HR & Payroll',
        'icon': Icons.account_balance_wallet_outlined,
        'label': 'Payroll Payouts & Payslips',
        'subLabel': 'Payroll ➜ run monthly payrolls, view staff payslips',
        'permission': 'HR_PAYROLL',
        'keywords': ['payroll generation', 'monthly salary slip', 'generate payroll', 'payslip', 'salary payout'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen())),
      },

      // Financials & Schemes
      {
        'category': 'Reports',
        'icon': Icons.account_balance,
        'label': 'Cash Book & Finance Ledger',
        'subLabel': 'Finance & Reports ➜ account entries, cash ledgers',
        'permission': 'CASH_LEDGER',
        'keywords': ['cash ledger', 'cash book', 'bank account ledger', 'finance summary', 'journal entry'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashLedgerScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.local_offer_outlined,
        'label': 'Discount Schemes Summary',
        'subLabel': 'Scheme Report ➜ promotional coupons and customer offers',
        'permission': 'SCHEME_REPORT',
        'keywords': ['scheme report', 'discount list', 'promotions summary', 'active coupons', 'special rates list'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchemeReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.badge_outlined,
        'label': 'Cashier Shift Handover Analytics',
        'subLabel': 'Handover Report ➜ day-wise physical cash count, cashier variance, shortage alerts',
        'permission': 'REPORTS',
        'keywords': ['cashier handover', 'shift handover report', 'cashier cash count', 'cashier report', 'cashier variance', 'handover analytics'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashierHandoverReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.auto_awesome,
        'label': 'AI Query Analytics',
        'subLabel': 'AI Analysis ➜ Ask natural language questions, deepseek, gemini, claude, perplexity, openai',
        'permission': 'AI_QUERY_ANALYTICS',
        'keywords': ['ai analysis', 'ai query analytics', 'ai analytics', 'ai report', 'ai assistant', 'ai query', 'natural language analytics', 'deepseek', 'gemini', 'perplexity', 'claude', 'openai', 'llm', 'ai model'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiQueryAnalyticsScreen())),
      },
    ];

    final filteredDrawerItems = ModuleCapability.filterDrawerItems(allDrawerItems, _businessModule);
    final filteredDeepSearch = ModuleCapability.filterDrawerItems(deepSearchRegistry, _businessModule);

    final matchingItems = !isSearching
        ? <Map<String, dynamic>>[]
        : [
            ...filteredDrawerItems.where((item) {
              final label = (item['label'] as String).toLowerCase();
              final category = (item['category'] as String).toLowerCase();
              final List<String> keywords = List<String>.from(item['keywords'] ?? []);
              final perm = item['permission'] as String?;
              if (perm != null && !PermissionService.can(perm)) return false;
              return label.contains(searchQuery) ||
                  category.contains(searchQuery) ||
                  keywords.any((kw) => kw.contains(searchQuery));
            }),
            ...filteredDeepSearch.where((item) {
              final label = (item['label'] as String).toLowerCase();
              final subLabel = (item['subLabel'] as String).toLowerCase();
              final category = (item['category'] as String).toLowerCase();
              final List<String> keywords = List<String>.from(item['keywords'] ?? []);
              final perm = item['permission'] as String?;
              if (perm != null && !PermissionService.can(perm)) return false;
              return label.contains(searchQuery) ||
                  subLabel.contains(searchQuery) ||
                  category.contains(searchQuery) ||
                  keywords.any((kw) => kw.contains(searchQuery));
            }),
          ];

    Widget buildHeader() {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Clickable User Avatar & Profile Info (Tap to view full ID & copy)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showUserDetailDialog(context, userName, userEmail, userRole, hotelName),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                  child: Row(
                    children: [
                      _buildDrawerHeaderLogoWidget(propInfo?.logoPath ?? property?.logoPath, 56),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    userRole.isNotEmpty ? userRole.toUpperCase() : 'ADMIN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Active session uptime duration tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.circle, size: 5, color: Color(0xFF10B981)),
                                      const SizedBox(width: 3),
                                      Text(
                                        sessionDuration,
                                        style: const TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    userName.isNotEmpty ? userName : 'System Administrator',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimaryColor,
                                    ),
                                  ),
                                ),
                                Icon(Icons.info_outline_rounded, size: 14, color: textSecondaryColor.withOpacity(0.6)),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Tap for full User ID',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: textSecondaryColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Account Security',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _changePassword(userName),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.key_outlined,
                      size: 17,
                      color: textSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildFooter() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.business_outlined,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hotelName.isNotEmpty ? hotelName : 'Famalth technologies',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'v$currentVersion',
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Build: 2025-12-04',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: textSecondaryColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          buildHeader(),

          // 100% Fully Pill-Rounded Search Input Bar (Google & Microsoft style)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  style: TextStyle(color: textPrimaryColor, fontSize: 13, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Search Menu...',
                    hintStyle: TextStyle(
                      color: textSecondaryColor.withOpacity(0.65),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 8),
                      child: Icon(Icons.search_rounded, color: textSecondaryColor, size: 18),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
                    suffixIcon: _drawerSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: textSecondaryColor, size: 16),
                            onPressed: () {
                              setState(() {
                                _drawerSearchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _drawerSearchQuery = val;
                    });
                  },
                ),
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                if (isSearching) ...[
                  if (matchingItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No menu items found',
                          style: TextStyle(color: textSecondaryColor, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...matchingItems.map((item) {
                      return _drawerItem(
                        item['icon'] as IconData,
                        item['label'] as String,
                        permission: item['permission'] as String?,
                        isBeta: item['isBeta'] as bool? ?? false,
                        isNew: item['isNew'] as bool? ?? false,
                        isDeprecated: item['isDeprecated'] as bool? ?? false,
                        isFutureUpdate: item['isFutureUpdate'] as bool? ?? false,
                        onTap: item['onTap'] as VoidCallback?,
                        isSubItem: false,
                        categoryName: item['category'] as String?,
                        subLabel: item['subLabel'] as String?,
                      );
                    }),
                ] else ...[
                  // FAVORITES SECTION (Show all starred features directly, no expansion tile)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'FAVORITES',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.8,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => _openManageFavoritesDialog(filteredDrawerItems),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.tune_rounded, size: 13, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Customize',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_favoriteDrawerItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star_outline_rounded, size: 16, color: textSecondaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap the star icon on any feature to pin it here.',
                                style: TextStyle(fontSize: 11.5, color: textSecondaryColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filteredDrawerItems.where((item) {
                      final label = item['label'] as String;
                      if (!_favoriteDrawerItems.contains(label)) return false;
                      final perm = item['permission'] as String?;
                      if (perm != null && !PermissionService.can(perm)) return false;
                      return true;
                    }).map((item) {
                      return _drawerItem(
                        item['icon'] as IconData,
                        item['label'] as String,
                        permission: item['permission'] as String?,
                        isBeta: item['isBeta'] as bool? ?? false,
                        isNew: item['isNew'] as bool? ?? false,
                        isDeprecated: item['isDeprecated'] as bool? ?? false,
                        isFutureUpdate: item['isFutureUpdate'] as bool? ?? false,
                        onTap: item['onTap'] as VoidCallback?,
                        isSubItem: false,
                        isFavoriteSectionItem: true,
                        categoryName: item['category'] as String?,
                      );
                    }),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),

                  // CATEGORIES SECTION
                  ...categories.map((categoryName) {
                    final categoryItems = filteredDrawerItems.where((item) {
                      if (item['category'] != categoryName) return false;
                      final perm = item['permission'] as String?;
                      if (perm != null && !PermissionService.can(perm)) return false;
                      return true;
                    }).toList();

                    if (categoryItems.isEmpty) return const SizedBox();

                    return Theme(
                      data: theme.copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        key: PageStorageKey<String>(categoryName),
                        leading: Icon(
                          _getCategoryIcon(categoryName),
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          size: 20,
                        ),
                        title: Text(
                          categoryName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textPrimaryColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                        children: categoryItems.map((item) {
                          return _drawerItem(
                            item['icon'] as IconData,
                            item['label'] as String,
                            permission: item['permission'] as String?,
                            isBeta: item['isBeta'] as bool? ?? false,
                            isNew: item['isNew'] as bool? ?? false,
                            isDeprecated: item['isDeprecated'] as bool? ?? false,
                            isFutureUpdate: item['isFutureUpdate'] as bool? ?? false,
                            onTap: item['onTap'] as VoidCallback?,
                            isSubItem: true,
                            categoryName: categoryName,
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          // FOOTER
          buildFooter(),
        ],
      ),
    );
  }

  Widget _drawerItem(
    IconData ic,
    String label, {
    VoidCallback? onTap,
    String? permission,
    bool isBeta = false,
    bool isNew = false,
    bool isDeprecated = false,
    bool isFutureUpdate = false,
    bool isSubItem = false,
    bool isFavoriteSectionItem = false,
    String? categoryName,
    String? subLabel,
  }) {
    if (permission != null && !PermissionService.can(permission)) {
      return const SizedBox();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final isFavorited = _favoriteDrawerItems.contains(label);

    Widget? badgeWidget;
    if (isBeta) {
      badgeWidget = _buildBadge('BETA', const Color(0xFFEF4444));
    } else if (isNew) {
      badgeWidget = _buildBadge('NEW', const Color(0xFF10B981));
    } else if (isDeprecated) {
      badgeWidget = _buildBadge('DEP', const Color(0xFF64748B));
    } else if (isFutureUpdate) {
      badgeWidget = _buildBadge('UPCOMING', const Color(0xFFF59E0B));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(isSubItem ? 16 : 10, 1, 10, 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap ?? () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                if (isSubItem && !isFavoriteSectionItem) ...[
                  Container(
                    width: 1.5,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(
                  ic,
                  size: (isSubItem && !isFavoriteSectionItem) ? 16 : 19,
                  color: (isSubItem && !isFavoriteSectionItem)
                      ? (isDark ? Colors.white70 : const Color(0xFF64748B))
                      : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: (isSubItem && !isFavoriteSectionItem) ? 12.5 : 13,
                                fontWeight: (isSubItem && !isFavoriteSectionItem) ? FontWeight.w500 : FontWeight.w600,
                                color: textPrimaryColor,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          if (isFavoriteSectionItem && categoryName != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '($categoryName)',
                              style: TextStyle(
                                fontSize: 10,
                                color: textSecondaryColor.withOpacity(0.7),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subLabel != null) ...[
                        const SizedBox(height: 2.5),
                        Text(
                          subLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: textSecondaryColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (badgeWidget != null) ...[
                  const SizedBox(width: 6),
                  badgeWidget,
                ],
                // Star Toggle Button for Favorites (hide for deep sub-features)
                if (subLabel == null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _toggleFavorite(label),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isFavorited ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 17,
                          color: isFavorited
                              ? const Color(0xFFFFB800)
                              : textSecondaryColor.withOpacity(0.35),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _changePassword(String username) {
    final formKey = GlobalKey<FormState>();
    final oldPass = TextEditingController();
    final newPass = TextEditingController();
    final confirm = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('Change Password', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          "Updating password for: $username",
                          style:
                              const TextStyle(color: Colors.blue, fontSize: 13),
                        ),
                      ),

                      // CURRENT PASSWORD
                      TextFormField(
                        controller: oldPass,
                        obscureText: obscureOld,
                        decoration: InputDecoration(
                          labelText: 'Current Password *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureOld
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () =>
                                setDialogState(() => obscureOld = !obscureOld),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // NEW PASSWORD
                      TextFormField(
                        controller: newPass,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New Password *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_reset),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () =>
                                setDialogState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 8
                            ? 'Must be at least 8 characters'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // CONFIRM PASSWORD
                      TextFormField(
                        controller: confirm,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.check_circle_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setDialogState(
                                () => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v != newPass.text)
                            return 'Passwords do not match';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => loading = true);

                          try {
                            await userCtrl.changePassword(
                                username, oldPass.text, newPass.text);

                            if (!context.mounted) return;
                            Navigator.pop(ctx); // Close dialog

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Password updated successfully.'),
                                  backgroundColor: Colors.green),
                            );
                            await TokenStorage.clear();
                            _notificationTimer?.cancel();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginScreen()),
                                (route) => false);
                          } catch (e) {
                            setDialogState(() => loading = false);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(e
                                      .toString()
                                      .replaceAll("Exception: ", "")),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // Widget _drawerItem(IconData ic, String label, {VoidCallback? onTap}) {
  //   return ListTile(
  //     leading: Icon(ic),
  //     title: Text(label),
  //     trailing: const Icon(Icons.chevron_right, size: 20),
  //     onTap: onTap ?? () => Navigator.of(context).pop(),
  //   );
  // }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  bool _hasAnyPermission(List<String> perms) {
    for (final p in perms) {
      if (PermissionService.can(p)) {
        return true;
      }
    }
    return false;
  }

  // ================= KPI =================
  Widget _kpiRow() {
    return Row(
      children: [
        _kpi('Today In', '$todayIn', Icons.input, Colors.green),
        const SizedBox(width: 12),
        _kpi('Today Out', '$todayOut', Icons.output, Colors.orange),
        const SizedBox(width: 12),
        _kpi('Low Stock', '$lowStock', Icons.warning, Colors.red),
        const SizedBox(width: 12),
        _kpi('Stock Value', _formatMoney(stockValue),
            _currencyIcon, Colors.purple),
      ],
    );
  }

  Widget _kpi(String t, String v, IconData i, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: c, child: Icon(i, color: Colors.white)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text(v,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ================= ALERT =================
  Widget _lowStockAlert() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Low Stock / Reorder Alert',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: lowStockItems
                .map((e) => Chip(
                      label: Text(e),
                      backgroundColor: Colors.red.shade50,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ================= CHARTS =================
  Widget _issueReceiveChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Stock Dispatch vs Receive (7 Days)'),
      primaryXAxis: const CategoryAxis(),
      legend: const Legend(isVisible: true),
      series: [
        ColumnSeries<_TxnDay, String>(
          name: 'Received',
          dataSource: issueReceive7,
          xValueMapper: (d, _) => d.day,
          yValueMapper: (d, _) => d.received,
        ),
        ColumnSeries<_TxnDay, String>(
          name: 'Stock Dispatch',
          dataSource: issueReceive7,
          xValueMapper: (d, _) => d.day,
          yValueMapper: (d, _) => d.issued,
        ),
      ],
    );
  }

  Widget _deptIssueChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Department-wise Stock Dispatch'),
      primaryXAxis: const CategoryAxis(),
      series: [
        BarSeries<_DeptIssue, String>(
          dataSource: deptIssue,
          xValueMapper: (d, _) => d.dept,
          yValueMapper: (d, _) => d.qty,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _damageChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Damage / Wastage (7 Days)'),
      primaryXAxis: const CategoryAxis(),
      series: [
        LineSeries<_DamageDay, String>(
          dataSource: damage7,
          xValueMapper: (d, _) => d.day,
          yValueMapper: (d, _) => d.qty,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _categoryStockChart() {
    return SfCircularChart(
      title: const ChartTitle(text: 'Stock Balance'),
      legend: const Legend(isVisible: true),
      series: [
        DoughnutSeries<_CategoryStock, String>(
          dataSource: categoryStock,
          xValueMapper: (d, _) => d.category,
          yValueMapper: (d, _) => d.percent,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _card(Widget c) => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(padding: const EdgeInsets.all(12), child: c),
      );

  Widget _chartCard(String title, String subtitle, Widget child,
      {double height = 320}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildDrawerHeaderLogoWidget(String? logoPath, double size) {
    return BrandLogoWidget(
      logoPath: logoPath,
      size: size,
    );
  }

  // ==================== HRMS DEDICATED DASHBOARD ====================

  Future<void> _loadHrmsDashboardData() async {
    if (!mounted) return;
    setState(() => _loadingHrmsData = true);
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final monthStr = DateFormat('yyyy-MM').format(now);

      final resEmployees = await ApiClient.get(ApiEndpoints.hrmsEmployees, silent: true);
      final List<Map<String, dynamic>> empList =
          resEmployees != null && resEmployees['data'] is List
              ? List<Map<String, dynamic>>.from(resEmployees['data'])
              : [];

      final resAttendance = await ApiClient.get(
          '${ApiEndpoints.hrmsAttendance}?month=$monthStr',
          silent: true);
      final List<Map<String, dynamic>> attList =
          resAttendance != null && resAttendance['data'] is List
              ? List<Map<String, dynamic>>.from(resAttendance['data'])
              : [];

      final resLeaves = await ApiClient.get(
          '${ApiEndpoints.hrmsLeaves}?status=Pending',
          silent: true);
      final List<Map<String, dynamic>> leavesList =
          resLeaves != null && resLeaves['data'] is List
              ? List<Map<String, dynamic>>.from(resLeaves['data'])
              : [];

      final resDesignations =
          await ApiClient.get(ApiEndpoints.hrmsDesignations, silent: true);
      final List<Map<String, dynamic>> desigList =
          resDesignations != null && resDesignations['data'] is List
              ? List<Map<String, dynamic>>.from(resDesignations['data'])
              : [];

      final resShifts =
          await ApiClient.get(ApiEndpoints.hrmsShifts, silent: true);
      final List<Map<String, dynamic>> shiftsList =
          resShifts != null && resShifts['data'] is List
              ? List<Map<String, dynamic>>.from(resShifts['data'])
              : [];

      final totalEmp = empList.length;
      final activeEmp = empList.where((e) {
        final s = (e['status'] ?? 'active').toString().toLowerCase();
        return s == 'active';
      }).length;

      double monthlyEst = 0.0;
      for (final e in empList) {
        final s = (e['status'] ?? 'active').toString().toLowerCase();
        if (s == 'active') {
          final salary = double.tryParse(
                  e['base_salary']?.toString() ?? e['salary']?.toString() ?? '0') ??
              0.0;
          monthlyEst += salary;
        }
      }

      final todayPunches = attList.where((a) {
        final punchDate = a['punch_date']?.toString() ?? '';
        return punchDate.startsWith(todayStr);
      }).toList();

      final presentIds = todayPunches.map((a) => a['employee_id']).toSet();
      final presentCount = presentIds.length;
      final onLeaveCount = leavesList.length;
      final absentCount =
          (activeEmp - presentCount) > 0 ? (activeEmp - presentCount) : 0;

      if (mounted) {
        setState(() {
          _hrmsEmployees = empList;
          _hrmsAttendanceToday = todayPunches;
          _hrmsLeavesPending = leavesList;
          _hrmsDesignations = desigList;
          _hrmsShifts = shiftsList;
          _hrmsTotalEmployees = totalEmp;
          _hrmsActiveEmployees = activeEmp;
          _hrmsPresentToday = presentCount;
          _hrmsOnLeaveToday = onLeaveCount;
          _hrmsAbsentToday = absentCount;
          _hrmsMonthlyPayrollEst = monthlyEst;
          _loadingHrmsData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading HRMS dashboard data: $e');
      if (mounted) {
        setState(() => _loadingHrmsData = false);
      }
    }
  }

  Widget _buildHrmsDashboard({required bool isWide}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHrmsHeroBanner(isWide, isDark, textPrimaryColor),
        const SizedBox(height: 16),
        _buildHrmsKpiGrid(isWide, isDark),
        const SizedBox(height: 16),
        _buildHrmsQuickHub(isWide, isDark),
        const SizedBox(height: 16),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildHrmsStaffDirectoryCard(isDark, textPrimaryColor, textSecondaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildHrmsWorkforceAnalyticsCard(isDark, textPrimaryColor, textSecondaryColor),
                    const SizedBox(height: 16),
                    _buildHrmsShiftsAndLeavesCard(isDark, textPrimaryColor, textSecondaryColor),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _buildHrmsStaffDirectoryCard(isDark, textPrimaryColor, textSecondaryColor),
          const SizedBox(height: 16),
          _buildHrmsWorkforceAnalyticsCard(isDark, textPrimaryColor, textSecondaryColor),
          const SizedBox(height: 16),
          _buildHrmsShiftsAndLeavesCard(isDark, textPrimaryColor, textSecondaryColor),
        ],
      ],
    );
  }

  Widget _buildHrmsHeroBanner(bool isWide, bool isDark, Color textPrimaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF2563EB)).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.badge_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Workforce & HRMS Command Center',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time employee tracking, daily attendance punches, leave management, and automated payroll operations.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (isWide)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.business_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        (user?.propertyName?.trim().isNotEmpty == true ? user!.propertyName! : 'Active Outlet'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmployeeScreen()),
                ).then((_) => _loadHrmsDashboardData()),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add Employee', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                ).then((_) => _loadHrmsDashboardData()),
                icon: const Icon(Icons.co_present_rounded, size: 18),
                label: const Text('Daily Attendance'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PayrollScreen()),
                ).then((_) => _loadHrmsDashboardData()),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Process Payroll'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HrmsMastersScreen()),
                ).then((_) => _loadHrmsDashboardData()),
                icon: const Icon(Icons.work_history_rounded, size: 18),
                label: const Text('Shifts & Masters'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CashLedgerScreen(businessModule: _businessModule),
                  ),
                ),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                label: const Text('Cash / Bank Ledger'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHrmsKpiGrid(bool isWide, bool isDark) {
    final kpis = [
      _HrmsMetricItem(
        title: 'Total Workforce',
        value: '$_hrmsTotalEmployees',
        subtitle: '$_hrmsActiveEmployees Active Staff',
        icon: Icons.groups_rounded,
        color: const Color(0xFF2563EB),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeScreen())).then((_) => _loadHrmsDashboardData()),
      ),
      _HrmsMetricItem(
        title: 'Present Today',
        value: '$_hrmsPresentToday',
        subtitle: _hrmsActiveEmployees > 0
            ? '${((_hrmsPresentToday / _hrmsActiveEmployees) * 100).toStringAsFixed(0)}% Clocked In'
            : '0% Clocked In',
        icon: Icons.how_to_reg_rounded,
        color: const Color(0xFF059669),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())).then((_) => _loadHrmsDashboardData()),
      ),
      _HrmsMetricItem(
        title: 'Absent / Off Today',
        value: '$_hrmsAbsentToday',
        subtitle: '$_hrmsOnLeaveToday On Approved Leave',
        icon: Icons.person_off_rounded,
        color: const Color(0xFFD97706),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())).then((_) => _loadHrmsDashboardData()),
      ),
      _HrmsMetricItem(
        title: 'Est. Monthly Payroll',
        value: _formatMoney(_hrmsMonthlyPayrollEst),
        subtitle: 'Base Salary Commitment',
        icon: Icons.monetization_on_rounded,
        color: const Color(0xFF7C3AED),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen())).then((_) => _loadHrmsDashboardData()),
      ),
      _HrmsMetricItem(
        title: 'Pending Leaves',
        value: '${_hrmsLeavesPending.length}',
        subtitle: 'Awaiting Authorization',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFE11D48),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())).then((_) => _loadHrmsDashboardData()),
      ),
    ];

    if (isWide) {
      return Row(
        children: kpis.map((kpi) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildHrmsMetricCard(kpi, isDark),
            ),
          );
        }).toList(),
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: kpis.map((kpi) {
          return SizedBox(
            width: 260,
            child: _buildHrmsMetricCard(kpi, isDark),
          );
        }).toList(),
      );
    }
  }

  Widget _buildHrmsMetricCard(_HrmsMetricItem m, bool isDark) {
    return InkWell(
      onTap: m.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(m.icon, color: m.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.value,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: m.color,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHrmsQuickHub(bool isWide, bool isDark) {
    final hubs = [
      _HrmsHubCardItem(
        title: 'Employee Directory',
        desc: 'Master directory of employee profiles, contracts, contact info & bank records.',
        icon: Icons.badge_outlined,
        color: const Color(0xFF2563EB),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeScreen())).then((_) => _loadHrmsDashboardData()),
      ),
      _HrmsHubCardItem(
        title: 'Attendance & Punch Clock',
        desc: 'Track daily clock-in/out records, shift schedules, overtime, and leave applications.',
        icon: Icons.fingerprint_rounded,
        color: const Color(0xFF059669),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())).then((_) => _loadHrmsDashboardData()),
      ),
      _HrmsHubCardItem(
        title: 'Payroll & Payslips',
        desc: 'Compute salaries, bonuses, deductions, loans, advances and print professional payslips.',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF7C3AED),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen())).then((_) => _loadHrmsDashboardData()),
      ),
      _HrmsHubCardItem(
        title: 'Cash / Bank Ledger (Finance)',
        desc: 'Manage company cash books, bank books, staff advances, and petty cash expenses.',
        icon: Icons.account_balance_rounded,
        color: const Color(0xFFD97706),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CashLedgerScreen(businessModule: _businessModule))),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 550 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: hubs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 105,
          ),
          itemBuilder: (context, index) {
            final h = hubs[index];
            return InkWell(
              onTap: h.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: h.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(h.icon, color: h.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              h.desc,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHrmsStaffDirectoryCard(bool isDark, Color textPrimaryColor, Color textSecondaryColor) {
    final staffToShow = _hrmsEmployees.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_outlined, size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'Workforce Directory & Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_hrmsEmployees.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmployeeScreen()),
                ).then((_) => _loadHrmsDashboardData()),
                child: const Text('Manage All ➜', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_hrmsEmployees.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    Icon(Icons.badge_outlined, size: 48, color: textSecondaryColor.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'No staff profiles registered yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add your workforce to begin tracking daily attendance and payroll.',
                      style: TextStyle(fontSize: 12, color: textSecondaryColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmployeeScreen()),
                      ).then((_) => _loadHrmsDashboardData()),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('Add First Employee'),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: staffToShow.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final emp = staffToShow[index];
                final name = (emp['full_name'] ?? emp['name'] ?? 'Staff Member').toString();
                final code = (emp['employee_code'] ?? '#EMP-${emp['id']}').toString();
                final desig = (emp['designation']?['name'] ?? emp['designation_name'] ?? 'Staff').toString();
                final shift = (emp['shift']?['name'] ?? 'General').toString();
                final isActive = (emp['status'] ?? 'active').toString().toLowerCase() == 'active';

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'E',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF059669).withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActive ? const Color(0xFF059669) : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      Text(code, style: TextStyle(fontSize: 11, color: textSecondaryColor)),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(fontSize: 10, color: textSecondaryColor)),
                      const SizedBox(width: 8),
                      Text(desig, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(fontSize: 10, color: textSecondaryColor)),
                      const SizedBox(width: 8),
                      Text(shift, style: TextStyle(fontSize: 11, color: textSecondaryColor)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmployeeScreen()),
                    ).then((_) => _loadHrmsDashboardData()),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHrmsWorkforceAnalyticsCard(bool isDark, Color textPrimaryColor, Color textSecondaryColor) {
    // Group employees by designation
    final Map<String, int> desigCounts = {};
    for (final emp in _hrmsEmployees) {
      final dName = (emp['designation']?['name'] ?? emp['designation_name'] ?? 'General Staff').toString();
      desigCounts[dName] = (desigCounts[dName] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline_rounded, size: 20, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Text(
                'Department & Role Breakdown',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (desigCounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No designations mapped', style: TextStyle(fontSize: 12, color: textSecondaryColor)),
              ),
            )
          else
            ...desigCounts.entries.map((entry) {
              final pct = _hrmsTotalEmployees > 0 ? (entry.value / _hrmsTotalEmployees) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimaryColor),
                        ),
                        Text(
                          '${entry.value} (${(pct * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHrmsShiftsAndLeavesCard(bool isDark, Color textPrimaryColor, Color textSecondaryColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 20, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Text(
                    "Shifts & Today's Attendance",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                ).then((_) => _loadHrmsDashboardData()),
                child: const Text('Open Register ➜', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_hrmsPresentToday out of $_hrmsActiveEmployees Active Clocked In',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                      Text(
                        '$_hrmsAbsentToday staff absent • $_hrmsOnLeaveToday approved leave',
                        style: TextStyle(fontSize: 11, color: textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_hrmsShifts.isNotEmpty) ...[
            Text(
              'Configured Shifts (${_hrmsShifts.length})',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimaryColor),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _hrmsShifts.map((s) {
                final sName = (s['name'] ?? 'Shift').toString();
                final start = (s['start_time'] ?? '').toString();
                final end = (s['end_time'] ?? '').toString();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    start.isNotEmpty ? '$sName ($start - $end)' : sName,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimaryColor),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ================= CLINIC DASHBOARD METHODS =================
  Future<void> _loadClinicDashboardData() async {
    if (!mounted) return;
    setState(() => _loadingClinicData = true);
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      // 1. Operating Status
      try {
        final resStatus = await ApiClient.get(ApiEndpoints.clinicOperatingStatus, silent: true);
        if (resStatus != null && resStatus['success'] == true && resStatus['data'] != null && mounted) {
          _isClinicClosedToday = resStatus['data']['clinic_closed_today'] == true;
          _clinicClosedReason = resStatus['data']['clinic_closed_reason'] ?? '';
        }
      } catch (_) {}

      // 2. Doctors
      try {
        final resDocs = await ApiClient.get(ApiEndpoints.clinicDoctors, silent: true);
        if (resDocs != null && resDocs['success'] == true && mounted) {
          _clinicDoctors = (resDocs['data'] is List) ? List<dynamic>.from(resDocs['data']) : [];
        }
      } catch (_) {}

      // 3. Today's Appointments & OPD Queue
      try {
        final resAppts = await ApiClient.get(
          ApiEndpoints.clinicAppointments,
          queryParams: {
            'from_date': todayStr,
            'to_date': todayStr,
            'date': todayStr,
          },
          silent: true,
        );
        if (resAppts != null && resAppts['success'] == true && mounted) {
          final rawList = (resAppts['data'] is List) ? List<dynamic>.from(resAppts['data']) : [];
          // Filter strictly to today's date so appointments from previous or future dates are not included
          _clinicAppointments = rawList.where((appt) {
            final apptDate = (appt['appointment_date'] ?? appt['date'] ?? '').toString().split('T')[0].trim();
            if (apptDate.isEmpty) return true;
            return apptDate == todayStr;
          }).toList();
        }
      } catch (_) {}

      // 4. Clinic Analytics
      try {
        final resAnalytics = await ApiClient.get(
          ApiEndpoints.clinicAnalytics,
          queryParams: {'from_date': todayStr, 'to_date': todayStr},
          silent: true,
        );
        if (resAnalytics != null && resAnalytics['success'] == true && mounted) {
          _clinicAnalytics = Map<String, dynamic>.from(resAnalytics['data'] ?? {});
        }
      } catch (_) {}

      // 5. Active Subscriptions / Therapy Packages
      try {
        final resSubs = await ApiClient.get(
          ApiEndpoints.clinicSubscriptions,
          queryParams: {'status': 'ACTIVE'},
          silent: true,
        );
        if (resSubs != null && resSubs['success'] == true && mounted) {
          _clinicSubscriptions = (resSubs['data'] is List) ? List<dynamic>.from(resSubs['data']) : [];
        }
      } catch (_) {}

      if (mounted) {
        int queue = 0;
        int consulted = 0;
        int waiting = 0;
        int pharmacyBilled = 0;
        double fees = 0.0;

        for (final appt in _clinicAppointments) {
          queue++;
          final status = (appt['status'] ?? '').toString().toUpperCase();
          if (status == 'VISITED' || status == 'COMPLETED') {
            consulted++;
          } else if (status != 'CANCELLED' && status != 'NO_SHOW') {
            waiting++;
          }
          final billingStatus = (appt['billing_status'] ?? appt['dispensing_status'] ?? '').toString().toUpperCase();
          if (billingStatus == 'BILLED') {
            pharmacyBilled++;
          }
          final fee = double.tryParse('${appt['consultation_fee'] ?? 0}') ?? 0;
          final payStatus = (appt['payment_status'] ?? appt['fee_status'] ?? '').toString().toUpperCase();
          final isPaid = payStatus == 'PAID' || appt['paid'] == true;
          if (isPaid) {
            fees += fee;
          }
        }

        final analyticsFees = double.tryParse('${_clinicAnalytics['total_consultation_fees'] ?? 0}') ?? 0;
        if (analyticsFees > fees) fees = analyticsFees;

        setState(() {
          _clinicTodayQueueCount = queue;
          _clinicConsultedCount = consulted;
          _clinicWaitingCount = waiting;
          _clinicPharmacyBilledCount = pharmacyBilled;
          _clinicTodayRevenue = fees;
          _clinicActiveTherapyCount = _clinicSubscriptions.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading clinic dashboard: $e');
    } finally {
      if (mounted) setState(() => _loadingClinicData = false);
    }
  }

  Future<void> _openToggleClinicClosedDialog() async {
    final willClose = !_isClinicClosedToday;
    final reasonCtrl = TextEditingController(text: willClose ? 'Clinic closed for administrative reasons' : '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              willClose ? Icons.do_not_disturb_on_rounded : Icons.check_circle_rounded,
              color: willClose ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            ),
            const SizedBox(width: 8),
            Text(willClose ? 'Mark Clinic Closed Today?' : 'Mark Clinic Open Today?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              willClose
                  ? 'Patients booking online will be notified that the clinic is not taking appointments today.'
                  : 'Clinic schedule and booking will be restored to active status.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            if (willClose) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notice / Reason for Closing',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willClose ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willClose ? 'Confirm Close' : 'Confirm Open'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.post(ApiEndpoints.clinicToggleClosedToday, {
          'closed': willClose,
          'reason': reasonCtrl.text.trim(),
        });
        if (res != null && res['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Clinic status updated!'),
              backgroundColor: willClose ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            ),
          );
          _loadClinicDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildClinicDashboard({required bool isWide}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClinicHeroBanner(isWide, isDark, textPrimaryColor),
        const SizedBox(height: 16),
        _buildClinicKpiGrid(isWide, isDark),
        const SizedBox(height: 16),
        _buildClinicQuickHub(isWide, isDark),
        const SizedBox(height: 16),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildClinicOpdQueueCard(isDark, textPrimaryColor, textSecondaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildClinicTherapyPackagesCard(isDark, textPrimaryColor, textSecondaryColor),
                    const SizedBox(height: 16),
                    _buildClinicDoctorsCard(isDark, textPrimaryColor, textSecondaryColor),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _buildClinicOpdQueueCard(isDark, textPrimaryColor, textSecondaryColor),
          const SizedBox(height: 16),
          _buildClinicTherapyPackagesCard(isDark, textPrimaryColor, textSecondaryColor),
          const SizedBox(height: 16),
          _buildClinicDoctorsCard(isDark, textPrimaryColor, textSecondaryColor),
        ],
      ],
    );
  }

  Widget _buildClinicHeroBanner(bool isWide, bool isDark, Color textPrimaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF0F766E)]
              : [const Color(0xFF047857), const Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF047857)).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clinic & Healthcare Operations Center',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live OPD patient queue, doctor consultations, e-prescriptions, pharmacy dispensing, and therapy care packages.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              if (isWide) ...[
                InkWell(
                  onTap: _openToggleClinicClosedDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isClinicClosedToday
                          ? Colors.red.shade900.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isClinicClosedToday ? Icons.cancel_rounded : Icons.check_circle_rounded,
                          color: _isClinicClosedToday ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isClinicClosedToday ? 'Clinic Closed Today' : 'Clinic Open Today',
                          style: TextStyle(
                            color: _isClinicClosedToday ? const Color(0xFFFCA5A5) : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.business_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        ((user?.propertyName ?? '').trim().isNotEmpty ? user!.propertyName! : 'Clinic Center'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (PermissionService.can('CLINIC_APPOINTMENTS'))
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF047857),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClinicDashboardScreen(
                        initialTab: ClinicTab.reception,
                        userRole: user?.role,
                        userPermissions: PermissionService.user?.permissions,
                        autoOpenBooking: true,
                      ),
                    ),
                  ).then((_) => _loadClinicDashboardData()),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              if (PermissionService.can('CLINIC_APPOINTMENTS'))
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClinicDashboardScreen(
                        initialTab: ClinicTab.reception,
                        userRole: user?.role,
                        userPermissions: PermissionService.user?.permissions,
                      ),
                    ),
                  ).then((_) => _loadClinicDashboardData()),
                  icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                  label: const Text('Reception Desk (OPD)'),
                ),
              if (PermissionService.can('DOCTOR_CONSULTATION|PRESCRIPTIONS'))
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClinicDashboardScreen(
                        initialTab: ClinicTab.doctor,
                        userRole: user?.role,
                        userPermissions: PermissionService.user?.permissions,
                      ),
                    ),
                  ).then((_) => _loadClinicDashboardData()),
                  icon: const Icon(Icons.medical_services_rounded, size: 18),
                  label: const Text('Doctor Consultation'),
                ),
              if (PermissionService.can('CLINIC_PHARMACY'))
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClinicDashboardScreen(
                        initialTab: ClinicTab.pharmacy,
                        userRole: user?.role,
                        userPermissions: PermissionService.user?.permissions,
                      ),
                    ),
                  ).then((_) => _loadClinicDashboardData()),
                  icon: const Icon(Icons.local_pharmacy_rounded, size: 18),
                  label: const Text('Pharmacy & Dispensing'),
                ),
              if (PermissionService.can('CLINIC_THERAPY'))
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClinicDashboardScreen(
                        initialTab: ClinicTab.therapy,
                        userRole: user?.role,
                        userPermissions: PermissionService.user?.permissions,
                      ),
                    ),
                  ).then((_) => _loadClinicDashboardData()),
                  icon: const Icon(Icons.spa_rounded, size: 18),
                  label: const Text('Therapy & Packages'),
                ),
              if (PermissionService.can('CLINIC_ANALYTICS'))
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClinicDashboardScreen(
                        initialTab: ClinicTab.analytics,
                        userRole: user?.role,
                        userPermissions: PermissionService.user?.permissions,
                      ),
                    ),
                  ).then((_) => _loadClinicDashboardData()),
                  icon: const Icon(Icons.analytics_rounded, size: 18),
                  label: const Text('Analytics & Intelligence'),
                ),
              if (PermissionService.can('NIGHT_AUDIT'))
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NightAuditScreen()),
                  ),
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                  label: const Text('Cash Handover (Day Audit)'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClinicKpiGrid(bool isWide, bool isDark) {
    final metrics = [
      _ClinicMetricItem(
        title: "Today OPD Queue",
        value: '$_clinicTodayQueueCount',
        subtitle: '$_clinicWaitingCount Waiting in Queue',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF0284C7),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClinicDashboardScreen(
              initialTab: ClinicTab.reception,
              userRole: user?.role,
            ),
          ),
        ).then((_) => _loadClinicDashboardData()),
      ),
      _ClinicMetricItem(
        title: "Consultations Done",
        value: '$_clinicConsultedCount',
        subtitle: 'Visited & Prescribed',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF059669),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClinicDashboardScreen(
              initialTab: ClinicTab.doctor,
              userRole: user?.role,
            ),
          ),
        ).then((_) => _loadClinicDashboardData()),
      ),
      _ClinicMetricItem(
        title: "Pharmacy Dispensed",
        value: '$_clinicPharmacyBilledCount',
        subtitle: 'Prescriptions Fulfilled',
        icon: Icons.medication_rounded,
        color: const Color(0xFFD97706),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClinicDashboardScreen(
              initialTab: ClinicTab.pharmacy,
              userRole: user?.role,
            ),
          ),
        ).then((_) => _loadClinicDashboardData()),
      ),
      _ClinicMetricItem(
        title: "Active Therapy Plans",
        value: '$_clinicActiveTherapyCount',
        subtitle: 'Care Courses Active',
        icon: Icons.spa_rounded,
        color: const Color(0xFF7C3AED),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClinicDashboardScreen(
              initialTab: ClinicTab.therapy,
              userRole: user?.role,
            ),
          ),
        ).then((_) => _loadClinicDashboardData()),
      ),
      _ClinicMetricItem(
        title: "OPD & Rx Collection",
        value: _formatMoney(_clinicTodayRevenue),
        subtitle: 'Today Fees Collected',
        icon: Icons.payments_rounded,
        color: const Color(0xFF0D9488),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClinicDashboardScreen(
              initialTab: ClinicTab.analytics,
              userRole: user?.role,
            ),
          ),
        ).then((_) => _loadClinicDashboardData()),
      ),
      _ClinicMetricItem(
        title: "Doctors On Duty",
        value: '${_clinicDoctors.length}',
        subtitle: 'Active Clinicians',
        icon: Icons.badge_rounded,
        color: const Color(0xFFE11D48),
        onTap: () => showDialog(
          context: context,
          builder: (_) => ClinicDoctorManagementDialog(
            onDoctorsChanged: _loadClinicDashboardData,
          ),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 6
            : constraints.maxWidth > 750
                ? 3
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 110,
          ),
          itemBuilder: (context, index) {
            final m = metrics[index];
            return InkWell(
              onTap: m.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          m.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: m.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(m.icon, color: m.color, size: 16),
                        ),
                      ],
                    ),
                    Text(
                      m.value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      m.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: m.color,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClinicQuickHub(bool isWide, bool isDark) {
    final hubs = [
      if (PermissionService.can('DOCTOR_CONSULTATION|PRESCRIPTIONS'))
        _ClinicHubCardItem(
          title: 'Doctor Consultation Desk',
          desc: 'Examine OPD queue, record symptoms, diagnoses & prescribe medicines',
          icon: Icons.medical_services_rounded,
          color: const Color(0xFF059669),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClinicDashboardScreen(
                initialTab: ClinicTab.doctor,
                userRole: user?.role,
                userPermissions: PermissionService.user?.permissions,
              ),
            ),
          ).then((_) => _loadClinicDashboardData()),
        ),
      if (PermissionService.can('CLINIC_APPOINTMENTS'))
        _ClinicHubCardItem(
          title: 'OPD Reception & Tokens',
          desc: 'Register walk-in patients, take vitals, collect fees & generate queue tokens',
          icon: Icons.how_to_reg_rounded,
          color: const Color(0xFF0284C7),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClinicDashboardScreen(
                initialTab: ClinicTab.reception,
                userRole: user?.role,
                userPermissions: PermissionService.user?.permissions,
              ),
            ),
          ).then((_) => _loadClinicDashboardData()),
        ),
      if (PermissionService.can('CLINIC_PHARMACY'))
        _ClinicHubCardItem(
          title: 'Pharmacy & Dispensing POS',
          desc: 'Dispense e-prescriptions, bill retail medicines, manage batches & shelf life',
          icon: Icons.local_pharmacy_rounded,
          color: const Color(0xFFD97706),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClinicDashboardScreen(
                initialTab: ClinicTab.pharmacy,
                userRole: user?.role,
                userPermissions: PermissionService.user?.permissions,
              ),
            ),
          ).then((_) => _loadClinicDashboardData()),
        ),
      if (PermissionService.can('CLINIC_THERAPY'))
        _ClinicHubCardItem(
          title: 'Therapy & Care Packages',
          desc: 'Manage sessions, track advance balances, view consumed ratios & deduct visits',
          icon: Icons.spa_rounded,
          color: const Color(0xFF7C3AED),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClinicDashboardScreen(
                initialTab: ClinicTab.therapy,
                userRole: user?.role,
                userPermissions: PermissionService.user?.permissions,
              ),
            ),
          ).then((_) => _loadClinicDashboardData()),
        ),
      if (PermissionService.can('ITEM_MASTER|CLINIC_PHARMACY'))
        _ClinicHubCardItem(
          title: 'Medicines & Lab Tests Master',
          desc: 'Maintain drug formulations, standard doses, test pricing & clinical catalog',
          icon: Icons.medication_liquid_rounded,
          color: const Color(0xFF0D9488),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ItemMasterScreen(isClinicMode: true)),
          ),
        ),
      if (PermissionService.can('CLINIC_ANALYTICS'))
        _ClinicHubCardItem(
          title: 'Operational Intelligence',
          desc: 'Demographics, attendance conversion rates, doctor workloads & top Rx drugs',
          icon: Icons.insights_rounded,
          color: const Color(0xFF2563EB),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClinicDashboardScreen(
                initialTab: ClinicTab.analytics,
                userRole: user?.role,
                userPermissions: PermissionService.user?.permissions,
              ),
            ),
          ).then((_) => _loadClinicDashboardData()),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 950 ? 3 : constraints.maxWidth > 600 ? 2 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: hubs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 88,
          ),
          itemBuilder: (context, index) {
            final h = hubs[index];
            return InkWell(
              onTap: h.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: h.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(h.icon, color: h.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            h.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            h.desc,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClinicOpdQueueCard(bool isDark, Color textPrimaryColor, Color textSecondaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: Color(0xFF059669), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Today's Live OPD Queue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_clinicAppointments.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Refresh Queue',
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: _loadClinicDashboardData,
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClinicDashboardScreen(
                          initialTab: ClinicTab.reception,
                          userRole: user?.role,
                        ),
                      ),
                    ).then((_) => _loadClinicDashboardData()),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingClinicData)
            const Padding(
              padding: EdgeInsets.all(28.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_clinicAppointments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 48,
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No patients in OPD queue today',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Book Appointment" above to register a patient walk-in.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _clinicAppointments.length > 8 ? 8 : _clinicAppointments.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final appt = _clinicAppointments[index];
                final patientName = (appt['patient_name'] ?? 'Patient').toString();
                final phone = (appt['patient_phone'] ?? appt['phone'] ?? '').toString();
                final doctorName = (appt['doctor_name'] ?? 'Doctor').toString();
                final time = (appt['appointment_time'] ?? '').toString();
                final token = (appt['token_number'] ?? (index + 1)).toString();
                final status = (appt['status'] ?? 'SCHEDULED').toString().toUpperCase();
                final fee = double.tryParse('${appt['consultation_fee'] ?? 0}') ?? 0;
                final payStatus = (appt['payment_status'] ?? appt['fee_status'] ?? 'UNPAID').toString().toUpperCase();
                final payMode = (appt['payment_mode'] ?? '').toString().toUpperCase();
                final isPack = appt['is_package_session'] == true || payStatus == 'PACKAGE_INCLUDED' || payMode == 'PACKAGE_SUBSCRIPTION';
                final isPaid = payStatus == 'PAID' || appt['paid'] == true;

                Color statusBg = const Color(0xFFF1F5F9);
                Color statusFg = const Color(0xFF475569);
                if (status == 'VISITED' || status == 'COMPLETED') {
                  statusBg = const Color(0xFFDCFCE7);
                  statusFg = const Color(0xFF15803D);
                } else if (status == 'WAITING' || status == 'WAITING IN QUEUE') {
                  statusBg = const Color(0xFFFEF3C7);
                  statusFg = const Color(0xFFB45309);
                } else if (status == 'CONFIRMED') {
                  statusBg = const Color(0xFFE0F2FE);
                  statusFg = const Color(0xFF0369A1);
                }

                Color feeBg = const Color(0xFFFEF2F2);
                Color feeFg = const Color(0xFFDC2626);
                String feeLabel = 'Due: ₹${fee.toStringAsFixed(0)}';
                if (isPaid) {
                  feeBg = const Color(0xFFDCFCE7);
                  feeFg = const Color(0xFF15803D);
                  feeLabel = payMode.isNotEmpty ? 'Paid: ₹${fee.toStringAsFixed(0)} ($payMode)' : 'Paid: ₹${fee.toStringAsFixed(0)}';
                } else if (isPack) {
                  feeBg = const Color(0xFFF3E8FF);
                  feeFg = const Color(0xFF7E22CE);
                  feeLabel = 'Therapy Plan';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '#$token',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patientName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textPrimaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dr. $doctorName • $phone ${time.isNotEmpty ? "• $time" : ""}',
                              style: TextStyle(fontSize: 11, color: textSecondaryColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: feeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          feeLabel,
                          style: TextStyle(color: feeFg, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(color: statusFg, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Doctor Consultation',
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClinicDashboardScreen(
                              initialTab: ClinicTab.doctor,
                              userRole: user?.role,
                            ),
                          ),
                        ).then((_) => _loadClinicDashboardData()),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildClinicTherapyPackagesCard(bool isDark, Color textPrimaryColor, Color textSecondaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.spa_rounded, color: Color(0xFF7C3AED), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Active Therapy Packages',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClinicDashboardScreen(
                      initialTab: ClinicTab.therapy,
                      userRole: user?.role,
                    ),
                  ),
                ).then((_) => _loadClinicDashboardData()),
                child: const Text('Manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_clinicSubscriptions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No active therapy packages found',
                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _clinicSubscriptions.length > 4 ? 4 : _clinicSubscriptions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final sub = _clinicSubscriptions[index];
                final custName = (sub['customer_name'] ?? sub['patient_name'] ?? 'Patient').toString();
                final phone = (sub['phone_number'] ?? sub['phone'] ?? '').toString();
                final planName = (sub['package_name'] ?? sub['product_name'] ?? sub['plan_name'] ?? 'Therapy Plan').toString();
                final total = int.tryParse('${sub['total_sessions'] ?? 0}') ?? 0;
                final consumed = int.tryParse('${sub['consumed_sessions'] ?? sub['sessions_consumed'] ?? 0}') ?? 0;
                final left = int.tryParse('${sub['sessions_left'] ?? (total - consumed)}') ?? 0;
                final progress = total > 0 ? (consumed / total).clamp(0.0, 1.0) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  custName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$planName • $phone',
                                  style: TextStyle(fontSize: 11, color: textSecondaryColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: left > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$left Left',
                              style: TextStyle(
                                color: left > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Consumed: $consumed of $total sessions',
                            style: TextStyle(fontSize: 10, color: textSecondaryColor),
                          ),
                          Text(
                            '${(progress * 100).toInt()}% Done',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildClinicDoctorsCard(bool isDark, Color textPrimaryColor, Color textSecondaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.badge_rounded, color: Color(0xFFE11D48), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Clinicians On Duty',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ClinicDoctorManagementDialog(
                    onDoctorsChanged: _loadClinicDashboardData,
                  ),
                ),
                child: const Text('Directory', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE11D48))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_clinicDoctors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No doctors configured yet. Click Directory to add.',
                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _clinicDoctors.length > 4 ? 4 : _clinicDoctors.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final doc = _clinicDoctors[index];
                final name = (doc['full_name'] ?? doc['name'] ?? 'Doctor').toString();
                final spec = (doc['specialty'] ?? doc['specialization'] ?? 'Physician').toString();
                final fee = double.tryParse('${doc['consultation_fee'] ?? 0}') ?? 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFE11D48).withValues(alpha: 0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'D',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textPrimaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              spec,
                              style: TextStyle(fontSize: 11, color: textSecondaryColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Fee: ₹${fee.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ================= MODELS =================
class _TxnDay {
  final String day;
  final double received;
  final double issued;
  _TxnDay(this.day, this.received, this.issued);
}

class _DeptIssue {
  final String dept;
  final double qty;
  _DeptIssue(this.dept, this.qty);
}

class _DamageDay {
  final String day;
  final double qty;
  _DamageDay(this.day, this.qty);
}

class _CategoryStock {
  final String category;
  final int percent;
  _CategoryStock(this.category, this.percent);
}

class _SupplierPayment {
  final String supplier;
  final double paid;
  final double unpaid;
  _SupplierPayment(this.supplier, this.paid, this.unpaid);
}

class _UnpaidSupplier {
  final String supplier;
  final double amount;
  _UnpaidSupplier(this.supplier, this.amount);
}

class _HeatmapZoneValue {
  final double qty;
  final double sales;

  _HeatmapZoneValue(this.qty, this.sales);

  factory _HeatmapZoneValue.fromJson(Map<String, dynamic> json) {
    return _HeatmapZoneValue(
      _safeDouble(json['qty']),
      _safeDouble(json['sales']),
    );
  }
}

class _HeatmapItem {
  final String itemName;
  final String itemCode;
  final String itemGroup;
  final String subCategory;
  final String brand;
  final double totalQty;
  final double totalSales;
  final Map<String, _HeatmapZoneValue> zones;

  _HeatmapItem({
    required this.itemName,
    required this.itemCode,
    required this.itemGroup,
    required this.subCategory,
    required this.brand,
    required this.totalQty,
    required this.totalSales,
    required this.zones,
  });

  factory _HeatmapItem.fromJson(Map<String, dynamic> json) {
    final zonesJson = Map<String, dynamic>.from(json['zones'] as Map? ?? {});
    final zones = <String, _HeatmapZoneValue>{};
    for (final entry in zonesJson.entries) {
      zones[entry.key] = _HeatmapZoneValue.fromJson(
        Map<String, dynamic>.from(entry.value as Map? ?? {}),
      );
    }
    return _HeatmapItem(
      itemName: json['item_name'] ?? '',
      itemCode: json['item_code'] ?? '',
      itemGroup: json['item_group'] ?? '',
      subCategory: json['sub_category'] ?? '',
      brand: json['brand'] ?? '',
      totalQty: _safeDouble(json['total_qty']),
      totalSales: _safeDouble(json['total_sales']),
      zones: zones,
    );
  }
}

class _GrowthComparison {
  final _PeriodTotals? current;
  final _PeriodTotals? previous;
  final double growthPercent;

  _GrowthComparison({
    required this.current,
    required this.previous,
    required this.growthPercent,
  });

  factory _GrowthComparison.fromJson(Map<String, dynamic> json) {
    return _GrowthComparison(
      current: json['current'] is Map
          ? _PeriodTotals.fromJson(Map<String, dynamic>.from(
              json['current'] as Map,
            ))
          : null,
      previous: json['previous'] is Map
          ? _PeriodTotals.fromJson(Map<String, dynamic>.from(
              json['previous'] as Map,
            ))
          : null,
      growthPercent: _safeDouble(json['growth_percent']),
    );
  }
}

class _TransactionTypeSummary {
  final String transactionType;
  final String transactionLabel;
  final double credited;
  final double debited;
  final double net;
  final int count;

  _TransactionTypeSummary({
    required this.transactionType,
    required this.transactionLabel,
    required this.credited,
    required this.debited,
    required this.net,
    required this.count,
  });

  factory _TransactionTypeSummary.fromJson(Map<String, dynamic> json) {
    return _TransactionTypeSummary(
      transactionType: json['transaction_type'] ?? '',
      transactionLabel: json['transaction_label'] ?? '',
      credited: _safeDouble(json['credited']),
      debited: _safeDouble(json['debited']),
      net: _safeDouble(json['net']),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class _PeriodTotals {
  final double sales;
  final double profit;
  final double loss;

  _PeriodTotals({
    required this.sales,
    required this.profit,
    required this.loss,
  });

  factory _PeriodTotals.fromJson(Map<String, dynamic> json) {
    return _PeriodTotals(
      sales: _safeDouble(json['sales']),
      profit: _safeDouble(json['profit']),
      loss: _safeDouble(json['loss']),
    );
  }
}

class _PeriodPoint {
  final String label;
  final double value;
  _PeriodPoint(this.label, this.value);
}

double _safeDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class _HrmsMetricItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _HrmsMetricItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _HrmsHubCardItem {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _HrmsHubCardItem({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _ClinicMetricItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ClinicMetricItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _ClinicHubCardItem {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ClinicHubCardItem({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
