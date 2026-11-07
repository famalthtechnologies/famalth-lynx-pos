import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/currency/currency_service.dart';
import '../../core/config/app_brand.dart';

class ReceiptTemplateDesignerScreen extends StatefulWidget {
  const ReceiptTemplateDesignerScreen({super.key});

  @override
  State<ReceiptTemplateDesignerScreen> createState() => _ReceiptTemplateDesignerScreenState();
}

class _ReceiptTemplateDesignerScreenState extends State<ReceiptTemplateDesignerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const Color primaryColor = Color(0xFF0B5CAD);

  // Auto-sync toggle across formats
  bool _autoSyncSharedDetails = true;

  // =========================================================================
  // 1. 80mm / Thermal Bill Template Controllers & Toggles
  // =========================================================================
  final _billPhoneCtrl = TextEditingController();
  final _billEmailCtrl = TextEditingController();
  final _billWebsiteCtrl = TextEditingController();
  bool _billShowWebsite = true;
  final _billInvoiceTitleCtrl = TextEditingController(text: 'TAX INVOICE');
  final _billHeaderTitleCtrl = TextEditingController();
  final _billHeaderSubtextCtrl = TextEditingController();
  final _billFooterNoteCtrl = TextEditingController();
  final _billTaxRegNoCtrl = TextEditingController();
  final _billTermsCtrl = TextEditingController();
  final _billResellerFooterCtrl = TextEditingController();
  final _billBankNameCtrl = TextEditingController();
  final _billBankAccountNoCtrl = TextEditingController();
  final _billBankIfscCtrl = TextEditingController();
  final _billUpiIdCtrl = TextEditingController();
  final _billUpiPayeeNameCtrl = TextEditingController();
  final _billFssaiCtrl = TextEditingController();
  final _billDrugLicenseCtrl = TextEditingController();

  bool _billShowLogo = true;
  bool _billShowAddress = true;
  bool _billShowPhone = true;
  bool _billShowEmail = true;
  bool _billShowCustomer = true;
  bool _billShowCashier = true;
  bool _billShowToken = true;
  bool _billShowBrand = true;
  bool _billShowHsnCode = true;
  bool _billShowDiscounts = true;
  bool _billShowTaxBreakup = true;
  bool _billShowBankDetails = true;
  bool _billShowUpiQr = true;
  bool _billShowResellerFooter = true;
  bool _billShowCurrency = true;
  bool _billShowFssai = true;
  bool _billShowDrugLicense = true;
  String _billFontSize = 'MEDIUM'; // SMALL, MEDIUM, LARGE
  String _billThermalWidth = '80mm'; // 80mm, 76mm, 58mm
  String _selectedBillFormat = 'A4'; // THERMAL_80, A4, A5

  // =========================================================================
  // 2. A4 Full Invoice Template Controllers & Toggles
  // =========================================================================
  final _a4InvoiceTitleCtrl = TextEditingController(text: 'TAX INVOICE');
  final _a4HeaderTitleCtrl = TextEditingController();
  final _a4HeaderSubtextCtrl = TextEditingController();
  final _a4TaxRegNoCtrl = TextEditingController();
  final _a4PanNoCtrl = TextEditingController();
  final _a4FooterNoteCtrl = TextEditingController();
  final _a4TermsCtrl = TextEditingController();
  final _a4BankNameCtrl = TextEditingController();
  final _a4BankAccountNoCtrl = TextEditingController();
  final _a4BankIfscCtrl = TextEditingController();
  final _a4MpesaPaybillCtrl = TextEditingController();
  final _a4SignatoryLabelCtrl = TextEditingController();
  final _a4PhoneCtrl = TextEditingController();
  final _a4EmailCtrl = TextEditingController();
  final _a4WebsiteCtrl = TextEditingController();
  final _a4ResellerFooterCtrl = TextEditingController();
  final _a4FssaiCtrl = TextEditingController();
  final _a4DrugLicenseCtrl = TextEditingController();

  bool _a4ShowLogo = true;
  bool _a4ShowPhone = true;
  bool _a4ShowEmail = true;
  bool _a4ShowWebsite = true;
  bool _a4ShowCompanyAddress = true;
  bool _a4ShowCompanyContact = true;
  bool _a4ShowTaxReg = true;
  bool _a4ShowBuyerDetails = true;
  bool _a4ShowShippingDetails = true;
  bool _a4ShowHsnCode = true;
  bool _a4ShowBrand = true;
  bool _a4ShowItemDiscount = true;
  bool _a4ShowTaxBreakup = true;
  bool _a4ShowAmountInWords = true;
  bool _a4ShowBankDetails = true;
  bool _a4ShowQrCode = true;
  bool _a4ShowTermsAndConditions = true;
  bool _a4ShowSignatureBox = true;
  bool _a4ShowCurrency = true;
  bool _a4ShowPaymentMode = true;
  bool _a4ShowPlaceOfSupply = true;
  bool _a4ShowCashier = true;
  bool _a4ShowResellerFooter = true;
  bool _a4ShowFssai = true;
  bool _a4ShowDrugLicense = true;
  String _a4ThemeColor = 'BLUE'; // BLUE, SLATE, EMERALD, CRIMSON
  String _a4FontSize = 'MEDIUM'; // SMALL, MEDIUM, LARGE

  // =========================================================================
  // 3. A5 Half-Sheet Invoice Template Controllers & Toggles
  // =========================================================================
  final _a5InvoiceTitleCtrl = TextEditingController(text: 'TAX INVOICE');
  final _a5HeaderTitleCtrl = TextEditingController();
  final _a5HeaderSubtextCtrl = TextEditingController();
  final _a5TaxRegNoCtrl = TextEditingController();
  final _a5PanNoCtrl = TextEditingController();
  final _a5FooterNoteCtrl = TextEditingController();
  final _a5TermsCtrl = TextEditingController();
  final _a5BankNameCtrl = TextEditingController();
  final _a5BankAccountNoCtrl = TextEditingController();
  final _a5BankIfscCtrl = TextEditingController();
  final _a5MpesaPaybillCtrl = TextEditingController();
  final _a5SignatoryLabelCtrl = TextEditingController();
  final _a5PhoneCtrl = TextEditingController();
  final _a5EmailCtrl = TextEditingController();
  final _a5WebsiteCtrl = TextEditingController();
  final _a5ResellerFooterCtrl = TextEditingController();
  final _a5FssaiCtrl = TextEditingController();
  final _a5DrugLicenseCtrl = TextEditingController();

  bool _a5ShowLogo = true;
  bool _a5ShowPhone = true;
  bool _a5ShowEmail = true;
  bool _a5ShowWebsite = true;
  bool _a5ShowCompanyAddress = true;
  bool _a5ShowCompanyContact = true;
  bool _a5ShowTaxReg = true;
  bool _a5ShowBuyerDetails = true;
  bool _a5ShowShippingDetails = true;
  bool _a5ShowHsnCode = true;
  bool _a5ShowBrand = true;
  bool _a5ShowItemDiscount = true;
  bool _a5ShowTaxBreakup = true;
  bool _a5ShowAmountInWords = true;
  bool _a5ShowBankDetails = true;
  bool _a5ShowQrCode = true;
  bool _a5ShowTermsAndConditions = true;
  bool _a5ShowSignatureBox = true;
  bool _a5ShowCurrency = true;
  bool _a5ShowPaymentMode = true;
  bool _a5ShowPlaceOfSupply = true;
  bool _a5ShowCashier = true;
  bool _a5ShowResellerFooter = true;
  bool _a5ShowFssai = true;
  bool _a5ShowDrugLicense = true;
  String _a5ThemeColor = 'BLUE'; // BLUE, SLATE, EMERALD, CRIMSON
  String _a5FontSize = 'MEDIUM'; // SMALL, MEDIUM, LARGE

  // =========================================================================
  // 4. KOT Kitchen Ticket Template Controllers & Toggles
  // =========================================================================
  final _kotHeaderTitleCtrl = TextEditingController(text: 'KITCHEN ORDER TICKET');
  final _kotFooterNoteCtrl = TextEditingController();

  bool _kotShowStation = true;
  bool _kotShowTable = true;
  bool _kotShowGuests = true;
  bool _kotShowWaiter = true;
  bool _kotShowTimestamp = true;
  bool _kotShowNotes = true;
  bool _kotShowBrand = true;
  bool _kotShowCutLine = true;
  String _kotFontSize = 'MEDIUM'; // SMALL, MEDIUM, LARGE

  // =========================================================================
  // 4. Token Ticket Template Controllers & Toggles (Tab 4)
  // =========================================================================
  final _tokenHeaderTitleCtrl = TextEditingController(text: 'ORDER TOKEN / QUEUE SLIP');
  final _tokenHeaderSubtextCtrl = TextEditingController();
  final _tokenFooterNoteCtrl = TextEditingController(text: 'Please wait for your token number to be called.');
  final _tokenCounterLabelCtrl = TextEditingController(text: 'COUNTER #1 - PICKUP BAY');

  bool _tokenShowStoreName = true;
  bool _tokenShowBigNumber = true;
  bool _tokenShowOrderNo = true;
  bool _tokenShowTimestamp = true;
  bool _tokenShowCounter = true;
  bool _tokenShowCustomer = true;
  bool _tokenShowItemsSummary = true;
  bool _tokenShowItemCount = true;
  bool _tokenShowBarcode = true;
  bool _tokenShowCutLine = true;
  String _tokenBadgeStyle = 'INVERTED_BOX'; // INVERTED_BOX, BORDER_BOX, CIRCLE, MINIMAL
  String _tokenFontSize = 'MEDIUM'; // SMALL, MEDIUM, LARGE
  String _tokenThermalWidth = '80mm'; // 80mm, 58mm

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    Future.microtask(() => _loadSettings());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _billInvoiceTitleCtrl.dispose();
    _billBankNameCtrl.dispose();
    _billBankAccountNoCtrl.dispose();
    _billBankIfscCtrl.dispose();
    _billUpiIdCtrl.dispose();
    _billUpiPayeeNameCtrl.dispose();
    _a4InvoiceTitleCtrl.dispose();
    _a5InvoiceTitleCtrl.dispose();
    _billHeaderTitleCtrl.dispose();
    _billHeaderSubtextCtrl.dispose();
    _billFooterNoteCtrl.dispose();
    _billTaxRegNoCtrl.dispose();
    _billTermsCtrl.dispose();
    _billResellerFooterCtrl.dispose();
    _billPhoneCtrl.dispose();
    _billEmailCtrl.dispose();
    _billWebsiteCtrl.dispose();
    _a4PhoneCtrl.dispose();
    _a4EmailCtrl.dispose();
    _a4WebsiteCtrl.dispose();
    _a4ResellerFooterCtrl.dispose();
    _billFssaiCtrl.dispose();
    _billDrugLicenseCtrl.dispose();
    _a4FssaiCtrl.dispose();
    _a4DrugLicenseCtrl.dispose();
    _a5FssaiCtrl.dispose();
    _a5DrugLicenseCtrl.dispose();
    _a5PhoneCtrl.dispose();
    _a5EmailCtrl.dispose();
    _a5WebsiteCtrl.dispose();
    _a5ResellerFooterCtrl.dispose();

    _a4HeaderTitleCtrl.dispose();
    _a4HeaderSubtextCtrl.dispose();
    _a4TaxRegNoCtrl.dispose();
    _a4PanNoCtrl.dispose();
    _a4FooterNoteCtrl.dispose();
    _a4TermsCtrl.dispose();
    _a4BankNameCtrl.dispose();
    _a4BankAccountNoCtrl.dispose();
    _a4BankIfscCtrl.dispose();
    _a4MpesaPaybillCtrl.dispose();
    _a4SignatoryLabelCtrl.dispose();

        _a5HeaderTitleCtrl.dispose();
    _a5HeaderSubtextCtrl.dispose();
    _a5TaxRegNoCtrl.dispose();
    _a5PanNoCtrl.dispose();
    _a5FooterNoteCtrl.dispose();
    _a5TermsCtrl.dispose();
    _a5BankNameCtrl.dispose();
    _a5BankAccountNoCtrl.dispose();
    _a5BankIfscCtrl.dispose();
    _a5MpesaPaybillCtrl.dispose();
    _a5SignatoryLabelCtrl.dispose();
    _kotHeaderTitleCtrl.dispose();
    _kotFooterNoteCtrl.dispose();

    _tokenHeaderTitleCtrl.dispose();
    _tokenHeaderSubtextCtrl.dispose();
    _tokenFooterNoteCtrl.dispose();
    _tokenCounterLabelCtrl.dispose();
    super.dispose();
  }

  String _getCountryTaxLabel([dynamic prop]) {
    final stateOrCountry = (prop?.state ?? '').trim().toLowerCase();
    if (stateOrCountry == 'kenya' || CurrencyService.code == 'KES') return 'KRA PIN';
    if (stateOrCountry == 'uae' || CurrencyService.code == 'AED') return 'TRN';
    if (stateOrCountry == 'uk' || CurrencyService.symbol == '£') return 'VAT Reg No';
    if (CurrencyService.symbol == '₹' || CurrencyService.code == 'INR') return 'GSTIN';
    return 'Tax ID';
  }


  // =========================================================================
  // Auto-Sync Helpers Across Formats (80mm ⟷ A4 ⟷ A5)
  // =========================================================================
  void _syncText(String fieldKey, String value, {required String from}) {
    if (!_autoSyncSharedDetails) return;
    switch (fieldKey) {
      case 'store_title':
        if (from != '80mm') _billHeaderTitleCtrl.text = value;
        if (from != 'A4') _a4HeaderTitleCtrl.text = value;
        if (from != 'A5') _a5HeaderTitleCtrl.text = value;
        break;
      case 'address':
        if (from != '80mm') _billHeaderSubtextCtrl.text = value;
        if (from != 'A4') _a4HeaderSubtextCtrl.text = value;
        if (from != 'A5') _a5HeaderSubtextCtrl.text = value;
        break;
      case 'phone':
        if (from != '80mm') _billPhoneCtrl.text = value;
        if (from != 'A4') _a4PhoneCtrl.text = value;
        if (from != 'A5') _a5PhoneCtrl.text = value;
        break;
      case 'email':
        if (from != '80mm') _billEmailCtrl.text = value;
        if (from != 'A4') _a4EmailCtrl.text = value;
        if (from != 'A5') _a5EmailCtrl.text = value;
        break;
      case 'website':
        if (from != '80mm') _billWebsiteCtrl.text = value;
        if (from != 'A4') _a4WebsiteCtrl.text = value;
        if (from != 'A5') _a5WebsiteCtrl.text = value;
        break;
      case 'tax_reg':
        if (from != '80mm') _billTaxRegNoCtrl.text = value;
        if (from != 'A4') _a4TaxRegNoCtrl.text = value;
        if (from != 'A5') _a5TaxRegNoCtrl.text = value;
        break;
      case 'pan_no':
        if (from != 'A4') _a4PanNoCtrl.text = value;
        if (from != 'A5') _a5PanNoCtrl.text = value;
        break;
      case 'doc_title':
        if (from != '80mm') _billInvoiceTitleCtrl.text = value;
        if (from != 'A4') _a4InvoiceTitleCtrl.text = value;
        if (from != 'A5') _a5InvoiceTitleCtrl.text = value;
        break;
      case 'footer_note':
        if (from != '80mm') _billFooterNoteCtrl.text = value;
        if (from != 'A4') _a4FooterNoteCtrl.text = value;
        if (from != 'A5') _a5FooterNoteCtrl.text = value;
        break;
      case 'terms':
        if (from != '80mm') _billTermsCtrl.text = value;
        if (from != 'A4') _a4TermsCtrl.text = value;
        if (from != 'A5') _a5TermsCtrl.text = value;
        break;
      case 'bank_name':
        if (from != '80mm') _billBankNameCtrl.text = value;
        if (from != 'A4') _a4BankNameCtrl.text = value;
        if (from != 'A5') _a5BankNameCtrl.text = value;
        break;
      case 'bank_acc':
        if (from != '80mm') _billBankAccountNoCtrl.text = value;
        if (from != 'A4') _a4BankAccountNoCtrl.text = value;
        if (from != 'A5') _a5BankAccountNoCtrl.text = value;
        break;
      case 'bank_ifsc':
        if (from != '80mm') _billBankIfscCtrl.text = value;
        if (from != 'A4') _a4BankIfscCtrl.text = value;
        if (from != 'A5') _a5BankIfscCtrl.text = value;
        break;
      case 'mpesa':
        if (from != '80mm') _billUpiIdCtrl.text = value;
        if (from != 'A4') _a4MpesaPaybillCtrl.text = value;
        if (from != 'A5') _a5MpesaPaybillCtrl.text = value;
        break;
      case 'reseller_footer':
        if (from != '80mm') _billResellerFooterCtrl.text = value;
        if (from != 'A4' && from != 'a4') _a4ResellerFooterCtrl.text = value;
        if (from != 'A5' && from != 'a5') _a5ResellerFooterCtrl.text = value;
        break;
      case 'fssai':
        if (from != '80mm') _billFssaiCtrl.text = value;
        if (from != 'A4' && from != 'a4') _a4FssaiCtrl.text = value;
        if (from != 'A5' && from != 'a5') _a5FssaiCtrl.text = value;
        break;
      case 'drug_license':
        if (from != '80mm') _billDrugLicenseCtrl.text = value;
        if (from != 'A4' && from != 'a4') _a4DrugLicenseCtrl.text = value;
        if (from != 'A5' && from != 'a5') _a5DrugLicenseCtrl.text = value;
        break;
    }
  }

  void _syncToggle(String toggleKey, bool value, {required String from}) {
    if (!_autoSyncSharedDetails) return;
    switch (toggleKey) {
      case 'show_logo':
        _billShowLogo = value;
        _a4ShowLogo = value;
        _a5ShowLogo = value;
        break;
      case 'show_address':
        _billShowAddress = value;
        _a4ShowCompanyAddress = value;
        _a5ShowCompanyAddress = value;
        break;
      case 'show_phone':
        _billShowPhone = value;
        _a4ShowPhone = value;
        _a5ShowPhone = value;
        _a4ShowCompanyContact = value || _a4ShowEmail || _a4ShowWebsite;
        _a5ShowCompanyContact = value || _a5ShowEmail || _a5ShowWebsite;
        break;
      case 'show_email':
        _billShowEmail = value;
        _a4ShowEmail = value;
        _a5ShowEmail = value;
        _a4ShowCompanyContact = _a4ShowPhone || value || _a4ShowWebsite;
        _a5ShowCompanyContact = _a5ShowPhone || value || _a5ShowWebsite;
        break;
      case 'show_website':
        _billShowWebsite = value;
        _a4ShowWebsite = value;
        _a5ShowWebsite = value;
        break;
      case 'show_tax_reg':
        _a4ShowTaxReg = value;
        _a5ShowTaxReg = value;
        break;
      case 'show_brand':
        _billShowBrand = value;
        _a4ShowBrand = value;
        _a5ShowBrand = value;
        break;
      case 'show_hsn_code':
        _billShowHsnCode = value;
        _a4ShowHsnCode = value;
        _a5ShowHsnCode = value;
        break;
      case 'show_discounts':
        _billShowDiscounts = value;
        _a4ShowItemDiscount = value;
        _a5ShowItemDiscount = value;
        break;
      case 'show_tax_breakup':
        _billShowTaxBreakup = value;
        _a4ShowTaxBreakup = value;
        _a5ShowTaxBreakup = value;
        break;
      case 'show_bank_details':
        _billShowBankDetails = value;
        _a4ShowBankDetails = value;
        _a5ShowBankDetails = value;
        break;
      case 'show_currency':
        _billShowCurrency = value;
        _a4ShowCurrency = value;
        _a5ShowCurrency = value;
        break;
      case 'show_terms':
        _a4ShowTermsAndConditions = value;
        _a5ShowTermsAndConditions = value;
        break;
      case 'show_payment_mode':
        _a4ShowPaymentMode = value;
        _a5ShowPaymentMode = value;
        break;
      case 'show_place_of_supply':
        _a4ShowPlaceOfSupply = value;
        _a5ShowPlaceOfSupply = value;
        break;
      case 'show_cashier':
        _billShowCashier = value;
        _a4ShowCashier = value;
        _a5ShowCashier = value;
        break;
      case 'show_reseller_footer':
        _billShowResellerFooter = value;
        _a4ShowResellerFooter = value;
        _a5ShowResellerFooter = value;
        break;
      case 'show_fssai':
        _billShowFssai = value;
        _a4ShowFssai = value;
        _a5ShowFssai = value;
        break;
      case 'show_drug_license':
        _billShowDrugLicense = value;
        _a4ShowDrugLicense = value;
        _a5ShowDrugLicense = value;
        break;
    }
  }

  void _syncAllFromActiveFormat() {
    final int tab = _tabController.index;
    if (tab == 0) {
      // From 80mm to A4 & A5
      _a4HeaderTitleCtrl.text = _billHeaderTitleCtrl.text;
      _a5HeaderTitleCtrl.text = _billHeaderTitleCtrl.text;
      _a4HeaderSubtextCtrl.text = _billHeaderSubtextCtrl.text;
      _a5HeaderSubtextCtrl.text = _billHeaderSubtextCtrl.text;
      _a4PhoneCtrl.text = _billPhoneCtrl.text;
      _a5PhoneCtrl.text = _billPhoneCtrl.text;
      _a4EmailCtrl.text = _billEmailCtrl.text;
      _a5EmailCtrl.text = _billEmailCtrl.text;
      _a4WebsiteCtrl.text = _billWebsiteCtrl.text;
      _a5WebsiteCtrl.text = _billWebsiteCtrl.text;
      _a4TaxRegNoCtrl.text = _billTaxRegNoCtrl.text;
      _a5TaxRegNoCtrl.text = _billTaxRegNoCtrl.text;
      _a4InvoiceTitleCtrl.text = _billInvoiceTitleCtrl.text;
      _a5InvoiceTitleCtrl.text = _billInvoiceTitleCtrl.text;
      _a4FooterNoteCtrl.text = _billFooterNoteCtrl.text;
      _a5FooterNoteCtrl.text = _billFooterNoteCtrl.text;
      _a4TermsCtrl.text = _billTermsCtrl.text;
      _a5TermsCtrl.text = _billTermsCtrl.text;
      _a4BankNameCtrl.text = _billBankNameCtrl.text;
      _a5BankNameCtrl.text = _billBankNameCtrl.text;
      _a4BankAccountNoCtrl.text = _billBankAccountNoCtrl.text;
      _a5BankAccountNoCtrl.text = _billBankAccountNoCtrl.text;
      _a4BankIfscCtrl.text = _billBankIfscCtrl.text;
      _a5BankIfscCtrl.text = _billBankIfscCtrl.text;

      _a4ShowLogo = _billShowLogo;
      _a5ShowLogo = _billShowLogo;
      _a4ShowCompanyAddress = _billShowAddress;
      _a5ShowCompanyAddress = _billShowAddress;
      _a4ShowPhone = _billShowPhone;
      _a5ShowPhone = _billShowPhone;
      _a4ShowEmail = _billShowEmail;
      _a5ShowEmail = _billShowEmail;
      _a4ShowWebsite = _billShowWebsite;
      _a5ShowWebsite = _billShowWebsite;
      _a4ShowBrand = _billShowBrand;
      _a5ShowBrand = _billShowBrand;
      _a4ShowHsnCode = _billShowHsnCode;
      _a5ShowHsnCode = _billShowHsnCode;
      _a4ShowItemDiscount = _billShowDiscounts;
      _a5ShowItemDiscount = _billShowDiscounts;
      _a4ShowTaxBreakup = _billShowTaxBreakup;
      _a5ShowTaxBreakup = _billShowTaxBreakup;
      _a4ShowBankDetails = _billShowBankDetails;
      _a5ShowBankDetails = _billShowBankDetails;
      _a4ShowCurrency = _billShowCurrency;
      _a5ShowCurrency = _billShowCurrency;
      _a4ShowCashier = _billShowCashier;
      _a5ShowCashier = _billShowCashier;
      _a4ResellerFooterCtrl.text = _billResellerFooterCtrl.text;
      _a5ResellerFooterCtrl.text = _billResellerFooterCtrl.text;
      _a4ShowResellerFooter = _billShowResellerFooter;
      _a5ShowResellerFooter = _billShowResellerFooter;
      _a4FssaiCtrl.text = _billFssaiCtrl.text;
      _a5FssaiCtrl.text = _billFssaiCtrl.text;
      _a4DrugLicenseCtrl.text = _billDrugLicenseCtrl.text;
      _a5DrugLicenseCtrl.text = _billDrugLicenseCtrl.text;
      _a4ShowFssai = _billShowFssai;
      _a5ShowFssai = _billShowFssai;
      _a4ShowDrugLicense = _billShowDrugLicense;
      _a5ShowDrugLicense = _billShowDrugLicense;
    } else if (tab == 1) {
      // From A4 to 80mm & A5
      _billHeaderTitleCtrl.text = _a4HeaderTitleCtrl.text;
      _a5HeaderTitleCtrl.text = _a4HeaderTitleCtrl.text;
      _billHeaderSubtextCtrl.text = _a4HeaderSubtextCtrl.text;
      _a5HeaderSubtextCtrl.text = _a4HeaderSubtextCtrl.text;
      _billPhoneCtrl.text = _a4PhoneCtrl.text;
      _a5PhoneCtrl.text = _a4PhoneCtrl.text;
      _billEmailCtrl.text = _a4EmailCtrl.text;
      _a5EmailCtrl.text = _a4EmailCtrl.text;
      _billWebsiteCtrl.text = _a4WebsiteCtrl.text;
      _a5WebsiteCtrl.text = _a4WebsiteCtrl.text;
      _billTaxRegNoCtrl.text = _a4TaxRegNoCtrl.text;
      _a5TaxRegNoCtrl.text = _a4TaxRegNoCtrl.text;
      _billInvoiceTitleCtrl.text = _a4InvoiceTitleCtrl.text;
      _a5InvoiceTitleCtrl.text = _a4InvoiceTitleCtrl.text;
      _billFooterNoteCtrl.text = _a4FooterNoteCtrl.text;
      _a5FooterNoteCtrl.text = _a4FooterNoteCtrl.text;
      _billTermsCtrl.text = _a4TermsCtrl.text;
      _a5TermsCtrl.text = _a4TermsCtrl.text;
      _billBankNameCtrl.text = _a4BankNameCtrl.text;
      _a5BankNameCtrl.text = _a4BankNameCtrl.text;
      _billBankAccountNoCtrl.text = _a4BankAccountNoCtrl.text;
      _a5BankAccountNoCtrl.text = _a4BankAccountNoCtrl.text;
      _billBankIfscCtrl.text = _a4BankIfscCtrl.text;
      _a5BankIfscCtrl.text = _a4BankIfscCtrl.text;

      _billShowLogo = _a4ShowLogo;
      _a5ShowLogo = _a4ShowLogo;
      _billShowAddress = _a4ShowCompanyAddress;
      _a5ShowCompanyAddress = _a4ShowCompanyAddress;
      _billShowPhone = _a4ShowPhone;
      _a5ShowPhone = _a4ShowPhone;
      _billShowEmail = _a4ShowEmail;
      _a5ShowEmail = _a4ShowEmail;
      _billShowWebsite = _a4ShowWebsite;
      _a5ShowWebsite = _a4ShowWebsite;
      _billShowBrand = _a4ShowBrand;
      _a5ShowBrand = _a4ShowBrand;
      _billShowHsnCode = _a4ShowHsnCode;
      _a5ShowHsnCode = _a4ShowHsnCode;
      _billShowDiscounts = _a4ShowItemDiscount;
      _a5ShowItemDiscount = _a4ShowItemDiscount;
      _billShowTaxBreakup = _a4ShowTaxBreakup;
      _a5ShowTaxBreakup = _a4ShowTaxBreakup;
      _billShowBankDetails = _a4ShowBankDetails;
      _a5ShowBankDetails = _a4ShowBankDetails;
      _billShowCurrency = _a4ShowCurrency;
      _a5ShowCurrency = _a4ShowCurrency;
      _billShowCashier = _a4ShowCashier;
      _a5ShowCashier = _a4ShowCashier;
      _a5ShowPaymentMode = _a4ShowPaymentMode;
      _a5ShowPlaceOfSupply = _a4ShowPlaceOfSupply;
      _billResellerFooterCtrl.text = _a4ResellerFooterCtrl.text;
      _a5ResellerFooterCtrl.text = _a4ResellerFooterCtrl.text;
      _billShowResellerFooter = _a4ShowResellerFooter;
      _a5ShowResellerFooter = _a4ShowResellerFooter;
      _billFssaiCtrl.text = _a4FssaiCtrl.text;
      _a5FssaiCtrl.text = _a4FssaiCtrl.text;
      _billDrugLicenseCtrl.text = _a4DrugLicenseCtrl.text;
      _a5DrugLicenseCtrl.text = _a4DrugLicenseCtrl.text;
      _billShowFssai = _a4ShowFssai;
      _a5ShowFssai = _a4ShowFssai;
      _billShowDrugLicense = _a4ShowDrugLicense;
      _a5ShowDrugLicense = _a4ShowDrugLicense;
    } else if (tab == 2) {
      // From A5 to 80mm & A4
      _billHeaderTitleCtrl.text = _a5HeaderTitleCtrl.text;
      _a4HeaderTitleCtrl.text = _a5HeaderTitleCtrl.text;
      _billHeaderSubtextCtrl.text = _a5HeaderSubtextCtrl.text;
      _a4HeaderSubtextCtrl.text = _a5HeaderSubtextCtrl.text;
      _billPhoneCtrl.text = _a5PhoneCtrl.text;
      _a4PhoneCtrl.text = _a5PhoneCtrl.text;
      _billEmailCtrl.text = _a5EmailCtrl.text;
      _a4EmailCtrl.text = _a5EmailCtrl.text;
      _billWebsiteCtrl.text = _a5WebsiteCtrl.text;
      _a4WebsiteCtrl.text = _a5WebsiteCtrl.text;
      _billTaxRegNoCtrl.text = _a5TaxRegNoCtrl.text;
      _a4TaxRegNoCtrl.text = _a5TaxRegNoCtrl.text;
      _billInvoiceTitleCtrl.text = _a5InvoiceTitleCtrl.text;
      _a4InvoiceTitleCtrl.text = _a5InvoiceTitleCtrl.text;
      _billFooterNoteCtrl.text = _a5FooterNoteCtrl.text;
      _a4FooterNoteCtrl.text = _a5FooterNoteCtrl.text;
      _billTermsCtrl.text = _a5TermsCtrl.text;
      _a4TermsCtrl.text = _a5TermsCtrl.text;
      _billBankNameCtrl.text = _a5BankNameCtrl.text;
      _a4BankNameCtrl.text = _a5BankNameCtrl.text;
      _billBankAccountNoCtrl.text = _a5BankAccountNoCtrl.text;
      _a4BankAccountNoCtrl.text = _a5BankAccountNoCtrl.text;
      _billBankIfscCtrl.text = _a5BankIfscCtrl.text;
      _a4BankIfscCtrl.text = _a5BankIfscCtrl.text;

      _billShowLogo = _a5ShowLogo;
      _a4ShowLogo = _a5ShowLogo;
      _billShowAddress = _a5ShowCompanyAddress;
      _a4ShowCompanyAddress = _a5ShowCompanyAddress;
      _billShowPhone = _a5ShowPhone;
      _a4ShowPhone = _a5ShowPhone;
      _billShowEmail = _a5ShowEmail;
      _a4ShowEmail = _a5ShowEmail;
      _billShowWebsite = _a5ShowWebsite;
      _a4ShowWebsite = _a5ShowWebsite;
      _billShowBrand = _a5ShowBrand;
      _a4ShowBrand = _a5ShowBrand;
      _billShowHsnCode = _a5ShowHsnCode;
      _a4ShowHsnCode = _a5ShowHsnCode;
      _billShowDiscounts = _a5ShowItemDiscount;
      _a4ShowItemDiscount = _a5ShowItemDiscount;
      _billShowTaxBreakup = _a5ShowTaxBreakup;
      _a4ShowTaxBreakup = _a5ShowTaxBreakup;
      _billShowBankDetails = _a5ShowBankDetails;
      _a4ShowBankDetails = _a5ShowBankDetails;
      _billShowCurrency = _a5ShowCurrency;
      _a4ShowCurrency = _a5ShowCurrency;
      _billShowCashier = _a5ShowCashier;
      _a4ShowCashier = _a5ShowCashier;
      _a4ShowPaymentMode = _a5ShowPaymentMode;
      _a4ShowPlaceOfSupply = _a5ShowPlaceOfSupply;
      _billResellerFooterCtrl.text = _a5ResellerFooterCtrl.text;
      _a4ResellerFooterCtrl.text = _a5ResellerFooterCtrl.text;
      _billShowResellerFooter = _a5ShowResellerFooter;
      _a4ShowResellerFooter = _a5ShowResellerFooter;
      _billFssaiCtrl.text = _a5FssaiCtrl.text;
      _a4FssaiCtrl.text = _a5FssaiCtrl.text;
      _billDrugLicenseCtrl.text = _a5DrugLicenseCtrl.text;
      _a4DrugLicenseCtrl.text = _a5DrugLicenseCtrl.text;
      _billShowFssai = _a5ShowFssai;
      _a4ShowFssai = _a5ShowFssai;
      _billShowDrugLicense = _a5ShowDrugLicense;
      _a4ShowDrugLicense = _a5ShowDrugLicense;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Synchronized active format billing details across 80mm, A4, and A5!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    SystemSettingsController settingsCtrl;
    try {
      settingsCtrl = context.read<SystemSettingsController>();
    } catch (_) {
      settingsCtrl = SystemSettingsController();
    }
    final propCtrl = PropertyInfoController();
    await settingsCtrl.load();
    await propCtrl.load();

    final billConfig = settingsCtrl.settings?.receiptTemplateConfig ?? {};
    final a4Config = settingsCtrl.settings?.a4TemplateConfig ?? {};
    final a5Config = settingsCtrl.settings?.a5TemplateConfig ?? {};
    final kotConfig = settingsCtrl.settings?.kotTemplateConfig ?? {};
    final tokenConfig = settingsCtrl.settings?.tokenTemplateConfig ?? {};
    final prop = propCtrl.data;

    final String defaultTaxLabel = _getCountryTaxLabel(prop);
    final String defaultTaxVal = (prop?.gstNo.isNotEmpty == true && !prop!.gstNo.toUpperCase().contains('TAX_DEFAULT'))
        ? '$defaultTaxLabel: ${prop.gstNo}'
        : '';

    String cleanConfigTax(dynamic rawVal) {
      final s = (rawVal ?? '').toString().trim();
      if (s.isEmpty) return defaultTaxVal;
      if (s.contains('P051234567Z') || s.contains('P051987654X') || s.contains('P059988776Z') || s == 'KRA PIN / VAT:' || s == 'KRA PIN / GSTIN:') {
        return defaultTaxVal;
      }
      return s;
    }

    final rtc = settingsCtrl.settings?.receiptTemplateConfig;
    _autoSyncSharedDetails = billConfig['auto_sync_shared_details'] ?? (rtc != null ? (rtc['auto_sync_shared_details'] ?? true) : true);

    // 1. Bill 80mm Config
    _billPhoneCtrl.text = billConfig['phone'] ?? (prop?.mobile ?? '');
    _billEmailCtrl.text = billConfig['email'] ?? (prop?.email ?? '');
    _billWebsiteCtrl.text = billConfig['website'] ?? (prop?.website ?? '');
    _billShowWebsite = billConfig['show_website'] ?? (prop?.printWebsite ?? true);
    final rawBillTitle = billConfig['invoice_title']?.toString().trim();
    _billInvoiceTitleCtrl.text = (rawBillTitle != null && rawBillTitle.isNotEmpty) ? rawBillTitle.toUpperCase() : 'TAX INVOICE';
    _billBankNameCtrl.text = billConfig['bank_name'] ?? (prop?.bankName ?? '');
    _billBankAccountNoCtrl.text = billConfig['bank_account_no'] ?? (prop?.bankAccNo ?? '');
    _billBankIfscCtrl.text = billConfig['bank_ifsc'] ?? (prop?.bankIfsc ?? '');
    _billUpiIdCtrl.text = billConfig['upi_id'] ?? (prop?.upiId ?? '');
    _billUpiPayeeNameCtrl.text = billConfig['upi_payee_name'] ?? (prop?.upiPayeeName ?? '');

    final rawA4Title = a4Config['invoice_title']?.toString().trim();
    _a4InvoiceTitleCtrl.text = (rawA4Title != null && rawA4Title.isNotEmpty) ? rawA4Title.toUpperCase() : 'TAX INVOICE';

    final rawA5Title = (a5Config['invoice_title'] ?? a4Config['invoice_title'])?.toString().trim();
    _a5InvoiceTitleCtrl.text = (rawA5Title != null && rawA5Title.isNotEmpty) ? rawA5Title.toUpperCase() : 'TAX INVOICE';

    _billHeaderTitleCtrl.text = billConfig['header_title'] ?? (prop?.propertyName.isNotEmpty == true ? prop!.propertyName : 'RETAIL POS STORE');
    _billHeaderSubtextCtrl.text = billConfig['header_subtext'] ?? (prop?.address.isNotEmpty == true ? '${prop!.address}, ${prop.city}' : 'Business Address & City');
    _billFooterNoteCtrl.text = billConfig['footer_note'] ?? (prop?.thermalFooterNote.isNotEmpty == true ? prop!.thermalFooterNote : 'Thank you for your business!');
    _billTaxRegNoCtrl.text = cleanConfigTax(billConfig['tax_reg_no']);
    _billFssaiCtrl.text = billConfig['fssai_no'] ?? (prop?.fssaiNo ?? '');
    _billDrugLicenseCtrl.text = billConfig['drug_license_no'] ?? (billConfig['dl_no'] ?? (prop?.drugLicenseNo ?? ''));
    _billTermsCtrl.text = billConfig['terms_and_conditions'] ?? (prop?.termsAndConditions.isNotEmpty == true ? prop!.termsAndConditions : 'Goods once sold will not be taken back or exchanged.');
    _billResellerFooterCtrl.text = billConfig['reseller_footer_text'] ?? AppBrand.poweredByLabel;

    _billShowLogo = billConfig['show_logo'] ?? true;
    _billShowAddress = billConfig['show_address'] ?? true;
    _billShowPhone = billConfig['show_phone'] ?? (prop?.printMobile ?? true);
    _billShowEmail = billConfig['show_email'] ?? (prop?.printEmail ?? true);
    _billShowCustomer = billConfig['show_customer'] ?? true;
    _billShowCashier = billConfig['show_cashier'] ?? true;
    _billShowToken = billConfig['show_token'] ?? (settingsCtrl.settings?.enableTokenSystem ?? false);
    _billShowBrand = billConfig['show_brand'] ?? (settingsCtrl.settings?.showBrandName ?? true);
    _billShowHsnCode = billConfig['show_hsn_code'] ?? true;
    _billShowDiscounts = billConfig['show_item_discounts'] ?? true;
    _billShowTaxBreakup = billConfig['show_tax_breakup'] ?? true;
    _billShowBankDetails = billConfig['show_bank_details'] ?? (prop?.printBankDetails ?? false);
    _billShowUpiQr = billConfig['show_upi_qr'] ?? (prop?.printUpiQr ?? false);
    _billShowResellerFooter = billConfig['show_reseller_footer'] ?? true;
    _billShowCurrency = billConfig['show_currency_symbol'] ?? billConfig['show_currency'] ?? true;
    _billShowFssai = billConfig['show_fssai'] ?? true;
    _billShowDrugLicense = billConfig['show_drug_license'] ?? (billConfig['show_dl_no'] ?? true);
    _billFontSize = billConfig['font_size'] ?? 'MEDIUM';
    _billThermalWidth = billConfig['thermal_width'] ?? '80mm';

    final String rawFormat = (settingsCtrl.settings?.billFormat ?? 'A4').trim().toUpperCase();
    if (rawFormat.contains('A5')) {
      _selectedBillFormat = 'A5';
    } else if (rawFormat.contains('80') || rawFormat.contains('THERMAL') || rawFormat.contains('76') || rawFormat.contains('58')) {
      _selectedBillFormat = 'THERMAL_80';
    } else {
      _selectedBillFormat = 'A4';
    }

    // 2. A4 Invoice Config
    _a4PhoneCtrl.text = a4Config['phone'] ?? (_billPhoneCtrl.text.isNotEmpty ? _billPhoneCtrl.text : (prop?.mobile ?? ''));
    _a4EmailCtrl.text = a4Config['email'] ?? (_billEmailCtrl.text.isNotEmpty ? _billEmailCtrl.text : (prop?.email ?? ''));
    _a4WebsiteCtrl.text = a4Config['website'] ?? (_billWebsiteCtrl.text.isNotEmpty ? _billWebsiteCtrl.text : (prop?.website ?? ''));
    _a4ShowPhone = a4Config['show_phone'] ?? (billConfig['show_phone'] ?? (prop?.printMobile ?? true));
    _a4ShowEmail = a4Config['show_email'] ?? (billConfig['show_email'] ?? (prop?.printEmail ?? true));
    _a4ShowWebsite = a4Config['show_website'] ?? (billConfig['show_website'] ?? (prop?.printWebsite ?? true));
    _a4HeaderTitleCtrl.text = a4Config['header_title'] ?? (prop?.propertyName.isNotEmpty == true ? prop!.propertyName : 'RETAIL ENTERPRISES LIMITED');
    _a4HeaderSubtextCtrl.text = a4Config['header_subtext'] ?? (prop?.address.isNotEmpty == true ? '${prop!.address}, ${prop.city}, ${prop.state}' : 'Commercial Office & Address');
    _a4TaxRegNoCtrl.text = cleanConfigTax(a4Config['tax_reg_no']);
    _a4PanNoCtrl.text = a4Config['pan_no'] ?? (prop?.panNo.isNotEmpty == true ? 'REG / PAN: ${prop!.panNo}' : 'REG / PAN: 12345678');
    _a4FssaiCtrl.text = a4Config['fssai_no'] ?? (_billFssaiCtrl.text.isNotEmpty ? _billFssaiCtrl.text : (prop?.fssaiNo ?? ''));
    _a4DrugLicenseCtrl.text = a4Config['drug_license_no'] ?? (a4Config['dl_no'] ?? (_billDrugLicenseCtrl.text.isNotEmpty ? _billDrugLicenseCtrl.text : (prop?.drugLicenseNo ?? '')));
    _a4FooterNoteCtrl.text = a4Config['footer_note'] ?? 'This is a computer generated invoice and does not require a physical signature.';
    _a4TermsCtrl.text = a4Config['terms_and_conditions'] ?? (prop?.termsAndConditions.isNotEmpty == true ? prop!.termsAndConditions : '1. Goods once sold will not be accepted back without prior inspection.\n2. Interest @ 18% p.a. will be charged on overdue payments after 30 days.\n3. Subject to local judicial arbitration.');
    _a4BankNameCtrl.text = a4Config['bank_name'] ?? (prop?.bankName.isNotEmpty == true ? prop!.bankName : 'Commercial Bank');
    _a4BankAccountNoCtrl.text = a4Config['bank_account_no'] ?? (prop?.bankAccNo.isNotEmpty == true ? prop!.bankAccNo : 'A/C: 0102030405060');
    _a4BankIfscCtrl.text = a4Config['bank_ifsc'] ?? (prop?.bankIfsc.isNotEmpty == true ? prop!.bankIfsc : 'SWIFT / IFSC: 0001234');
    _a4MpesaPaybillCtrl.text = a4Config['digital_payment'] ?? (a4Config['mpesa_paybill'] ?? 'Digital Pay / Till: 247247');
    _a4SignatoryLabelCtrl.text = a4Config['signatory_label'] ?? 'For ${prop?.propertyName.isNotEmpty == true ? prop!.propertyName : "RETAIL ENTERPRISES LTD"}\nAuthorized Signatory';

    _a4ShowLogo = a4Config['show_logo'] ?? true;
    _a4ShowCompanyAddress = a4Config['show_address'] ?? true;
    _a4ShowCompanyContact = a4Config['show_contact'] ?? true;
    _a4ShowTaxReg = a4Config['show_tax_reg'] ?? true;
    _a4ShowBuyerDetails = a4Config['show_buyer_details'] ?? true;
    _a4ShowShippingDetails = a4Config['show_shipping_details'] ?? true;
    _a4ShowHsnCode = a4Config['show_hsn_code'] ?? true;
    _a4ShowBrand = a4Config['show_brand'] ?? true;
    _a4ShowItemDiscount = a4Config['show_item_discount'] ?? true;
    _a4ShowTaxBreakup = a4Config['show_tax_breakup'] ?? true;
    _a4ShowAmountInWords = a4Config['show_amount_in_words'] ?? true;
    _a4ShowBankDetails = a4Config['show_bank_details'] ?? true;
    _a4ShowQrCode = a4Config['show_qr_code'] ?? true;
    _a4ShowTermsAndConditions = a4Config['show_terms'] ?? true;
    _a4ShowSignatureBox = a4Config['show_signature_box'] ?? true;
    _a4ShowCurrency = a4Config['show_currency_symbol'] ?? a4Config['show_currency'] ?? true;
    _a4ShowPaymentMode = a4Config['show_payment_mode'] ?? true;
    _a4ShowPlaceOfSupply = a4Config['show_place_of_supply'] ?? true;
    _a4ShowCashier = a4Config['show_cashier'] ?? true;
    _a4ResellerFooterCtrl.text = a4Config['reseller_footer_text'] ?? (_billResellerFooterCtrl.text.isNotEmpty ? _billResellerFooterCtrl.text : AppBrand.poweredByLabel);
    _a4ShowResellerFooter = a4Config['show_reseller_footer'] ?? true;
    _a4ShowFssai = a4Config['show_fssai'] ?? (_billShowFssai);
    _a4ShowDrugLicense = a4Config['show_drug_license'] ?? (a4Config['show_dl_no'] ?? _billShowDrugLicense);
    _a4ThemeColor = a4Config['theme_color'] ?? 'BLUE';
    _a4FontSize = a4Config['font_size'] ?? 'MEDIUM';

    // 3. A5 Invoice Config
    _a5PhoneCtrl.text = a5Config['phone'] ?? (_a4PhoneCtrl.text.isNotEmpty ? _a4PhoneCtrl.text : (_billPhoneCtrl.text.isNotEmpty ? _billPhoneCtrl.text : (prop?.mobile ?? '')));
    _a5EmailCtrl.text = a5Config['email'] ?? (_a4EmailCtrl.text.isNotEmpty ? _a4EmailCtrl.text : (_billEmailCtrl.text.isNotEmpty ? _billEmailCtrl.text : (prop?.email ?? '')));
    _a5WebsiteCtrl.text = a5Config['website'] ?? (_a4WebsiteCtrl.text.isNotEmpty ? _a4WebsiteCtrl.text : (_billWebsiteCtrl.text.isNotEmpty ? _billWebsiteCtrl.text : (prop?.website ?? '')));
    _a5ShowPhone = a5Config['show_phone'] ?? (_a4ShowPhone);
    _a5ShowEmail = a5Config['show_email'] ?? (_a4ShowEmail);
    _a5ShowWebsite = a5Config['show_website'] ?? (_a4ShowWebsite);
    _a5HeaderTitleCtrl.text = a5Config['header_title'] ?? (a4Config['header_title'] ?? (prop?.propertyName.isNotEmpty == true ? prop!.propertyName : 'RETAIL ENTERPRISES LIMITED'));
    _a5HeaderSubtextCtrl.text = a5Config['header_subtext'] ?? (a4Config['header_subtext'] ?? (prop?.address.isNotEmpty == true ? '${prop!.address}, ${prop.city}, ${prop.state}' : 'Commercial Office & Address'));
    _a5TaxRegNoCtrl.text = cleanConfigTax(a5Config['tax_reg_no'] ?? a4Config['tax_reg_no']);
    _a5PanNoCtrl.text = a5Config['pan_no'] ?? (a4Config['pan_no'] ?? (prop?.panNo.isNotEmpty == true ? 'REG / PAN: ${prop!.panNo}' : 'REG / PAN: 12345678'));
    _a5FssaiCtrl.text = a5Config['fssai_no'] ?? (_a4FssaiCtrl.text.isNotEmpty ? _a4FssaiCtrl.text : (_billFssaiCtrl.text.isNotEmpty ? _billFssaiCtrl.text : (prop?.fssaiNo ?? '')));
    _a5DrugLicenseCtrl.text = a5Config['drug_license_no'] ?? (a5Config['dl_no'] ?? (_a4DrugLicenseCtrl.text.isNotEmpty ? _a4DrugLicenseCtrl.text : (_billDrugLicenseCtrl.text.isNotEmpty ? _billDrugLicenseCtrl.text : (prop?.drugLicenseNo ?? ''))));
    _a5FooterNoteCtrl.text = a5Config['footer_note'] ?? (a4Config['footer_note'] ?? 'This is a computer generated invoice and does not require a physical signature.');
    _a5TermsCtrl.text = a5Config['terms_and_conditions'] ?? (a4Config['terms_and_conditions'] ?? (prop?.termsAndConditions.isNotEmpty == true ? prop!.termsAndConditions : '1. Goods once sold will not be accepted back without prior inspection.\n2. Interest @ 18% p.a. will be charged on overdue payments after 30 days.\n3. Subject to local judicial arbitration.'));
    _a5BankNameCtrl.text = a5Config['bank_name'] ?? (a4Config['bank_name'] ?? (prop?.bankName.isNotEmpty == true ? prop!.bankName : 'Standard Chartered / Equity Bank'));
    _a5BankAccountNoCtrl.text = a5Config['bank_account_no'] ?? (a4Config['bank_account_no'] ?? (prop?.bankAccNo.isNotEmpty == true ? prop!.bankAccNo : 'A/C: 0102030405060'));
    _a5BankIfscCtrl.text = a5Config['bank_ifsc'] ?? (a4Config['bank_ifsc'] ?? (prop?.bankIfsc.isNotEmpty == true ? prop!.bankIfsc : 'SWIFT: SCBLKENX / Branch: 010'));
    _a5MpesaPaybillCtrl.text = a5Config['digital_payment'] ?? (a5Config['mpesa_paybill'] ?? (a4Config['digital_payment'] ?? (a4Config['mpesa_paybill'] ?? 'Digital Pay / Till: 247247')));
    _a5SignatoryLabelCtrl.text = a5Config['signatory_label'] ?? (a4Config['signatory_label'] ?? 'For ${prop?.propertyName.isNotEmpty == true ? prop!.propertyName : "RETAIL ENTERPRISES LTD"}\nAuthorized Signatory');

    _a5ShowLogo = a5Config['show_logo'] ?? (a4Config['show_logo'] ?? true);
    _a5ShowCompanyAddress = a5Config['show_address'] ?? (a4Config['show_address'] ?? true);
    _a5ShowCompanyContact = a5Config['show_contact'] ?? (a4Config['show_contact'] ?? true);
    _a5ShowTaxReg = a5Config['show_tax_reg'] ?? (a4Config['show_tax_reg'] ?? true);
    _a5ShowBuyerDetails = a5Config['show_buyer_details'] ?? (a4Config['show_buyer_details'] ?? true);
    _a5ShowShippingDetails = a5Config['show_shipping_details'] ?? (a4Config['show_shipping_details'] ?? true);
    _a5ShowHsnCode = a5Config['show_hsn_code'] ?? (a4Config['show_hsn_code'] ?? true);
    _a5ShowBrand = a5Config['show_brand'] ?? (a4Config['show_brand'] ?? true);
    _a5ShowItemDiscount = a5Config['show_item_discount'] ?? (a4Config['show_item_discount'] ?? true);
    _a5ShowTaxBreakup = a5Config['show_tax_breakup'] ?? (a4Config['show_tax_breakup'] ?? true);
    _a5ShowAmountInWords = a5Config['show_amount_in_words'] ?? (a4Config['show_amount_in_words'] ?? true);
    _a5ShowBankDetails = a5Config['show_bank_details'] ?? (a4Config['show_bank_details'] ?? true);
    _a5ShowQrCode = a5Config['show_qr_code'] ?? (a4Config['show_qr_code'] ?? true);
    _a5ShowTermsAndConditions = a5Config['show_terms'] ?? (a4Config['show_terms'] ?? true);
    _a5ShowSignatureBox = a5Config['show_signature_box'] ?? (a4Config['show_signature_box'] ?? true);
    _a5ShowCurrency = a5Config['show_currency_symbol'] ?? a5Config['show_currency'] ?? (a4Config['show_currency_symbol'] ?? true);
    _a5ShowPaymentMode = a5Config['show_payment_mode'] ?? (_a4ShowPaymentMode);
    _a5ShowPlaceOfSupply = a5Config['show_place_of_supply'] ?? (_a4ShowPlaceOfSupply);
    _a5ShowCashier = a5Config['show_cashier'] ?? (_a4ShowCashier);
    _a5ResellerFooterCtrl.text = a5Config['reseller_footer_text'] ?? (_a4ResellerFooterCtrl.text.isNotEmpty ? _a4ResellerFooterCtrl.text : (_billResellerFooterCtrl.text.isNotEmpty ? _billResellerFooterCtrl.text : AppBrand.poweredByLabel));
    _a5ShowResellerFooter = a5Config['show_reseller_footer'] ?? (_a4ShowResellerFooter);
    _a5ShowFssai = a5Config['show_fssai'] ?? (_a4ShowFssai);
    _a5ShowDrugLicense = a5Config['show_drug_license'] ?? (a5Config['show_dl_no'] ?? _a4ShowDrugLicense);
    _a5ThemeColor = a5Config['theme_color'] ?? (a4Config['theme_color'] ?? 'BLUE');
    _a5FontSize = a5Config['font_size'] ?? (a4Config['font_size'] ?? 'MEDIUM');

    // 4. KOT Config
    _kotHeaderTitleCtrl.text = kotConfig['header_title'] ?? 'KITCHEN ORDER TICKET';
    _kotFooterNoteCtrl.text = kotConfig['footer_note'] ?? 'Order ready for cooking & serving';
    _kotShowStation = kotConfig['show_station'] ?? true;
    _kotShowTable = kotConfig['show_table'] ?? true;
    _kotShowGuests = kotConfig['show_guests'] ?? true;
    _kotShowWaiter = kotConfig['show_waiter'] ?? true;
    _kotShowTimestamp = kotConfig['show_timestamp'] ?? true;
    _kotShowNotes = kotConfig['show_notes'] ?? true;
    _kotShowBrand = kotConfig['show_brand'] ?? true;
    _kotShowCutLine = kotConfig['show_cut_line'] ?? true;
    _kotFontSize = kotConfig['font_size'] ?? 'MEDIUM';

    // 4. Token Config
    _tokenHeaderTitleCtrl.text = tokenConfig['header_title'] ?? (prop?.propertyName.isNotEmpty == true ? prop!.propertyName : 'ORDER TOKEN / QUEUE SLIP');
    _tokenHeaderSubtextCtrl.text = tokenConfig['header_subtext'] ?? (prop?.address.isNotEmpty == true ? prop!.address : 'Please retain this slip for order collection');
    _tokenFooterNoteCtrl.text = tokenConfig['footer_note'] ?? 'Please watch the pickup display or wait for announcement.';
    _tokenCounterLabelCtrl.text = tokenConfig['counter_label'] ?? 'COUNTER #1 - PICKUP BAY';
    _tokenShowStoreName = tokenConfig['show_store_name'] ?? true;
    _tokenShowBigNumber = tokenConfig['show_big_number'] ?? true;
    _tokenShowOrderNo = tokenConfig['show_order_no'] ?? true;
    _tokenShowTimestamp = tokenConfig['show_timestamp'] ?? true;
    _tokenShowCounter = tokenConfig['show_counter'] ?? true;
    _tokenShowCustomer = tokenConfig['show_customer'] ?? true;
    _tokenShowItemsSummary = tokenConfig['show_items_summary'] ?? true;
    _tokenShowItemCount = tokenConfig['show_item_count'] ?? true;
    _tokenShowBarcode = tokenConfig['show_barcode'] ?? true;
    _tokenShowCutLine = tokenConfig['show_cut_line'] ?? true;
    _tokenBadgeStyle = tokenConfig['badge_style'] ?? 'INVERTED_BOX';
    _tokenFontSize = tokenConfig['font_size'] ?? 'MEDIUM';
    _tokenThermalWidth = tokenConfig['thermal_width'] ?? '80mm';

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveTemplateConfig() async {
    SystemSettingsController settingsCtrl;
    try {
      settingsCtrl = context.read<SystemSettingsController>();
    } catch (_) {
      settingsCtrl = SystemSettingsController();
    }
    var currentSettings = settingsCtrl.settings;
    if (currentSettings == null) {
      await settingsCtrl.load();
      currentSettings = settingsCtrl.settings;
      if (currentSettings == null) return;
    }

    final billConfig = {
      'auto_sync_shared_details': _autoSyncSharedDetails,
      'invoice_title': _billInvoiceTitleCtrl.text.trim().toUpperCase(),
      'phone': _billPhoneCtrl.text.trim(),
      'email': _billEmailCtrl.text.trim(),
      'website': _billWebsiteCtrl.text.trim(),
      'show_website': _billShowWebsite,
      'bank_name': _billBankNameCtrl.text.trim(),
      'bank_account_no': _billBankAccountNoCtrl.text.trim(),
      'bank_ifsc': _billBankIfscCtrl.text.trim(),
      'upi_id': _billUpiIdCtrl.text.trim(),
      'upi_payee_name': _billUpiPayeeNameCtrl.text.trim(),
      'header_title': _billHeaderTitleCtrl.text.trim(),
      'header_subtext': _billHeaderSubtextCtrl.text.trim(),
      'footer_note': _billFooterNoteCtrl.text.trim(),
      'tax_reg_no': _billTaxRegNoCtrl.text.trim(),
      'fssai_no': _billFssaiCtrl.text.trim(),
      'drug_license_no': _billDrugLicenseCtrl.text.trim(),
      'dl_no': _billDrugLicenseCtrl.text.trim(),
      'terms_and_conditions': _billTermsCtrl.text.trim(),
      'show_logo': _billShowLogo,
      'show_address': _billShowAddress,
      'show_phone': _billShowPhone,
      'show_email': _billShowEmail,
      'show_customer': _billShowCustomer,
      'show_cashier': _billShowCashier,
      'show_token': _billShowToken,
      'show_brand': _billShowBrand,
      'show_hsn_code': _billShowHsnCode,
      'show_item_discounts': _billShowDiscounts,
      'show_tax_breakup': _billShowTaxBreakup,
      'show_bank_details': _billShowBankDetails,
      'show_upi_qr': _billShowUpiQr,
      'show_reseller_footer': _billShowResellerFooter,
      'show_currency_symbol': _billShowCurrency,
      'show_fssai': _billShowFssai,
      'show_drug_license': _billShowDrugLicense,
      'show_dl_no': _billShowDrugLicense,
      'reseller_footer_text': _billResellerFooterCtrl.text.trim(),
      'font_size': _billFontSize,
      'thermal_width': _billThermalWidth,
    };

    final a4Config = {
      'auto_sync_shared_details': _autoSyncSharedDetails,
      'invoice_title': _a4InvoiceTitleCtrl.text.trim().toUpperCase(),
      'phone': _a4PhoneCtrl.text.trim(),
      'email': _a4EmailCtrl.text.trim(),
      'website': _a4WebsiteCtrl.text.trim(),
      'show_phone': _a4ShowPhone,
      'show_email': _a4ShowEmail,
      'show_website': _a4ShowWebsite,
      'header_title': _a4HeaderTitleCtrl.text.trim(),
      'header_subtext': _a4HeaderSubtextCtrl.text.trim(),
      'tax_reg_no': _a4TaxRegNoCtrl.text.trim(),
      'pan_no': _a4PanNoCtrl.text.trim(),
      'fssai_no': _a4FssaiCtrl.text.trim(),
      'drug_license_no': _a4DrugLicenseCtrl.text.trim(),
      'dl_no': _a4DrugLicenseCtrl.text.trim(),
      'footer_note': _a4FooterNoteCtrl.text.trim(),
      'terms_and_conditions': _a4TermsCtrl.text.trim(),
      'bank_name': _a4BankNameCtrl.text.trim(),
      'bank_account_no': _a4BankAccountNoCtrl.text.trim(),
      'bank_ifsc': _a4BankIfscCtrl.text.trim(),
      'mpesa_paybill': _a4MpesaPaybillCtrl.text.trim(),
      'digital_payment': _a4MpesaPaybillCtrl.text.trim(),
      'show_payment_mode': _a4ShowPaymentMode,
      'show_place_of_supply': _a4ShowPlaceOfSupply,
      'show_cashier': _a4ShowCashier,
      'show_reseller_footer': _a4ShowResellerFooter,
      'reseller_footer_text': _a4ResellerFooterCtrl.text.trim(),
      'show_fssai': _a4ShowFssai,
      'show_drug_license': _a4ShowDrugLicense,
      'show_dl_no': _a4ShowDrugLicense,
      'signatory_label': _a4SignatoryLabelCtrl.text.trim(),
      'show_logo': _a4ShowLogo,
      'show_address': _a4ShowCompanyAddress,
      'show_contact': _a4ShowCompanyContact,
      'show_tax_reg': _a4ShowTaxReg,
      'show_buyer_details': _a4ShowBuyerDetails,
      'show_shipping_details': _a4ShowShippingDetails,
      'show_hsn_code': _a4ShowHsnCode,
      'show_brand': _a4ShowBrand,
      'show_item_discount': _a4ShowItemDiscount,
      'show_tax_breakup': _a4ShowTaxBreakup,
      'show_amount_in_words': _a4ShowAmountInWords,
      'show_bank_details': _a4ShowBankDetails,
      'show_qr_code': _a4ShowQrCode,
      'show_terms': _a4ShowTermsAndConditions,
      'show_signature_box': _a4ShowSignatureBox,
      'show_currency_symbol': _a4ShowCurrency,
      'theme_color': _a4ThemeColor,
      'font_size': _a4FontSize,
    };

    final a5Config = {
      'auto_sync_shared_details': _autoSyncSharedDetails,
      'invoice_title': _a5InvoiceTitleCtrl.text.trim().toUpperCase(),
      'phone': _a5PhoneCtrl.text.trim(),
      'email': _a5EmailCtrl.text.trim(),
      'website': _a5WebsiteCtrl.text.trim(),
      'show_phone': _a5ShowPhone,
      'show_email': _a5ShowEmail,
      'show_website': _a5ShowWebsite,
      'header_title': _a5HeaderTitleCtrl.text.trim(),
      'header_subtext': _a5HeaderSubtextCtrl.text.trim(),
      'tax_reg_no': _a5TaxRegNoCtrl.text.trim(),
      'pan_no': _a5PanNoCtrl.text.trim(),
      'fssai_no': _a5FssaiCtrl.text.trim(),
      'drug_license_no': _a5DrugLicenseCtrl.text.trim(),
      'dl_no': _a5DrugLicenseCtrl.text.trim(),
      'footer_note': _a5FooterNoteCtrl.text.trim(),
      'terms_and_conditions': _a5TermsCtrl.text.trim(),
      'bank_name': _a5BankNameCtrl.text.trim(),
      'bank_account_no': _a5BankAccountNoCtrl.text.trim(),
      'bank_ifsc': _a5BankIfscCtrl.text.trim(),
      'mpesa_paybill': _a5MpesaPaybillCtrl.text.trim(),
      'digital_payment': _a5MpesaPaybillCtrl.text.trim(),
      'show_payment_mode': _a5ShowPaymentMode,
      'show_place_of_supply': _a5ShowPlaceOfSupply,
      'show_cashier': _a5ShowCashier,
      'show_reseller_footer': _a5ShowResellerFooter,
      'reseller_footer_text': _a5ResellerFooterCtrl.text.trim(),
      'show_fssai': _a5ShowFssai,
      'show_drug_license': _a5ShowDrugLicense,
      'show_dl_no': _a5ShowDrugLicense,
      'signatory_label': _a5SignatoryLabelCtrl.text.trim(),
      'show_logo': _a5ShowLogo,
      'show_address': _a5ShowCompanyAddress,
      'show_contact': _a5ShowCompanyContact,
      'show_tax_reg': _a5ShowTaxReg,
      'show_buyer_details': _a5ShowBuyerDetails,
      'show_shipping_details': _a5ShowShippingDetails,
      'show_hsn_code': _a5ShowHsnCode,
      'show_brand': _a5ShowBrand,
      'show_item_discount': _a5ShowItemDiscount,
      'show_tax_breakup': _a5ShowTaxBreakup,
      'show_amount_in_words': _a5ShowAmountInWords,
      'show_bank_details': _a5ShowBankDetails,
      'show_qr_code': _a5ShowQrCode,
      'show_terms': _a5ShowTermsAndConditions,
      'show_signature_box': _a5ShowSignatureBox,
      'show_currency_symbol': _a5ShowCurrency,
      'theme_color': _a5ThemeColor,
      'font_size': _a5FontSize,
    };

    final kotConfig = {
      'header_title': _kotHeaderTitleCtrl.text.trim(),
      'footer_note': _kotFooterNoteCtrl.text.trim(),
      'show_station': _kotShowStation,
      'show_table': _kotShowTable,
      'show_guests': _kotShowGuests,
      'show_waiter': _kotShowWaiter,
      'show_timestamp': _kotShowTimestamp,
      'show_notes': _kotShowNotes,
      'show_brand': _kotShowBrand,
      'show_cut_line': _kotShowCutLine,
      'font_size': _kotFontSize,
    };

    final tokenConfig = {
      'header_title': _tokenHeaderTitleCtrl.text.trim(),
      'header_subtext': _tokenHeaderSubtextCtrl.text.trim(),
      'footer_note': _tokenFooterNoteCtrl.text.trim(),
      'counter_label': _tokenCounterLabelCtrl.text.trim(),
      'show_store_name': _tokenShowStoreName,
      'show_big_number': _tokenShowBigNumber,
      'show_order_no': _tokenShowOrderNo,
      'show_timestamp': _tokenShowTimestamp,
      'show_counter': _tokenShowCounter,
      'show_customer': _tokenShowCustomer,
      'show_items_summary': _tokenShowItemsSummary,
      'show_item_count': _tokenShowItemCount,
      'show_barcode': _tokenShowBarcode,
      'show_cut_line': _tokenShowCutLine,
      'badge_style': _tokenBadgeStyle,
      'font_size': _tokenFontSize,
      'thermal_width': _tokenThermalWidth,
    };

    currentSettings.receiptTemplateConfig = billConfig;
    currentSettings.a4TemplateConfig = a4Config;
    currentSettings.a5TemplateConfig = a5Config;
    currentSettings.kotTemplateConfig = kotConfig;
    currentSettings.tokenTemplateConfig = tokenConfig;
    currentSettings.billFormat = _selectedBillFormat;

    setState(() => _loading = true);
    await settingsCtrl.save(currentSettings);
    try {
      final propCtrl = PropertyInfoController();
      await propCtrl.load();
      if (propCtrl.data != null) {
        final cur = propCtrl.data!;
        final updatedProp = cur.copyWith(
          thermalFooterNote: _billFooterNoteCtrl.text.trim().isNotEmpty ? _billFooterNoteCtrl.text.trim() : cur.thermalFooterNote,
          termsAndConditions: _billTermsCtrl.text.trim().isNotEmpty ? _billTermsCtrl.text.trim() : cur.termsAndConditions,
          mobile: _billPhoneCtrl.text.trim().isNotEmpty ? _billPhoneCtrl.text.trim() : cur.mobile,
          email: _billEmailCtrl.text.trim().isNotEmpty ? _billEmailCtrl.text.trim() : cur.email,
          website: _billWebsiteCtrl.text.trim().isNotEmpty ? _billWebsiteCtrl.text.trim() : cur.website,
          printMobile: _billShowPhone,
          printEmail: _billShowEmail,
          printWebsite: _billShowWebsite,
          printBankDetails: _billShowBankDetails,
          printUpiQr: _billShowUpiQr,
          bankName: _billBankNameCtrl.text.trim().isNotEmpty ? _billBankNameCtrl.text.trim() : cur.bankName,
          bankAccNo: _billBankAccountNoCtrl.text.trim().isNotEmpty ? _billBankAccountNoCtrl.text.trim() : cur.bankAccNo,
          bankIfsc: _billBankIfscCtrl.text.trim().isNotEmpty ? _billBankIfscCtrl.text.trim() : cur.bankIfsc,
          upiId: _billUpiIdCtrl.text.trim().isNotEmpty ? _billUpiIdCtrl.text.trim() : cur.upiId,
          upiPayeeName: _billUpiPayeeNameCtrl.text.trim().isNotEmpty ? _billUpiPayeeNameCtrl.text.trim() : cur.upiPayeeName,
        );
        await propCtrl.save(updatedProp);
      }
    } catch (_) {}
    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Bill, A4, A5 Invoice, KOT & Token templates saved successfully!'),
          backgroundColor: Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getA5PrimaryColor() {
    switch (_a5ThemeColor) {
      case 'SLATE':
        return const Color(0xFF1E293B);
      case 'EMERALD':
        return const Color(0xFF047857);
      case 'CRIMSON':
        return const Color(0xFF991B1B);
      case 'BLUE':
      default:
        return const Color(0xFF0B5CAD);
    }
  }

  Color _getA4PrimaryColor() {
    switch (_a4ThemeColor) {
      case 'SLATE':
        return const Color(0xFF1E293B);
      case 'EMERALD':
        return const Color(0xFF047857);
      case 'CRIMSON':
        return const Color(0xFF991B1B);
      case 'BLUE':
      default:
        return const Color(0xFF0B5CAD);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Receipt, KOT & Token Template Designer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save, size: 18),
              label: const Text('Save Templates', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _loading ? null : _saveTemplateConfig,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(icon: const Icon(Icons.receipt_long, size: 18), text: _selectedBillFormat == 'THERMAL_80' ? '80mm Thermal (Active)' : '80mm Thermal Bill'),
            Tab(icon: const Icon(Icons.description_outlined, size: 18), text: _selectedBillFormat == 'A4' ? 'A4 Tax Invoice (Active)' : 'A4 Tax Invoice'),
            Tab(icon: const Icon(Icons.receipt_outlined, size: 18), text: _selectedBillFormat == 'A5' ? 'A5 Tax Invoice (Active)' : 'A5 Tax Invoice'),
            const Tab(icon: Icon(Icons.soup_kitchen_outlined, size: 18), text: 'Kitchen KOT'),
            const Tab(icon: Icon(Icons.confirmation_number_outlined, size: 18), text: 'Token Slip'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                _buildDefaultFormatBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _build80mmBillDesignerTab(),
                      _buildA4InvoiceDesignerTab(),
                      _buildA5InvoiceDesignerTab(),
                      _buildKotDesignerTab(),
                      _buildTokenDesignerTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDefaultFormatBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, color: primaryColor, size: 20),
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Default System Bill Format:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _selectedBillFormat == 'THERMAL_80'
                            ? '80mm Roll Default'
                            : (_selectedBillFormat == 'A5' ? 'A5 Half-Sheet Default' : 'A4 Full Sheet Default'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'The selected format governs default layout across POS sales, invoice printing, customer receipts, and duplicates.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SegmentedButton<String>(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return Colors.white;
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return const Color(0xFF334155);
              }),
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: 'THERMAL_80',
                label: Text('80mm Thermal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                icon: Icon(Icons.receipt_long, size: 16),
              ),
              ButtonSegment(
                value: 'A4',
                label: Text('A4 Standard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                icon: Icon(Icons.description, size: 16),
              ),
              ButtonSegment(
                value: 'A5',
                label: Text('A5 Half-Sheet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                icon: Icon(Icons.receipt, size: 16),
              ),
            ],
            selected: {_selectedBillFormat},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _selectedBillFormat = newSelection.first;
              });
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _autoSyncSharedDetails ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _autoSyncSharedDetails ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _autoSyncSharedDetails ? Icons.sync_rounded : Icons.sync_disabled_rounded,
              size: 20,
              color: _autoSyncSharedDetails ? const Color(0xFF16A34A) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Auto-Sync Shared Billing Details Across Formats',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _autoSyncSharedDetails ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _autoSyncSharedDetails ? 'SYNC ACTIVE' : 'INDEPENDENT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: _autoSyncSharedDetails ? const Color(0xFF15803D) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _autoSyncSharedDetails
                        ? 'Store Name, Address, Phone, Email, Website, Tax IDs, Banking & Terms stay synchronized between 80mm, A4, and A5.'
                        : 'Independent Mode: Each template format can have different contact info, headers, and switches without overwriting other formats.',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _syncAllFromActiveFormat(),
              icon: const Icon(Icons.copy_all_rounded, size: 14),
              label: const Text('Push to All Formats', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: _autoSyncSharedDetails,
              activeThumbColor: const Color(0xFF16A34A),
              onChanged: (v) {
                setState(() => _autoSyncSharedDetails = v);
                if (v) _syncAllFromActiveFormat();
              },
            ),
          ],
        ),
      ),
    ],
  ),
);
  }

  // =========================================================================
  // TAB 1: 80mm Thermal Bill Template Designer
  // =========================================================================
  Widget _build80mmBillDesignerTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('80mm Thermal Receipt Content', 'Customize title, tax IDs, and policy notes', Icons.edit_note),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildHeadingFieldWithPresets(
                        label: 'Bill / Receipt Document Heading',
                        controller: _billInvoiceTitleCtrl,
                        presets: const ['TAX INVOICE', 'RETAIL INVOICE', 'BILL OF SUPPLY', 'ESTIMATE / QUOTATION', 'CASH MEMO', 'INVOICE'],
                        onChanged: (v) => _syncText('invoice_title', v, from: '80mm'),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Store / Business Header Title',
                        _billHeaderTitleCtrl,
                        'e.g. ABC SUPERMARKET',
                        onChanged: (v) => _syncText('header_title', v, from: '80mm'),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Header Subtext (Address & Tel)',
                        _billHeaderSubtextCtrl,
                        'e.g. Kimathi St, Nairobi • Tel: 0700000000',
                        maxLines: 2,
                        onChanged: (v) => _syncText('header_subtext', v, from: '80mm'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'Store Phone / Mobile',
                              _billPhoneCtrl,
                              'e.g. +91 9876543210',
                              onChanged: (v) => _syncText('phone', v, from: '80mm'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Store Email',
                              _billEmailCtrl,
                              'e.g. contact@mystore.com',
                              onChanged: (v) => _syncText('email', v, from: '80mm'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'Store Website / Online Store',
                              _billWebsiteCtrl,
                              'e.g. www.mystore.com',
                              onChanged: (v) => _syncText('website', v, from: '80mm'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Tax Registration ID (${_getCountryTaxLabel()})',
                              _billTaxRegNoCtrl,
                              'e.g. ${_getCountryTaxLabel()}: 123456789',
                              onChanged: (v) => _syncText('tax_reg_no', v, from: '80mm'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'FSSAI License No',
                              _billFssaiCtrl,
                              'e.g. 10019011000123',
                              onChanged: (v) => _syncText('fssai', v, from: '80mm'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Drug License (DL No)',
                              _billDrugLicenseCtrl,
                              'e.g. DL-20B/1234',
                              onChanged: (v) => _syncText('drug_license', v, from: '80mm'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Thermal Footer Note',
                        _billFooterNoteCtrl,
                        'e.g. Asante Sana! Thank you for shopping with us.',
                        maxLines: 2,
                        onChanged: (v) => _syncText('footer_note', v, from: '80mm'),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Terms & Return Policy',
                        _billTermsCtrl,
                        'e.g. Goods once sold will not be taken back.',
                        maxLines: 2,
                        onChanged: (v) => _syncText('terms', v, from: '80mm'),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Powered By / Reseller Tagline', _billResellerFooterCtrl, 'e.g. ${AppBrand.poweredByLabel}', onChanged: (v) => _syncText('reseller_footer', v, from: '80mm')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Thermal Section Visibility', 'Toggle components printed on thermal slips', Icons.toggle_on),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildSwitch('Print Store Logo at Top', _billShowLogo, (v) => setState(() { _billShowLogo = v; _syncToggle('show_logo', v, from: '80mm'); })),
                      _buildSwitch('Print Store Address Line', _billShowAddress, (v) => setState(() { _billShowAddress = v; _syncToggle('show_address', v, from: '80mm'); })),
                      _buildSwitch('Print Phone Number', _billShowPhone, (v) => setState(() { _billShowPhone = v; _syncToggle('show_phone', v, from: '80mm'); })),
                      _buildSwitch('Print Email Address', _billShowEmail, (v) => setState(() { _billShowEmail = v; _syncToggle('show_email', v, from: '80mm'); })),
                      _buildSwitch('Print Website Address', _billShowWebsite, (v) => setState(() { _billShowWebsite = v; _syncToggle('show_website', v, from: '80mm'); })),
                      _buildSwitch('Print FSSAI License No', _billShowFssai, (v) => setState(() { _billShowFssai = v; _syncToggle('show_fssai', v, from: '80mm'); })),
                      _buildSwitch('Print Drug License (DL No)', _billShowDrugLicense, (v) => setState(() { _billShowDrugLicense = v; _syncToggle('show_drug_license', v, from: '80mm'); })),
                      _buildSwitch('Print Customer Name & Phone', _billShowCustomer, (v) => setState(() => _billShowCustomer = v)),
                      _buildSwitch('Print Cashier / Server Name', _billShowCashier, (v) => setState(() { _billShowCashier = v; _syncToggle('show_cashier', v, from: '80mm'); })),
                      _buildSwitch('Print Token Number (e.g. TK-101)', _billShowToken, (v) => setState(() => _billShowToken = v)),
                      _buildSwitch('Print Product Brand Prefix', _billShowBrand, (v) => setState(() { _billShowBrand = v; _syncToggle('show_brand', v, from: '80mm'); })),
                      _buildSwitch('Print HSN / SAC Code in Details Line', _billShowHsnCode, (v) => setState(() { _billShowHsnCode = v; _syncToggle('show_hsn_code', v, from: '80mm'); })),
                      _buildSwitch('Print Discount & Scheme Breakdown', _billShowDiscounts, (v) => setState(() { _billShowDiscounts = v; _syncToggle('show_discounts', v, from: '80mm'); })),
                      _buildSwitch('Print Tax Analysis Table (VAT/CTL)', _billShowTaxBreakup, (v) => setState(() { _billShowTaxBreakup = v; _syncToggle('show_tax_breakup', v, from: '80mm'); })),
                      _buildSwitch('Print Bank Account / Digital Pay Till', _billShowBankDetails, (v) => setState(() { _billShowBankDetails = v; _syncToggle('show_bank_details', v, from: '80mm'); })),
                      if (_billShowBankDetails) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Bank Name', _billBankNameCtrl, 'e.g. Bank / Branch', onChanged: (v) => _syncText('bank_name', v, from: '80mm'))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField('Account / Till No', _billBankAccountNoCtrl, 'e.g. 1234567890', onChanged: (v) => _syncText('bank_account_no', v, from: '80mm'))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildTextField('IFSC / SWIFT / Branch Code', _billBankIfscCtrl, 'e.g. HDFC0001234', onChanged: (v) => _syncText('bank_ifsc', v, from: '80mm')),
                        const SizedBox(height: 8),
                      ],
                      _buildSwitch('Print Payment / e-Invoice QR Code', _billShowUpiQr, (v) => setState(() => _billShowUpiQr = v)),
                      if (_billShowUpiQr) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('UPI ID / VPA', _billUpiIdCtrl, 'e.g. store@upi')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField('Payee Legal Name', _billUpiPayeeNameCtrl, 'e.g. Retail Store Ltd')),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildSwitch('Print Powered by Reseller Tag', _billShowResellerFooter, (v) => setState(() { _billShowResellerFooter = v; _syncToggle('show_reseller_footer', v, from: '80mm'); })),
                      _buildSwitch('Print Currency Symbol (${CurrencyService.symbol})', _billShowCurrency, (v) => setState(() { _billShowCurrency = v; _syncToggle('show_currency', v, from: '80mm'); })),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Thermal Paper & Typography Scale', 'Paper roll width and dynamic font density', Icons.font_download),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Paper Roll Width', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _billThermalWidth,
                              decoration: _inputDecoration(),
                              items: const [
                                DropdownMenuItem(value: '80mm', child: Text('80mm (Standard 3-inch Roll)')),
                                DropdownMenuItem(value: '76mm', child: Text('76mm (3-inch POS / Dot Matrix Roll)')),
                                DropdownMenuItem(value: '72mm', child: Text('72mm (Standard Roll)')),
                                DropdownMenuItem(value: '58mm', child: Text('58mm (Compact 2-inch Roll)')),
                              ],
                              onChanged: (v) => setState(() => _billThermalWidth = v ?? '80mm'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Font Density / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _billFontSize,
                              decoration: _inputDecoration(),
                              items: const [
                                DropdownMenuItem(value: 'SMALL', child: Text('Compact (Dense, Save Paper)')),
                                DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Standard')),
                                DropdownMenuItem(value: 'LARGE', child: Text('Large Bold (High Legibility)')),
                              ],
                              onChanged: (v) => setState(() => _billFontSize = v ?? 'MEDIUM'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live 80mm Thermal Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(6)),
                      child: Text('$_billThermalWidth • Font: $_billFontSize', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: primaryColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: _buildLive80mmPreviewPaper(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: A4 Full Tax Invoice Template Designer
  // =========================================================================
  Widget _buildA4InvoiceDesignerTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('A4 Company & Header Details', 'Business identity on standard A4 tax invoice', Icons.business),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildHeadingFieldWithPresets(
                        label: 'A4 Invoice Document Heading',
                        controller: _a4InvoiceTitleCtrl,
                        presets: const ['TAX INVOICE', 'RETAIL INVOICE', 'BILL OF SUPPLY', 'PROFORMA INVOICE', 'COMMERCIAL INVOICE', 'INVOICE'],
                        onChanged: (v) => _syncText('invoice_title', v, from: 'a4'),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Company / Firm Legal Name',
                        _a4HeaderTitleCtrl,
                        'e.g. RETAIL ENTERPRISES LIMITED',
                        onChanged: (v) => _syncText('header_title', v, from: 'a4'),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Registered Office & Postal Address',
                        _a4HeaderSubtextCtrl,
                        'e.g. Commercial Street, Nairobi, Kenya',
                        maxLines: 2,
                        onChanged: (v) => _syncText('header_subtext', v, from: 'a4'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'Store Phone / Mobile',
                              _a4PhoneCtrl,
                              'e.g. +91 9876543210',
                              onChanged: (v) => _syncText('phone', v, from: 'a4'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Store Email',
                              _a4EmailCtrl,
                              'e.g. contact@mystore.com',
                              onChanged: (v) => _syncText('email', v, from: 'a4'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'Store Website / Online Store',
                              _a4WebsiteCtrl,
                              'e.g. www.mystore.com',
                              onChanged: (v) => _syncText('website', v, from: 'a4'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Tax ID / ${_getCountryTaxLabel()}',
                              _a4TaxRegNoCtrl,
                              'e.g. ${_getCountryTaxLabel()}: 123456789',
                              onChanged: (v) => _syncText('tax_reg_no', v, from: 'a4'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Company Reg / PAN', _a4PanNoCtrl, 'e.g. CPR/2023/88990'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'FSSAI License No',
                              _a4FssaiCtrl,
                              'e.g. 10019011000123',
                              onChanged: (v) => _syncText('fssai', v, from: 'a4'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Drug License (DL No)',
                              _a4DrugLicenseCtrl,
                              'e.g. DL-20B/1234',
                              onChanged: (v) => _syncText('drug_license', v, from: 'a4'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Bank Settlement & Signatory Details', 'Payment coordinates & authorization seal', Icons.account_balance),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Bank Name', _a4BankNameCtrl, 'e.g. Standard Chartered / Equity', onChanged: (v) => _syncText('bank_name', v, from: 'a4'))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Bank Account / IBAN', _a4BankAccountNoCtrl, 'e.g. 0102030405060', onChanged: (v) => _syncText('bank_account_no', v, from: 'a4'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('SWIFT / IFSC / Branch', _a4BankIfscCtrl, 'e.g. SCBLKENX / 010', onChanged: (v) => _syncText('bank_ifsc', v, from: 'a4'))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Digital Payment / Till / UPI ID', _a4MpesaPaybillCtrl, 'e.g. UPI / Till / Acc: 247247')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Signatory Designation Label', _a4SignatoryLabelCtrl, 'e.g. For RETAIL ENTERPRISES LTD\nAuthorized Signatory', maxLines: 2),
                      const SizedBox(height: 12),
                      _buildTextField('Invoice Terms & Conditions (Legal)', _a4TermsCtrl, 'e.g. 1. Goods once sold will not be accepted back...', maxLines: 3, onChanged: (v) => _syncText('terms', v, from: 'a4')),
                      const SizedBox(height: 12),
                      _buildTextField('Computer Generated Footer Tagline', _a4FooterNoteCtrl, 'e.g. This is a computer generated invoice...', maxLines: 2, onChanged: (v) => _syncText('footer_note', v, from: 'a4')),
                      const SizedBox(height: 12),
                      _buildTextField('Powered By / Reseller Tagline', _a4ResellerFooterCtrl, 'e.g. ${AppBrand.poweredByLabel}', onChanged: (v) => _syncText('reseller_footer', v, from: 'a4')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('A4 Invoicing Sections & Tables', 'Toggle tables and visual blocks on A4 page', Icons.view_quilt),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildSwitch('Print Company Logo & Header Brand Box', _a4ShowLogo, (v) => setState(() { _a4ShowLogo = v; _syncToggle('show_logo', v, from: 'a4'); })),
                      _buildSwitch('Print Registered Office Address Line', _a4ShowCompanyAddress, (v) => setState(() { _a4ShowCompanyAddress = v; _syncToggle('show_address', v, from: 'a4'); })),
                      _buildSwitch('Print Store Phone Number', _a4ShowPhone, (v) => setState(() { _a4ShowPhone = v; _a4ShowCompanyContact = v || _a4ShowEmail || _a4ShowWebsite; _syncToggle('show_phone', v, from: 'a4'); })),
                      _buildSwitch('Print Store Email Address', _a4ShowEmail, (v) => setState(() { _a4ShowEmail = v; _a4ShowCompanyContact = _a4ShowPhone || v || _a4ShowWebsite; _syncToggle('show_email', v, from: 'a4'); })),
                      _buildSwitch('Print Store Website Address', _a4ShowWebsite, (v) => setState(() { _a4ShowWebsite = v; _a4ShowCompanyContact = _a4ShowPhone || _a4ShowEmail || v; _syncToggle('show_website', v, from: 'a4'); })),
                      _buildSwitch('Print Tax PIN / GSTIN Block', _a4ShowTaxReg, (v) => setState(() { _a4ShowTaxReg = v; _syncToggle('show_tax_reg', v, from: 'a4'); })),
                      _buildSwitch('Print FSSAI License No', _a4ShowFssai, (v) => setState(() { _a4ShowFssai = v; _syncToggle('show_fssai', v, from: 'a4'); })),
                      _buildSwitch('Print Drug License (DL No)', _a4ShowDrugLicense, (v) => setState(() { _a4ShowDrugLicense = v; _syncToggle('show_drug_license', v, from: 'a4'); })),
                      _buildSwitch('Print "Billed To" Customer Card (Name, PIN, Address)', _a4ShowBuyerDetails, (v) => setState(() => _a4ShowBuyerDetails = v)),
                      _buildSwitch('Print "Shipped To" Delivery Address Card', _a4ShowShippingDetails, (v) => setState(() => _a4ShowShippingDetails = v)),
                      _buildSwitch('Print Cashier / Server Name', _a4ShowCashier, (v) => setState(() { _a4ShowCashier = v; _syncToggle('show_cashier', v, from: 'a4'); })),
                      _buildSwitch('Print Payment Mode / Method', _a4ShowPaymentMode, (v) => setState(() { _a4ShowPaymentMode = v; _syncToggle('show_payment_mode', v, from: 'a4'); })),
                      _buildSwitch('Print Place of Supply / State', _a4ShowPlaceOfSupply, (v) => setState(() { _a4ShowPlaceOfSupply = v; _syncToggle('show_place_of_supply', v, from: 'a4'); })),
                      _buildSwitch('Print HSN / SAC Code Column in Items Grid', _a4ShowHsnCode, (v) => setState(() { _a4ShowHsnCode = v; _syncToggle('show_hsn_code', v, from: 'a4'); })),
                      _buildSwitch('Print Item Brand Prefix in Description', _a4ShowBrand, (v) => setState(() { _a4ShowBrand = v; _syncToggle('show_brand', v, from: 'a4'); })),
                      _buildSwitch('Print Item Discount % Column', _a4ShowItemDiscount, (v) => setState(() { _a4ShowItemDiscount = v; _syncToggle('show_discounts', v, from: 'a4'); })),
                      _buildSwitch('Print Comprehensive Tax Breakup Box (CGST/SGST/VAT/CTL)', _a4ShowTaxBreakup, (v) => setState(() { _a4ShowTaxBreakup = v; _syncToggle('show_tax_breakup', v, from: 'a4'); })),
                      _buildSwitch('Print Total Net Payable in Words', _a4ShowAmountInWords, (v) => setState(() => _a4ShowAmountInWords = v)),
                      _buildSwitch('Print Bank Account & Digital Payment Settlement', _a4ShowBankDetails, (v) => setState(() { _a4ShowBankDetails = v; _syncToggle('show_bank_details', v, from: 'a4'); })),
                      _buildSwitch('Print e-Invoice / UPI Payment Verification QR', _a4ShowQrCode, (v) => setState(() => _a4ShowQrCode = v)),
                      _buildSwitch('Print Terms & Conditions Box', _a4ShowTermsAndConditions, (v) => setState(() { _a4ShowTermsAndConditions = v; _syncToggle('show_terms', v, from: 'a4'); })),
                      _buildSwitch('Print Signature & Company Seal Box', _a4ShowSignatureBox, (v) => setState(() => _a4ShowSignatureBox = v)),
                      _buildSwitch('Print Currency Symbol (${CurrencyService.symbol})', _a4ShowCurrency, (v) => setState(() { _a4ShowCurrency = v; _syncToggle('show_currency', v, from: 'a4'); })),
                      _buildSwitch('Print Powered by Reseller Tag', _a4ShowResellerFooter, (v) => setState(() { _a4ShowResellerFooter = v; _syncToggle('show_reseller_footer', v, from: 'a4'); })),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('A4 Accent Color Theme & Typography', 'Color scheme and font density scale', Icons.palette),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme Accent Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildColorOption('BLUE', 'Corporate Navy', const Color(0xFF0B5CAD), selectedKey: _a4ThemeColor, onSelect: (c) => setState(() => _a4ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('SLATE', 'Modern Charcoal', const Color(0xFF1E293B), selectedKey: _a4ThemeColor, onSelect: (c) => setState(() => _a4ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('EMERALD', 'Forest Emerald', const Color(0xFF047857), selectedKey: _a4ThemeColor, onSelect: (c) => setState(() => _a4ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('CRIMSON', 'Executive Wine', const Color(0xFF991B1B), selectedKey: _a4ThemeColor, onSelect: (c) => setState(() => _a4ThemeColor = c)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('A4 Font Density / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _a4FontSize,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'SMALL', child: Text('Compact (Dense Invoicing, Fit More Line Items)')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Standard (Balanced Invoicing)')),
                          DropdownMenuItem(value: 'LARGE', child: Text('Large Spacious (Executive Presentation)')),
                        ],
                        onChanged: (v) => setState(() => _a4FontSize = v ?? 'MEDIUM'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live A4 Sheet Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: _getA4PrimaryColor(), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('A4 210 x 297 mm • Font: $_a4FontSize • $_a4ThemeColor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: _buildLiveA4PreviewSheet(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: Kitchen KOT Template Designer
  // =========================================================================

  // =========================================================================
  // TAB 3: A5 Half-Sheet Tax Invoice Template Designer
  // =========================================================================
  Widget _buildA5InvoiceDesignerTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('A5 Company & Header Details', 'Business identity on compact A5 (148 x 210 mm) tax invoice', Icons.business),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildHeadingFieldWithPresets(
                        label: 'A5 Invoice Document Heading',
                        controller: _a5InvoiceTitleCtrl,
                        presets: const ['TAX INVOICE', 'RETAIL INVOICE', 'BILL OF SUPPLY', 'ESTIMATE', 'CASH MEMO', 'INVOICE'],
                        onChanged: (v) => _syncText('invoice_title', v, from: 'a5'),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Company / Firm Legal Name',
                        _a5HeaderTitleCtrl,
                        'e.g. RETAIL ENTERPRISES LIMITED',
                        onChanged: (v) => _syncText('header_title', v, from: 'a5'),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Registered Office & Postal Address',
                        _a5HeaderSubtextCtrl,
                        'e.g. Commercial Street, Nairobi, Kenya',
                        maxLines: 2,
                        onChanged: (v) => _syncText('header_subtext', v, from: 'a5'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'Store Phone / Mobile',
                              _a5PhoneCtrl,
                              'e.g. +91 9876543210',
                              onChanged: (v) => _syncText('phone', v, from: 'a5'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Store Email',
                              _a5EmailCtrl,
                              'e.g. contact@mystore.com',
                              onChanged: (v) => _syncText('email', v, from: 'a5'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'Store Website / Online Store',
                              _a5WebsiteCtrl,
                              'e.g. www.mystore.com',
                              onChanged: (v) => _syncText('website', v, from: 'a5'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Tax ID / ${_getCountryTaxLabel()}',
                              _a5TaxRegNoCtrl,
                              'e.g. ${_getCountryTaxLabel()}: 123456789',
                              onChanged: (v) => _syncText('tax_reg_no', v, from: 'a5'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Company Reg / PAN', _a5PanNoCtrl, 'e.g. CPR/2023/88990'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'FSSAI License No',
                              _a5FssaiCtrl,
                              'e.g. 10019011000123',
                              onChanged: (v) => _syncText('fssai', v, from: 'a5'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Drug License (DL No)',
                              _a5DrugLicenseCtrl,
                              'e.g. DL-20B/1234',
                              onChanged: (v) => _syncText('drug_license', v, from: 'a5'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Bank Settlement & Signatory Details', 'Payment coordinates & authorization seal', Icons.account_balance),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Bank Name', _a5BankNameCtrl, 'e.g. Standard Chartered / Equity', onChanged: (v) => _syncText('bank_name', v, from: 'a5'))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Bank Account / IBAN', _a5BankAccountNoCtrl, 'e.g. 0102030405060', onChanged: (v) => _syncText('bank_account_no', v, from: 'a5'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('SWIFT / IFSC / Branch', _a5BankIfscCtrl, 'e.g. SCBLKENX / 010', onChanged: (v) => _syncText('bank_ifsc', v, from: 'a5'))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Digital Payment / Till / UPI ID', _a5MpesaPaybillCtrl, 'e.g. UPI / Till / Acc: 247247')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Signatory Designation Label', _a5SignatoryLabelCtrl, 'e.g. For RETAIL ENTERPRISES LTD\nAuthorized Signatory', maxLines: 2),
                      const SizedBox(height: 12),
                      _buildTextField('Invoice Terms & Conditions (Legal)', _a5TermsCtrl, 'e.g. 1. Goods once sold will not be accepted back...', maxLines: 3, onChanged: (v) => _syncText('terms', v, from: 'a5')),
                      const SizedBox(height: 12),
                      _buildTextField('Computer Generated Footer Tagline', _a5FooterNoteCtrl, 'e.g. This is a computer generated invoice...', maxLines: 2, onChanged: (v) => _syncText('footer_note', v, from: 'a5')),
                      const SizedBox(height: 12),
                      _buildTextField('Powered By / Reseller Tagline', _a5ResellerFooterCtrl, 'e.g. ${AppBrand.poweredByLabel}', onChanged: (v) => _syncText('reseller_footer', v, from: 'a5')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('A5 Invoicing Sections & Tables', 'Toggle tables and visual blocks on A5 page', Icons.view_quilt),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildSwitch('Print Company Logo & Header Brand Box', _a5ShowLogo, (v) => setState(() { _a5ShowLogo = v; _syncToggle('show_logo', v, from: 'a5'); })),
                      _buildSwitch('Print Registered Office Address Line', _a5ShowCompanyAddress, (v) => setState(() { _a5ShowCompanyAddress = v; _syncToggle('show_address', v, from: 'a5'); })),
                      _buildSwitch('Print Store Phone Number', _a5ShowPhone, (v) => setState(() { _a5ShowPhone = v; _a5ShowCompanyContact = v || _a5ShowEmail || _a5ShowWebsite; _syncToggle('show_phone', v, from: 'a5'); })),
                      _buildSwitch('Print Store Email Address', _a5ShowEmail, (v) => setState(() { _a5ShowEmail = v; _a5ShowCompanyContact = _a5ShowPhone || v || _a5ShowWebsite; _syncToggle('show_email', v, from: 'a5'); })),
                      _buildSwitch('Print Store Website Address', _a5ShowWebsite, (v) => setState(() { _a5ShowWebsite = v; _a5ShowCompanyContact = _a5ShowPhone || _a5ShowEmail || v; _syncToggle('show_website', v, from: 'a5'); })),
                      _buildSwitch('Print Tax PIN / GSTIN Block', _a5ShowTaxReg, (v) => setState(() { _a5ShowTaxReg = v; _syncToggle('show_tax_reg', v, from: 'a5'); })),
                      _buildSwitch('Print FSSAI License No', _a5ShowFssai, (v) => setState(() { _a5ShowFssai = v; _syncToggle('show_fssai', v, from: 'a5'); })),
                      _buildSwitch('Print Drug License (DL No)', _a5ShowDrugLicense, (v) => setState(() { _a5ShowDrugLicense = v; _syncToggle('show_drug_license', v, from: 'a5'); })),
                      _buildSwitch('Print "Billed To" Customer Card (Name, PIN, Address)', _a5ShowBuyerDetails, (v) => setState(() => _a5ShowBuyerDetails = v)),
                      _buildSwitch('Print "Shipped To" Delivery Address Card', _a5ShowShippingDetails, (v) => setState(() => _a5ShowShippingDetails = v)),
                      _buildSwitch('Print Cashier / Server Name', _a5ShowCashier, (v) => setState(() { _a5ShowCashier = v; _syncToggle('show_cashier', v, from: 'a5'); })),
                      _buildSwitch('Print Payment Mode / Method', _a5ShowPaymentMode, (v) => setState(() { _a5ShowPaymentMode = v; _syncToggle('show_payment_mode', v, from: 'a5'); })),
                      _buildSwitch('Print Place of Supply / State', _a5ShowPlaceOfSupply, (v) => setState(() { _a5ShowPlaceOfSupply = v; _syncToggle('show_place_of_supply', v, from: 'a5'); })),
                      _buildSwitch('Print HSN / SAC Code Column in Items Grid', _a5ShowHsnCode, (v) => setState(() { _a5ShowHsnCode = v; _syncToggle('show_hsn_code', v, from: 'a5'); })),
                      _buildSwitch('Print Item Brand Prefix in Description', _a5ShowBrand, (v) => setState(() { _a5ShowBrand = v; _syncToggle('show_brand', v, from: 'a5'); })),
                      _buildSwitch('Print Item Discount % Column', _a5ShowItemDiscount, (v) => setState(() { _a5ShowItemDiscount = v; _syncToggle('show_discounts', v, from: 'a5'); })),
                      _buildSwitch('Print Comprehensive Tax Breakup Box (CGST/SGST/VAT/CTL)', _a5ShowTaxBreakup, (v) => setState(() { _a5ShowTaxBreakup = v; _syncToggle('show_tax_breakup', v, from: 'a5'); })),
                      _buildSwitch('Print Total Net Payable in Words', _a5ShowAmountInWords, (v) => setState(() => _a5ShowAmountInWords = v)),
                      _buildSwitch('Print Bank Account & Digital Payment Settlement', _a5ShowBankDetails, (v) => setState(() { _a5ShowBankDetails = v; _syncToggle('show_bank_details', v, from: 'a5'); })),
                      _buildSwitch('Print e-Invoice / UPI Payment Verification QR', _a5ShowQrCode, (v) => setState(() => _a5ShowQrCode = v)),
                      _buildSwitch('Print Terms & Conditions Box', _a5ShowTermsAndConditions, (v) => setState(() { _a5ShowTermsAndConditions = v; _syncToggle('show_terms', v, from: 'a5'); })),
                      _buildSwitch('Print Signature & Company Seal Box', _a5ShowSignatureBox, (v) => setState(() => _a5ShowSignatureBox = v)),
                      _buildSwitch('Print Currency Symbol (${CurrencyService.symbol})', _a5ShowCurrency, (v) => setState(() { _a5ShowCurrency = v; _syncToggle('show_currency', v, from: 'a5'); })),
                      _buildSwitch('Print Powered by Reseller Tag', _a5ShowResellerFooter, (v) => setState(() { _a5ShowResellerFooter = v; _syncToggle('show_reseller_footer', v, from: 'a5'); })),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('A5 Accent Color Theme & Typography', 'Color scheme and font density scale', Icons.palette),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme Accent Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildColorOption('BLUE', 'Corporate Navy', const Color(0xFF0B5CAD), selectedKey: _a5ThemeColor, onSelect: (c) => setState(() => _a5ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('SLATE', 'Modern Charcoal', const Color(0xFF1E293B), selectedKey: _a5ThemeColor, onSelect: (c) => setState(() => _a5ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('EMERALD', 'Forest Emerald', const Color(0xFF047857), selectedKey: _a5ThemeColor, onSelect: (c) => setState(() => _a5ThemeColor = c)),
                          const SizedBox(width: 8),
                          _buildColorOption('CRIMSON', 'Executive Wine', const Color(0xFF991B1B), selectedKey: _a5ThemeColor, onSelect: (c) => setState(() => _a5ThemeColor = c)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('A5 Font Density / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _a5FontSize,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'SMALL', child: Text('Compact (Dense Invoicing, Fit More Line Items)')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Standard (Balanced Invoicing)')),
                          DropdownMenuItem(value: 'LARGE', child: Text('Large Spacious (Executive Presentation)')),
                        ],
                        onChanged: (v) => setState(() => _a5FontSize = v ?? 'MEDIUM'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live A5 Sheet Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: _getA5PrimaryColor(), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('A5 148 x 210 mm • Font: $_a5FontSize • $_a5ThemeColor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: _buildLiveA5PreviewSheet(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // LIVE A5 INVOICE SHEET PREVIEW WIDGET (DYNAMIC FONT DENSITY)
  // =========================================================================
  Widget _buildLiveA5PreviewSheet() {
    String fmt(num val) => _a5ShowCurrency ? CurrencyService.format(val) : val.toStringAsFixed(2);
    final themeColor = _getA5PrimaryColor();

    // Dynamic scaling based on _a5FontSize
    double scale = 1.0;
    if (_a5FontSize == 'SMALL') scale = 0.85;
    if (_a5FontSize == 'LARGE') scale = 1.18;

    final double titleSize = 14.0 * scale;
    final double subtextSize = 8.5 * scale;
    final double metaLabelSize = 7.5 * scale;
    final double metaValueSize = 8.0 * scale;
    final double tableHeaderSize = 8.0 * scale;
    final double tableItemSize = 7.8 * scale;
    final double summaryLabelSize = 7.8 * scale;
    final double netTotalSize = 11.0 * scale;

    return Container(
      width: 450,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      padding: EdgeInsets.all(18 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A5 Top Banner / Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_a5ShowLogo) ...[
                Container(
                  width: 40 * scale,
                  height: 40 * scale,
                  decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.corporate_fare, color: themeColor, size: 24 * scale),
                ),
                SizedBox(width: 10 * scale),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _a5HeaderTitleCtrl.text.isEmpty ? 'RETAIL ENTERPRISES LIMITED' : _a5HeaderTitleCtrl.text,
                      style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: themeColor),
                    ),
                    if (_a5ShowCompanyAddress && _a5HeaderSubtextCtrl.text.isNotEmpty) ...[
                      SizedBox(height: 2 * scale),
                      Text(_a5HeaderSubtextCtrl.text, style: TextStyle(fontSize: subtextSize, color: const Color(0xFF475569))),
                    ],
                    () {
                      final contacts = <String>[];
                      if (_a5ShowPhone && _a5PhoneCtrl.text.trim().isNotEmpty) contacts.add('Tel: ${_a5PhoneCtrl.text.trim()}');
                      if (_a5ShowEmail && _a5EmailCtrl.text.trim().isNotEmpty) contacts.add('Email: ${_a5EmailCtrl.text.trim()}');
                      if (_a5ShowWebsite && _a5WebsiteCtrl.text.trim().isNotEmpty) contacts.add('Web: ${_a5WebsiteCtrl.text.trim()}');
                      if (contacts.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(top: 2 * scale),
                        child: Text(contacts.join('  |  '), style: TextStyle(fontSize: 7.8 * scale, color: const Color(0xFF64748B))),
                      );
                    }(),
                    if (_a5ShowTaxReg) ...[
                      SizedBox(height: 2 * scale),
                      Text('${_a5TaxRegNoCtrl.text} | ${_a5PanNoCtrl.text}', style: TextStyle(fontSize: 8 * scale, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    ],
                    if ((_a5ShowFssai && _a5FssaiCtrl.text.trim().isNotEmpty) || (_a5ShowDrugLicense && _a5DrugLicenseCtrl.text.trim().isNotEmpty)) ...[
                      SizedBox(height: 2 * scale),
                      Text([
                        if (_a5ShowFssai && _a5FssaiCtrl.text.trim().isNotEmpty) 'FSSAI: ${_a5FssaiCtrl.text.trim()}',
                        if (_a5ShowDrugLicense && _a5DrugLicenseCtrl.text.trim().isNotEmpty) 'DL No: ${_a5DrugLicenseCtrl.text.trim()}',
                      ].join('  |  '), style: TextStyle(fontSize: 7.8 * scale, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
                decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_a5InvoiceTitleCtrl.text.trim().isEmpty ? 'TAX INVOICE' : _a5InvoiceTitleCtrl.text.trim().toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11 * scale, letterSpacing: 0.8)),
                    Text('A5 COMPACT', style: TextStyle(color: Colors.white70, fontSize: 7 * scale)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          Divider(color: themeColor, thickness: 1.2),
          SizedBox(height: 4 * scale),

          // Metadata + Billed To Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(7 * scale),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('INVOICE DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5 * scale, color: themeColor)),
                      SizedBox(height: 3 * scale),
                      _a4MetaRow('Invoice No:', 'INV-2026-00892', metaLabelSize, metaValueSize),
                      _a4MetaRow('Date & Time:', '27-Sep-2026 14:00 PM', metaLabelSize, metaValueSize),
                      if (_a5ShowCashier)
                        _a4MetaRow('Cashier:', 'famalth1', metaLabelSize, metaValueSize),
                      if (_a5ShowPaymentMode)
                        _a4MetaRow('Payment Mode:', 'BANK / ONLINE', metaLabelSize, metaValueSize),
                      if (_a5ShowPlaceOfSupply)
                        _a4MetaRow('Place of Supply:', _getCountryTaxLabel() == 'GSTIN' ? 'Delhi, India (07)' : 'State / Province (01)', metaLabelSize, metaValueSize),
                    ],
                  ),
                ),
              ),
              if (_a5ShowBuyerDetails) ...[
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(7 * scale),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BILLED TO (BUYER)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5 * scale, color: themeColor)),
                        SizedBox(height: 3 * scale),
                        Text('Apex Commercial Supplies Ltd', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5 * scale)),
                        Text('Plot 45, Uhuru Highway, Nairobi', style: TextStyle(fontSize: 7.8 * scale, color: const Color(0xFF475569))),
                        Text('${_getCountryTaxLabel()}: ${_getCountryTaxLabel() == "GSTIN" ? "07AAAAA0000A1Z5" : "TAX-99887766"}', style: TextStyle(fontSize: 7.8 * scale, color: const Color(0xFF475569))),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8 * scale),

          // Tabular Items Table
          Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1))),
            child: Column(
              children: [
                Container(
                  color: themeColor.withValues(alpha: 0.08),
                  padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 4 * scale),
                  child: Row(
                    children: [
                      SizedBox(width: 18 * scale, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      if (_a5ShowHsnCode) Expanded(flex: 2, child: Text('HSN/SAC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      if (_a5ShowItemDiscount) Expanded(flex: 2, child: Text('DISC', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      if (_a5ShowTaxBreakup) Expanded(flex: 2, child: Text('TAX', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      Expanded(flex: 2, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFCBD5E1)),
                _a5ItemTableRow('1', '${_a5ShowBrand ? "Brookside - " : ""}Fresh Whole Milk 500ml', '0401.20', '10.0', fmt(80.00), fmt(0.00), '16% (${fmt(128.00)})', fmt(800.00), tableItemSize, scale),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _a5ItemTableRow('2', '${_a5ShowBrand ? "Farmers - " : ""}Sandwich Bread 400g', '1905.90', '5.0', fmt(65.00), '5% (${fmt(16.25)})', '16% (${fmt(49.40)})', fmt(308.75), tableItemSize, scale),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _a5ItemTableRow('3', 'Mineral Drinking Water 1L Bottle', '2201.10', '24.0', fmt(50.00), fmt(0.00), '16% (${fmt(192.00)})', fmt(1200.00), tableItemSize, scale),
              ],
            ),
          ),
          SizedBox(height: 8 * scale),

          // Financial Breakup & Bank Details Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    if (_a5ShowBankDetails) ...[
                      Container(
                        padding: EdgeInsets.all(5 * scale),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BANK & PAYMENT SETTLEMENT DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 7.8 * scale, color: themeColor)),
                            SizedBox(height: 2 * scale),
                            Text('Bank: ${_a5BankNameCtrl.text}', style: TextStyle(fontSize: 7.5 * scale)),
                            Text('${_a5BankAccountNoCtrl.text} | ${_a5BankIfscCtrl.text}', style: TextStyle(fontSize: 7.5 * scale)),
                            Text(_a5MpesaPaybillCtrl.text, style: TextStyle(fontSize: 7.5 * scale, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                flex: 4,
                child: Container(
                  padding: EdgeInsets.all(7 * scale),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    children: [
                      _a4SummaryRow('Taxable Amount:', fmt(1989.35), summaryLabelSize),
                      if (_a5ShowTaxBreakup) ...[
                        _a4SummaryRow('CGST / VAT (16%):', fmt(318.30), summaryLabelSize),
                        _a4SummaryRow('Tourism CTL (2%):', fmt(39.79), summaryLabelSize),
                      ],
                      _a4SummaryRow('Round Off:', fmt(-0.69), summaryLabelSize),
                      const Divider(height: 6, color: Color(0xFF94A3B8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NET TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: themeColor)),
                          Text(fmt(2346.75), style: TextStyle(fontWeight: FontWeight.bold, fontSize: netTotalSize, color: themeColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_a5ShowAmountInWords) ...[
            SizedBox(height: 5 * scale),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 7 * scale, vertical: 4 * scale),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
              child: Text(
                'Amount in Words: ${_getCountryTaxLabel() == "GSTIN" ? "Two Thousand Four Hundred Sixty Six Rupees Only" : "Two Thousand Four Hundred Sixty Six Only"}',
                style: TextStyle(fontSize: 7.8 * scale, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, color: Colors.grey.shade900),
              ),
            ),
          ],
          SizedBox(height: 8 * scale),

          // Terms and Signatory Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_a5ShowTermsAndConditions && _a5TermsCtrl.text.isNotEmpty) ...[
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Terms & Conditions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 7.8 * scale)),
                      SizedBox(height: 2 * scale),
                      Text(_a5TermsCtrl.text, style: TextStyle(fontSize: 7.0 * scale, color: const Color(0xFF475569))),
                    ],
                  ),
                ),
                SizedBox(width: 8 * scale),
              ],
              if (_a5ShowQrCode) ...[
                Column(
                  children: [
                    Icon(Icons.qr_code_2, size: 36 * scale),
                    Text('e-Invoice QR', style: TextStyle(fontSize: 6.5 * scale, color: Colors.grey)),
                  ],
                ),
                SizedBox(width: 8 * scale),
              ],
              if (_a5ShowSignatureBox) ...[
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: EdgeInsets.all(5 * scale),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      children: [
                        Text(
                          _a5SignatoryLabelCtrl.text.isEmpty ? 'Authorized Signatory' : _a5SignatoryLabelCtrl.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 7.5 * scale, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 16 * scale),
                        const Divider(height: 1, color: Colors.grey),
                        SizedBox(height: 2 * scale),
                        Text('Signature & Stamp', style: TextStyle(fontSize: 6.5 * scale, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_a5FooterNoteCtrl.text.isNotEmpty) ...[
            SizedBox(height: 6 * scale),
            Center(
              child: Text(_a5FooterNoteCtrl.text, style: TextStyle(fontSize: 7.0 * scale, color: Colors.grey)),
            ),
          ],
          if (_a5ShowResellerFooter) ...[
            SizedBox(height: 2.5 * scale),
            Center(
              child: Text(
                _a5ResellerFooterCtrl.text.trim().isNotEmpty ? _a5ResellerFooterCtrl.text.trim() : AppBrand.poweredByLabel,
                style: TextStyle(fontSize: 6.2 * scale, color: const Color(0xFF94A3B8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKotDesignerTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('Kitchen Ticket Headers', 'Headers and special instructions for chefs', Icons.restaurant_menu),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildTextField('Ticket Header Title', _kotHeaderTitleCtrl, 'e.g. KITCHEN ORDER TICKET (KOT)'),
                      const SizedBox(height: 12),
                      _buildTextField('Kitchen Instructions / Note', _kotFooterNoteCtrl, 'e.g. Please serve piping hot! Order ready.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('KOT Ticket Elements', 'Toggle restaurant info on preparation slip', Icons.checklist_rtl),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildSwitch('Print Kitchen Station Name (e.g. HOT LINE)', _kotShowStation, (v) => setState(() => _kotShowStation = v)),
                      _buildSwitch('Print Table Number in Bold (e.g. Table #04)', _kotShowTable, (v) => setState(() => _kotShowTable = v)),
                      _buildSwitch('Print Guest / Pax Count', _kotShowGuests, (v) => setState(() => _kotShowGuests = v)),
                      _buildSwitch('Print Captain / Waiter Name', _kotShowWaiter, (v) => setState(() => _kotShowWaiter = v)),
                      _buildSwitch('Print Exact Time Stamp', _kotShowTimestamp, (v) => setState(() => _kotShowTimestamp = v)),
                      _buildSwitch('Print Special Notes / Cooking Modifiers', _kotShowNotes, (v) => setState(() => _kotShowNotes = v)),
                      _buildSwitch('Print Product Brand Prefix', _kotShowBrand, (v) => setState(() => _kotShowBrand = v)),
                      _buildSwitch('Print Tear-off Cut Separator Line', _kotShowCutLine, (v) => setState(() => _kotShowCutLine = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Kitchen Font Typography', 'Chef reading legibility and size scale', Icons.format_size),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('KOT Font Density / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _kotFontSize,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'SMALL', child: Text('Compact Size (Dense Slip)')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Standard')),
                          DropdownMenuItem(value: 'LARGE', child: Text('Extra Large (Chef High Visibility Bold)')),
                        ],
                        onChanged: (v) => setState(() => _kotFontSize = v ?? 'MEDIUM'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live Kitchen KOT Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                      child: Text('KDS / 80mm Roll • Font: $_kotFontSize', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFB45309))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: _buildLiveKotPreviewPaper(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 4: Token Slip / Ticket Template Designer
  // =========================================================================
  Widget _buildTokenDesignerTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader('Token Ticket Header & Messages', 'Store identity, pickup counters, and instructions', Icons.confirmation_number),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildTextField('Store Header / Title', _tokenHeaderTitleCtrl, 'e.g. ORDER TOKEN / QUEUE SLIP'),
                      const SizedBox(height: 12),
                      _buildTextField('Subtext / Subtitle', _tokenHeaderSubtextCtrl, 'e.g. Please retain this slip for order collection', maxLines: 2),
                      const SizedBox(height: 12),
                      _buildTextField('Pickup Counter / Station Label', _tokenCounterLabelCtrl, 'e.g. COUNTER #1 - PICKUP BAY'),
                      const SizedBox(height: 12),
                      _buildTextField('Footer Guidance Note', _tokenFooterNoteCtrl, 'e.g. Please watch the pickup screen or wait for your number.', maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Token Badge & Visual Style', 'Format of the prominent token number', Icons.style),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Token Number Badge Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _tokenBadgeStyle,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'INVERTED_BOX', child: Text('Solid Inverted Box (High Contrast Black Block)')),
                          DropdownMenuItem(value: 'BORDER_BOX', child: Text('Bordered Box (Crisp Double/Thick Border)')),
                          DropdownMenuItem(value: 'CIRCLE', child: Text('Circle Badge (Rounded Emblem)')),
                          DropdownMenuItem(value: 'MINIMAL', child: Text('Minimal Clean (Large Bold Text with Underline)')),
                        ],
                        onChanged: (v) => setState(() => _tokenBadgeStyle = v ?? 'INVERTED_BOX'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Paper Roll Width', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _tokenThermalWidth,
                                  decoration: _inputDecoration(),
                                  items: const [
                                    DropdownMenuItem(value: '80mm', child: Text('80mm Standard Roll')),
                                    DropdownMenuItem(value: '76mm', child: Text('76mm POS / Dot Matrix Roll')),
                                    DropdownMenuItem(value: '72mm', child: Text('72mm Roll')),
                                    DropdownMenuItem(value: '58mm', child: Text('58mm Compact Roll')),
                                  ],
                                  onChanged: (v) => setState(() => _tokenThermalWidth = v ?? '80mm'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Font Density / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _tokenFontSize,
                                  decoration: _inputDecoration(),
                                  items: const [
                                    DropdownMenuItem(value: 'SMALL', child: Text('Compact Size')),
                                    DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Standard')),
                                    DropdownMenuItem(value: 'LARGE', child: Text('Extra Large (Maximum Visibility)')),
                                  ],
                                  onChanged: (v) => setState(() => _tokenFontSize = v ?? 'MEDIUM'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCardHeader('Token Section Elements', 'Toggle components printed on token slips', Icons.checklist_rtl),
                const SizedBox(height: 12),
                _buildCardWrapper(
                  child: Column(
                    children: [
                      _buildSwitch('Print Store / Brand Header Name', _tokenShowStoreName, (v) => setState(() => _tokenShowStoreName = v)),
                      _buildSwitch('Print Big Token Badge', _tokenShowBigNumber, (v) => setState(() => _tokenShowBigNumber = v)),
                      _buildSwitch('Print Order / Invoice # Reference', _tokenShowOrderNo, (v) => setState(() => _tokenShowOrderNo = v)),
                      _buildSwitch('Print Exact Order Timestamp', _tokenShowTimestamp, (v) => setState(() => _tokenShowTimestamp = v)),
                      _buildSwitch('Print Pickup Counter / Bay Instruction', _tokenShowCounter, (v) => setState(() => _tokenShowCounter = v)),
                      _buildSwitch('Print Customer Name & Phone', _tokenShowCustomer, (v) => setState(() => _tokenShowCustomer = v)),
                      _buildSwitch('Print Items Summary List', _tokenShowItemsSummary, (v) => setState(() => _tokenShowItemsSummary = v)),
                      _buildSwitch('Print Total Item & Quantity Count', _tokenShowItemCount, (v) => setState(() => _tokenShowItemCount = v)),
                      _buildSwitch('Print Barcode / QR for Scanner Recall', _tokenShowBarcode, (v) => setState(() => _tokenShowBarcode = v)),
                      _buildSwitch('Print Tear-off Cut Separator Line', _tokenShowCutLine, (v) => setState(() => _tokenShowCutLine = v)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFFE2E8F0)),
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live Token Slip Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                      child: Text('$_tokenThermalWidth • Style: $_tokenBadgeStyle • Font: $_tokenFontSize', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF15803D))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: _buildLiveTokenPreviewPaper(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // LIVE 80mm THERMAL PREVIEW WIDGET (DYNAMIC FONT DENSITY)
  // =========================================================================
  // =========================================================================
  // LIVE 80mm THERMAL PREVIEW WIDGET (1:1 REPLICA OF REAL PRINTED BILL)
  // =========================================================================
  Widget _buildLive80mmPreviewPaper() {
    final width = _billThermalWidth == '58mm' ? 260.0 : (_billThermalWidth == '76mm' ? 310.0 : 350.0);

    // Dynamic typography scaling based on _billFontSize
    double scale = 1.0;
    if (_billFontSize == 'SMALL') scale = 0.85;
    if (_billFontSize == 'LARGE') scale = 1.25;

    final double titleSize = 13.5 * scale;
    final double subtextSize = 9.0 * scale;
    final double taxIdSize = 9.5 * scale;
    final double metaSize = 9.0 * scale;
    final double itemHeaderSize = 9.5 * scale;
    final double totalHeaderSize = 13.0 * scale;
    final double totalAmountSize = 14.0 * scale;
    final double noteSize = 9.0 * scale;

    String fmt(num val) {
      if (_billShowCurrency) {
        return CurrencyService.format(val);
      }
      return val.toDouble().toStringAsFixed(2);
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Logo (if enabled)
          if (_billShowLogo) ...[
            Center(
              child: Container(
                width: 32 * scale,
                height: 32 * scale,
                margin: EdgeInsets.only(bottom: 4 * scale),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                ),
                child: Center(
                  child: Icon(Icons.blur_circular, size: 20 * scale, color: const Color(0xFF0284C7)),
                ),
              ),
            ),
          ],

          // 2. Business / Header Title
          Center(
            child: Text(
              _billHeaderTitleCtrl.text.isEmpty ? 'Famalth technologies' : _billHeaderTitleCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: titleSize, color: Colors.black),
            ),
          ),

          // 3. Address Subtext
          if (_billShowAddress && _billHeaderSubtextCtrl.text.isNotEmpty) ...[
            SizedBox(height: 2 * scale),
            Text(
              _billHeaderSubtextCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: subtextSize, color: const Color(0xFF475569)),
            ),
          ],
          if (_billShowPhone && _billPhoneCtrl.text.trim().isNotEmpty) ...[
            SizedBox(height: 1.5 * scale),
            Text(
              'Tel: ${_billPhoneCtrl.text.trim()}',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: subtextSize, color: const Color(0xFF475569)),
            ),
          ],
          if (_billShowEmail && _billEmailCtrl.text.trim().isNotEmpty) ...[
            SizedBox(height: 1.5 * scale),
            Text(
              'Email: ${_billEmailCtrl.text.trim()}',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: subtextSize, color: const Color(0xFF475569)),
            ),
          ],
          if (_billShowWebsite && _billWebsiteCtrl.text.trim().isNotEmpty) ...[
            SizedBox(height: 1.5 * scale),
            Text(
              'Web: ${_billWebsiteCtrl.text.trim()}',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: subtextSize, color: const Color(0xFF475569)),
            ),
          ],

          // 4. Tax ID / GSTIN / PIN
          if (_billTaxRegNoCtrl.text.isNotEmpty) ...[
            SizedBox(height: 2 * scale),
            Text(
              _billTaxRegNoCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: taxIdSize, color: Colors.black),
            ),
          ],
          if (_billShowFssai && _billFssaiCtrl.text.trim().isNotEmpty) ...[
            SizedBox(height: 1.5 * scale),
            Text(
              'FSSAI: ${_billFssaiCtrl.text.trim()}',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: subtextSize, color: const Color(0xFF475569)),
            ),
          ],
          if (_billShowDrugLicense && _billDrugLicenseCtrl.text.trim().isNotEmpty) ...[
            SizedBox(height: 1.5 * scale),
            Text(
              'DL No: ${_billDrugLicenseCtrl.text.trim()}',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: subtextSize, color: Colors.black),
            ),
          ],

          // 5. TAX INVOICE Header Badge
          SizedBox(height: 3 * scale),
          Center(
            child: Text(
              _billInvoiceTitleCtrl.text.trim().isEmpty ? 'TAX INVOICE' : _billInvoiceTitleCtrl.text.trim().toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10.5 * scale, color: Colors.black, letterSpacing: 0.5),
            ),
          ),

          // 6. Token Number (if enabled)
          if (_billShowToken) ...[
            SizedBox(height: 4 * scale),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 2 * scale, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('TOKEN NO: TK-101', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13 * scale, color: Colors.black)),
              ),
            ),
          ],

          SizedBox(height: 4 * scale),
          _dashedDivider(scale),
          SizedBox(height: 3 * scale),

          // 7. Metadata Rows (Bill No, Date, Cashier, Time, Customer)
          _build80mmMetaRow('Bill No:', 'FAM-21-26', 'Date:', '27-Sep-2026', metaSize),
          if (_billShowCashier)
            _build80mmMetaRow('Cashier:', 'famalth1', 'Time:', '02:49 PM', metaSize),
          if (_billShowCustomer)
            _build80mmMetaRow('Customer:', 'Walk-in', 'Phone:', '--', metaSize),

          SizedBox(height: 3 * scale),
          _dashedDivider(scale),
          SizedBox(height: 3 * scale),

          // 8. Item Details Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ITEM DETAILS', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: itemHeaderSize, color: Colors.black)),
              Text('NET TOTAL', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: itemHeaderSize, color: Colors.black)),
            ],
          ),
          SizedBox(height: 3 * scale),

          // 9. Items Rows (matching real PosInvoicePrinter item format)
          _build80mmItemRow(
            '${_billShowBrand ? "JK Paper - " : ""}A4 Paper Rim',
            fmt(855.86),
            '${_billShowHsnCode ? "HSN 4802 | " : ""}2 Nos x ${fmt(399.00)}${_billShowDiscounts ? " | Disc ${fmt(0.00)}" : ""} | Sales Tax 7.25% = ${fmt(57.85)}',
            scale,
          ),

          SizedBox(height: 3 * scale),
          _dashedDivider(scale),
          SizedBox(height: 3 * scale),

          // 10. Summary (Total Items, Total Qty, Subtotal)
          _build80mmSummaryRow('Total Items', '1.00', scale),
          _build80mmSummaryRow('Total Qty', '2.00', scale),
          _build80mmSummaryRow('Subtotal', fmt(798.00), scale),
          if (_billShowDiscounts)
            _build80mmSummaryRow('Savings / Discount', '- ${fmt(0.00)}', scale, isGreen: true),

          SizedBox(height: 3 * scale),
          _dashedDivider(scale),
          SizedBox(height: 3 * scale),

          // 11. Tax Breakup (Taxable Value, Tax Breakup - Items, Round Off)
          _build80mmSummaryRow('Taxable Value', fmt(798.00), scale),
          if (_billShowTaxBreakup) ...[
            SizedBox(height: 3 * scale),
            Text('Tax Breakup - Items', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: Colors.black)),
            SizedBox(height: 2 * scale),
            _build80mmTaxBreakupRow('STATE SALES TAX (6.25%)', fmt(798.00), fmt(49.88), scale),
            _build80mmTaxBreakupRow('CITY TAX (1%)', fmt(798.00), fmt(7.98), scale),
            _build80mmSummaryRow('Round Off', fmt(0.14), scale),
          ],

          SizedBox(height: 3 * scale),
          _dashedDivider(scale),
          SizedBox(height: 4 * scale),

          // 12. NET PAYABLE (Large Bold)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NET PAYABLE', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: totalHeaderSize, color: Colors.black)),
              Text(fmt(856.00), style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: totalAmountSize, color: Colors.black)),
            ],
          ),
          SizedBox(height: 4 * scale),

          // 13. Payment Breakdown (Split Bill Modes)
          _build80mmMetaRow('Payment Mode:', 'SPLIT', 'Refund:', fmt(0.00), metaSize),
          Text('PAYMENT (2 Modes)', style: TextStyle(fontFamily: 'monospace', fontSize: 8.5 * scale, color: Colors.black87)),
          SizedBox(height: 3 * scale),
          Center(
            child: Text(
              '— PAYMENT BREAKDOWN (SPLIT BILL) —',
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8.5 * scale, color: Colors.black),
            ),
          ),
          SizedBox(height: 2 * scale),
          _build80mmMetaRow('CASH:', fmt(856.00), '', '', metaSize),
          _build80mmMetaRow('RETAIL:', fmt(0.14), '', '', metaSize),
          _build80mmMetaRow('Total Received:', fmt(856.00), '', '', metaSize),

          // 14. Realistic Barcode Graphic
          SizedBox(height: 6 * scale),
          Center(
            child: _buildRealisticBarcode('FAM-21-26', scale),
          ),

          // 15. Notes & Footers
          SizedBox(height: 4 * scale),
          Text(
            'Note: Payment: Cash ${fmt(856.00)} | Retail round off: +${fmt(0.14)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'monospace', fontSize: 8.0 * scale, color: Colors.black87),
          ),

          if (_billTermsCtrl.text.isNotEmpty) ...[
            SizedBox(height: 4 * scale),
            Text(
              _billTermsCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: 8.0 * scale, color: Colors.grey.shade800),
            ),
          ],

          if (_billFooterNoteCtrl.text.isNotEmpty) ...[
            SizedBox(height: 4 * scale),
            Text(
              _billFooterNoteCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: noteSize, color: Colors.black),
            ),
          ],

          // 16. Optional UPI QR / Bank Details / Reseller Footer
          if (_billShowUpiQr) ...[
            SizedBox(height: 6 * scale),
            Center(child: Icon(Icons.qr_code_2, size: 46 * scale, color: Colors.black)),
            Center(child: Text('Scan to Pay via UPI', style: TextStyle(fontFamily: 'monospace', fontSize: 8.0 * scale, color: Colors.grey.shade700))),
          ],
          if (_billShowBankDetails) ...[
            SizedBox(height: 6 * scale),
            Container(
              padding: EdgeInsets.all(4 * scale),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
              child: Column(
                children: [
                  Text('--- Bank Details ---', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 8.5 * scale)),
                  Text('Bank: State Bank | A/c: 1234567890 | IFSC: SBIN0001234', style: TextStyle(fontFamily: 'monospace', fontSize: 7.5 * scale)),
                ],
              ),
            ),
          ],
          if (_billShowResellerFooter) ...[
            SizedBox(height: 6 * scale),
            Center(
              child: Text(
                '--- ${_billResellerFooterCtrl.text.trim().isNotEmpty ? _billResellerFooterCtrl.text.trim() : AppBrand.poweredByLabel} ---',
                style: TextStyle(fontFamily: 'monospace', fontSize: 7.5 * scale, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRealisticBarcode(String text, double scale) {
    return Column(
      children: [
        Container(
          height: 28 * scale,
          width: 140 * scale,
          padding: EdgeInsets.symmetric(horizontal: 4 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < 34; i++)
                Container(
                  width: (i % 6 == 0 ? 3.0 : (i % 3 == 0 ? 2.0 : 1.2)) * scale,
                  color: (i % 5 == 1 || i % 8 == 4) ? Colors.transparent : Colors.black,
                ),
            ],
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          text,
          style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: Colors.black, letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _build80mmItemRow(String name, String total, String details, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                total,
                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: Colors.black),
              ),
            ],
          ),
          SizedBox(height: 1 * scale),
          Text(
            details,
            style: TextStyle(fontFamily: 'monospace', fontSize: 8.0 * scale, color: const Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _build80mmMetaRow(String label1, String val1, String label2, String val2, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label1 $val1', style: TextStyle(fontFamily: 'monospace', fontSize: fontSize, color: Colors.black87)),
          if (label2.isNotEmpty || val2.isNotEmpty)
            Text('$label2 $val2', style: TextStyle(fontFamily: 'monospace', fontSize: fontSize, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _build80mmTaxBreakupRow(String label, String taxable, String taxAmt, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 5,
            child: Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 8.5 * scale, color: Colors.black87)),
          ),
          Expanded(
            flex: 3,
            child: Text(taxable, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontSize: 8.5 * scale, color: Colors.black87)),
          ),
          Expanded(
            flex: 2,
            child: Text(taxAmt, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 8.5 * scale, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _build80mmSummaryRow(String label, String value, double scale, {bool isGreen = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.0 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 9.0 * scale, color: isGreen ? const Color(0xFF15803D) : Colors.black87)),
          Text(value, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 9.0 * scale, color: isGreen ? const Color(0xFF15803D) : Colors.black87)),
        ],
      ),
    );
  }

  // =========================================================================
  // LIVE A4 INVOICE SHEET PREVIEW WIDGET (DYNAMIC FONT DENSITY)
  // =========================================================================
  Widget _buildLiveA4PreviewSheet() {
    String fmt(num val) => _a4ShowCurrency ? CurrencyService.format(val) : val.toStringAsFixed(2);
    final themeColor = _getA4PrimaryColor();

    // Dynamic scaling based on _a4FontSize
    double scale = 1.0;
    if (_a4FontSize == 'SMALL') scale = 0.85;
    if (_a4FontSize == 'LARGE') scale = 1.18;

    final double titleSize = 16.0 * scale;
    final double subtextSize = 9.5 * scale;
    final double metaLabelSize = 8.0 * scale;
    final double metaValueSize = 8.5 * scale;
    final double tableHeaderSize = 9.0 * scale;
    final double tableItemSize = 8.5 * scale;
    final double summaryLabelSize = 8.5 * scale;
    final double netTotalSize = 12.0 * scale;

    return Container(
      width: 580,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      padding: EdgeInsets.all(26 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A4 Top Banner / Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_a4ShowLogo) ...[
                Container(
                  width: 48 * scale,
                  height: 48 * scale,
                  decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.corporate_fare, color: themeColor, size: 28 * scale),
                ),
                SizedBox(width: 12 * scale),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _a4HeaderTitleCtrl.text.isEmpty ? 'RETAIL ENTERPRISES LIMITED' : _a4HeaderTitleCtrl.text,
                      style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: themeColor),
                    ),
                    if (_a4ShowCompanyAddress && _a4HeaderSubtextCtrl.text.isNotEmpty) ...[
                      SizedBox(height: 2 * scale),
                      Text(_a4HeaderSubtextCtrl.text, style: TextStyle(fontSize: subtextSize, color: const Color(0xFF475569))),
                    ],
                    () {
                      final contacts = <String>[];
                      if (_a4ShowPhone && _a4PhoneCtrl.text.trim().isNotEmpty) contacts.add('Tel: ${_a4PhoneCtrl.text.trim()}');
                      if (_a4ShowEmail && _a4EmailCtrl.text.trim().isNotEmpty) contacts.add('Email: ${_a4EmailCtrl.text.trim()}');
                      if (_a4ShowWebsite && _a4WebsiteCtrl.text.trim().isNotEmpty) contacts.add('Web: ${_a4WebsiteCtrl.text.trim()}');
                      if (contacts.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(top: 2 * scale),
                        child: Text(contacts.join('  |  '), style: TextStyle(fontSize: 8.5 * scale, color: const Color(0xFF64748B))),
                      );
                    }(),
                    if (_a4ShowTaxReg) ...[
                      SizedBox(height: 2 * scale),
                      Text('${_a4TaxRegNoCtrl.text}  |  ${_a4PanNoCtrl.text}', style: TextStyle(fontSize: 9 * scale, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    ],
                    if ((_a4ShowFssai && _a4FssaiCtrl.text.trim().isNotEmpty) || (_a4ShowDrugLicense && _a4DrugLicenseCtrl.text.trim().isNotEmpty)) ...[
                      SizedBox(height: 2 * scale),
                      Text([
                        if (_a4ShowFssai && _a4FssaiCtrl.text.trim().isNotEmpty) 'FSSAI: ${_a4FssaiCtrl.text.trim()}',
                        if (_a4ShowDrugLicense && _a4DrugLicenseCtrl.text.trim().isNotEmpty) 'DL No: ${_a4DrugLicenseCtrl.text.trim()}',
                      ].join('  |  '), style: TextStyle(fontSize: 8.5 * scale, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
                decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_a4InvoiceTitleCtrl.text.trim().isEmpty ? 'TAX INVOICE' : _a4InvoiceTitleCtrl.text.trim().toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * scale, letterSpacing: 1)),
                    Text('ORIGINAL FOR RECIPIENT', style: TextStyle(color: Colors.white70, fontSize: 7.5 * scale)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          Divider(color: themeColor, thickness: 1.5),
          SizedBox(height: 6 * scale),

          // Metadata + Billed To Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(9 * scale),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('INVOICE DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: themeColor)),
                      SizedBox(height: 4 * scale),
                      _a4MetaRow('Invoice No:', 'INV-2026-00892', metaLabelSize, metaValueSize),
                      _a4MetaRow('Date & Time:', '27-Sep-2026 14:00 PM', metaLabelSize, metaValueSize),
                      if (_a4ShowCashier)
                        _a4MetaRow('Cashier:', 'famalth1', metaLabelSize, metaValueSize),
                      if (_a4ShowPaymentMode)
                        _a4MetaRow('Payment Mode:', 'BANK TRANSFER / ONLINE', metaLabelSize, metaValueSize),
                      if (_a4ShowPlaceOfSupply)
                        _a4MetaRow('Place of Supply:', _getCountryTaxLabel() == 'GSTIN' ? 'Delhi, India (07)' : 'State / Province (01)', metaLabelSize, metaValueSize),
                    ],
                  ),
                ),
              ),
              if (_a4ShowBuyerDetails) ...[
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(9 * scale),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BILLED TO (BUYER)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5 * scale, color: themeColor)),
                        SizedBox(height: 4 * scale),
                        Text('Apex Commercial Supplies Ltd', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5 * scale)),
                        Text('Plot 45, Uhuru Highway, Nairobi', style: TextStyle(fontSize: 8.5 * scale, color: const Color(0xFF475569))),
                        Text('${_getCountryTaxLabel()}: ${_getCountryTaxLabel() == "GSTIN" ? "07AAAAA0000A1Z5" : "TAX-99887766"} | Tel: +1 555 0199', style: TextStyle(fontSize: 8.5 * scale, color: const Color(0xFF475569))),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12 * scale),

          // Tabular Items Table
          Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1))),
            child: Column(
              children: [
                Container(
                  color: themeColor.withValues(alpha: 0.08),
                  padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 5 * scale),
                  child: Row(
                    children: [
                      SizedBox(width: 22 * scale, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      if (_a4ShowHsnCode) Expanded(flex: 2, child: Text('HSN/SAC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      if (_a4ShowItemDiscount) Expanded(flex: 2, child: Text('DISC', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      if (_a4ShowTaxBreakup) Expanded(flex: 2, child: Text('TAX', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                      Expanded(flex: 2, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: tableHeaderSize, color: const Color(0xFF1E293B)))),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFCBD5E1)),
                _a4ItemTableRow('1', '${_a4ShowBrand ? "Brookside - " : ""}Fresh Whole Milk 500ml', '0401.20', '10.0', fmt(80.00), fmt(0.00), '16% (${fmt(128.00)})', fmt(800.00), tableItemSize, scale),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _a4ItemTableRow('2', '${_a4ShowBrand ? "Farmers - " : ""}Sandwich Bread 400g', '1905.90', '5.0', fmt(65.00), '5% (${fmt(16.25)})', '16% (${fmt(49.40)})', fmt(308.75), tableItemSize, scale),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _a4ItemTableRow('3', 'Mineral Drinking Water 1L Bottle', '2201.10', '24.0', fmt(50.00), fmt(0.00), '16% (${fmt(192.00)})', fmt(1200.00), tableItemSize, scale),
              ],
            ),
          ),
          SizedBox(height: 10 * scale),

          // Financial Breakup & Bank Details Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    if (_a4ShowBankDetails) ...[
                      Container(
                        padding: EdgeInsets.all(7 * scale),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BANK & PAYMENT SETTLEMENT DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5 * scale, color: themeColor)),
                            SizedBox(height: 3 * scale),
                            Text('Bank: ${_a4BankNameCtrl.text}', style: TextStyle(fontSize: 8 * scale)),
                            Text('${_a4BankAccountNoCtrl.text}  |  ${_a4BankIfscCtrl.text}', style: TextStyle(fontSize: 8 * scale)),
                            Text(_a4MpesaPaybillCtrl.text, style: TextStyle(fontSize: 8 * scale, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                flex: 4,
                child: Container(
                  padding: EdgeInsets.all(9 * scale),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    children: [
                      _a4SummaryRow('Taxable Amount:', fmt(1989.35), summaryLabelSize),
                      if (_a4ShowTaxBreakup) ...[
                        _a4SummaryRow('CGST / VAT (16%):', fmt(318.30), summaryLabelSize),
                        _a4SummaryRow('Tourism CTL (2%):', fmt(39.79), summaryLabelSize),
                      ],
                      _a4SummaryRow('Round Off:', fmt(-0.69), summaryLabelSize),
                      const Divider(height: 8, color: Color(0xFF94A3B8)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NET TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11 * scale, color: themeColor)),
                          Text(fmt(2346.75), style: TextStyle(fontWeight: FontWeight.bold, fontSize: netTotalSize, color: themeColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_a4ShowAmountInWords) ...[
            SizedBox(height: 6 * scale),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 5 * scale),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
              child: Text(
                'Amount in Words: ${_getCountryTaxLabel() == "GSTIN" ? "Two Thousand Four Hundred Sixty Six Rupees Only" : "Two Thousand Four Hundred Sixty Six Only"}',
                style: TextStyle(fontSize: 8.5 * scale, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, color: Colors.grey.shade900),
              ),
            ),
          ],
          SizedBox(height: 12 * scale),

          // Terms and Signatory Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_a4ShowTermsAndConditions && _a4TermsCtrl.text.isNotEmpty) ...[
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Terms & Conditions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5 * scale)),
                      SizedBox(height: 2 * scale),
                      Text(_a4TermsCtrl.text, style: TextStyle(fontSize: 7.5 * scale, color: const Color(0xFF475569))),
                    ],
                  ),
                ),
                SizedBox(width: 10 * scale),
              ],
              if (_a4ShowQrCode) ...[
                Column(
                  children: [
                    Icon(Icons.qr_code_2, size: 44 * scale),
                    Text('e-Invoice QR', style: TextStyle(fontSize: 7 * scale, color: Colors.grey)),
                  ],
                ),
                SizedBox(width: 10 * scale),
              ],
              if (_a4ShowSignatureBox) ...[
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: EdgeInsets.all(7 * scale),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      children: [
                        Text(
                          _a4SignatoryLabelCtrl.text.isEmpty ? 'Authorized Signatory' : _a4SignatoryLabelCtrl.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 8 * scale, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 20 * scale),
                        const Divider(height: 1, color: Colors.grey),
                        SizedBox(height: 2 * scale),
                        Text('Signature & Stamp', style: TextStyle(fontSize: 7 * scale, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_a4FooterNoteCtrl.text.isNotEmpty) ...[
            SizedBox(height: 8 * scale),
            Center(
              child: Text(_a4FooterNoteCtrl.text, style: TextStyle(fontSize: 7.5 * scale, color: Colors.grey)),
            ),
          ],
          if (_a4ShowResellerFooter) ...[
            SizedBox(height: 3 * scale),
            Center(
              child: Text(
                _a4ResellerFooterCtrl.text.trim().isNotEmpty ? _a4ResellerFooterCtrl.text.trim() : AppBrand.poweredByLabel,
                style: TextStyle(fontSize: 6.8 * scale, color: const Color(0xFF94A3B8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _a4MetaRow(String label, String value, double labelSize, double valueSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(width: 85, child: Text(label, style: TextStyle(fontSize: labelSize, color: const Color(0xFF64748B)))),
          Expanded(child: Text(value, style: TextStyle(fontSize: valueSize, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _a4ItemTableRow(String no, String name, String hsn, String qty, String rate, String disc, String tax, String total, double fontSize, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3.5 * scale),
      child: Row(
        children: [
          SizedBox(width: 22 * scale, child: Text(no, style: TextStyle(fontSize: fontSize))),
          Expanded(flex: 4, child: Text(name, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600))),
          if (_a4ShowHsnCode) Expanded(flex: 2, child: Text(hsn, style: TextStyle(fontSize: fontSize * 0.95, color: const Color(0xFF64748B)))),
          Expanded(flex: 1, child: Text(qty, textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize))),
          Expanded(flex: 2, child: Text(rate, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize))),
          if (_a4ShowItemDiscount) Expanded(flex: 2, child: Text(disc, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize, color: const Color(0xFF15803D)))),
          if (_a4ShowTaxBreakup) Expanded(flex: 2, child: Text(tax, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize * 0.95))),
          Expanded(flex: 2, child: Text(total, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _a5ItemTableRow(String no, String name, String hsn, String qty, String rate, String disc, String tax, String total, double fontSize, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 3.5 * scale),
      child: Row(
        children: [
          SizedBox(width: 18 * scale, child: Text(no, style: TextStyle(fontSize: fontSize))),
          Expanded(flex: 4, child: Text(name, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600))),
          if (_a5ShowHsnCode) Expanded(flex: 2, child: Text(hsn, style: TextStyle(fontSize: fontSize * 0.95, color: const Color(0xFF64748B)))),
          Expanded(flex: 1, child: Text(qty, textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize))),
          Expanded(flex: 2, child: Text(rate, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize))),
          if (_a5ShowItemDiscount) Expanded(flex: 2, child: Text(disc, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize, color: const Color(0xFF15803D)))),
          if (_a5ShowTaxBreakup) Expanded(flex: 2, child: Text(tax, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize * 0.95))),
          Expanded(flex: 2, child: Text(total, textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _a4SummaryRow(String label, String value, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: const Color(0xFF475569))),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // =========================================================================
  // LIVE KOT PREVIEW TICKET WIDGET (DYNAMIC FONT DENSITY)
  // =========================================================================
  Widget _buildLiveKotPreviewPaper() {
    // Dynamic typography scaling based on _kotFontSize
    double scale = 1.0;
    if (_kotFontSize == 'SMALL') scale = 0.85;
    if (_kotFontSize == 'LARGE') scale = 1.30;

    final double titleSize = 14.0 * scale;
    final double stationSize = 10.0 * scale;
    final double tableSize = 13.0 * scale;
    final double paxSize = 11.0 * scale;
    final double metaSize = 9.5 * scale;
    final double headerSize = 10.5 * scale;
    final double noteSize = 9.5 * scale;

    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              _kotHeaderTitleCtrl.text.isEmpty ? 'KITCHEN ORDER TICKET' : _kotHeaderTitleCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: titleSize, color: Colors.black),
            ),
          ),
          if (_kotShowStation) ...[
            SizedBox(height: 2 * scale),
            Center(
              child: Text('[ KITCHEN STATION: HOT LINE / GRILL ]', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: stationSize, color: const Color(0xFFB45309))),
            ),
          ],
          SizedBox(height: 5 * scale),
          _dashedDivider(scale),
          SizedBox(height: 5 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_kotShowTable) Text('TABLE: T-04 (Dine-In)', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: tableSize)),
              if (_kotShowGuests) Text('PAX: 3', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: paxSize)),
            ],
          ),
          SizedBox(height: 3 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KOT #: KOT-088', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: metaSize)),
              if (_kotShowTimestamp) Text('27-Sep-2026 14:02', style: TextStyle(fontFamily: 'monospace', fontSize: metaSize, color: Colors.grey.shade700)),
            ],
          ),
          if (_kotShowWaiter) ...[
            SizedBox(height: 2 * scale),
            Text('Captain/Server: Alex K.', style: TextStyle(fontFamily: 'monospace', fontSize: metaSize)),
          ],
          SizedBox(height: 5 * scale),
          _dashedDivider(scale),
          SizedBox(height: 5 * scale),
          Row(
            children: [
              Expanded(flex: 7, child: Text('ORDERED ITEM', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: headerSize))),
              Expanded(flex: 3, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: headerSize))),
            ],
          ),
          SizedBox(height: 4 * scale),
          _buildKotItemRow('${_kotShowBrand ? "Chef Special - " : ""}Grilled Chicken Breast', '2.0', scale, modifier: _kotShowNotes ? '* Medium Spicy, Extra Sauce' : null),
          _buildKotItemRow('Garlic Naan Butter', '4.0', scale),
          _buildKotItemRow('Fresh Passion Juice Pitcher', '1.0', scale, modifier: _kotShowNotes ? '* No Sugar Added' : null),
          SizedBox(height: 6 * scale),
          _dashedDivider(scale),
          if (_kotFooterNoteCtrl.text.isNotEmpty) ...[
            SizedBox(height: 6 * scale),
            Text(
              _kotFooterNoteCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontStyle: FontStyle.italic, fontSize: noteSize, color: Colors.black),
            ),
          ],
          if (_kotShowCutLine) ...[
            SizedBox(height: 10 * scale),
            Center(
              child: Text('✂ - - - - - - - - TEAR HERE - - - - - - - - ✂', style: TextStyle(fontFamily: 'monospace', fontSize: 9 * scale, color: Colors.grey)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKotItemRow(String name, String qty, double scale, {String? modifier}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 7, child: Text(name, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11 * scale))),
              Expanded(flex: 3, child: Text(qty, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 13.5 * scale))),
            ],
          ),
          if (modifier != null) ...[
            SizedBox(height: 1 * scale),
            Text(modifier, style: TextStyle(fontFamily: 'monospace', fontStyle: FontStyle.italic, fontSize: 9 * scale, color: const Color(0xFFDC2626))),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // LIVE TOKEN SLIP PREVIEW WIDGET (TAB 4)
  // =========================================================================
  Widget _buildLiveTokenPreviewPaper() {
    final width = _tokenThermalWidth == '58mm' ? 260.0 : 340.0;

    // Dynamic typography scaling based on _tokenFontSize
    double scale = 1.0;
    if (_tokenFontSize == 'SMALL') scale = 0.85;
    if (_tokenFontSize == 'LARGE') scale = 1.25;

    final double titleSize = 14.0 * scale;
    final double subtextSize = 9.5 * scale;
    final double counterSize = 11.0 * scale;
    final double metaSize = 9.5 * scale;
    final double noteSize = 9.0 * scale;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_tokenShowStoreName) ...[
            Center(
              child: Text(
                _tokenHeaderTitleCtrl.text.isEmpty ? 'ORDER TOKEN SLIP' : _tokenHeaderTitleCtrl.text,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: titleSize, color: Colors.black),
              ),
            ),
            if (_tokenHeaderSubtextCtrl.text.isNotEmpty) ...[
              SizedBox(height: 2 * scale),
              Text(
                _tokenHeaderSubtextCtrl.text,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', fontSize: subtextSize, color: const Color(0xFF64748B)),
              ),
            ],
            SizedBox(height: 6 * scale),
            _dashedDivider(scale),
            SizedBox(height: 6 * scale),
          ],

          if (_tokenShowBigNumber) ...[
            _buildTokenBadge(scale),
            SizedBox(height: 8 * scale),
          ],

          if (_tokenShowCounter && _tokenCounterLabelCtrl.text.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.symmetric(vertical: 4 * scale, horizontal: 8),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
              child: Center(
                child: Text(
                  _tokenCounterLabelCtrl.text,
                  style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: counterSize, color: const Color(0xFF0F172A)),
                ),
              ),
            ),
            SizedBox(height: 6 * scale),
          ],

          if (_tokenShowOrderNo || _tokenShowTimestamp) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_tokenShowOrderNo) Text('Order: #ORD-0842', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: metaSize)),
                if (_tokenShowTimestamp) Text('27-Sep-2026 14:05', style: TextStyle(fontFamily: 'monospace', fontSize: metaSize * 0.95, color: Colors.grey.shade700)),
              ],
            ),
          ],

          if (_tokenShowCustomer) ...[
            SizedBox(height: 3 * scale),
            Text('Customer: Jane Kamau (+254 712 ***)', style: TextStyle(fontFamily: 'monospace', fontSize: metaSize)),
          ],

          if (_tokenShowItemsSummary) ...[
            SizedBox(height: 6 * scale),
            _dashedDivider(scale),
            SizedBox(height: 4 * scale),
            Row(
              children: [
                Expanded(flex: 7, child: Text('ITEM ORDER SUMMARY', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale))),
                Expanded(flex: 3, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale))),
              ],
            ),
            SizedBox(height: 3 * scale),
            _buildTokenItemSummaryRow('Beef Burger Double Combo', '1', scale),
            _buildTokenItemSummaryRow('French Fries Large', '2', scale),
            _buildTokenItemSummaryRow('Vanilla Shake 400ml', '1', scale),
          ],

          if (_tokenShowItemCount) ...[
            SizedBox(height: 4 * scale),
            _dashedDivider(scale),
            SizedBox(height: 4 * scale),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL ITEMS / UNITS:', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale)),
                Text('3 Items (Qty: 4)', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10 * scale)),
              ],
            ),
          ],

          if (_tokenShowBarcode) ...[
            SizedBox(height: 8 * scale),
            Center(
              child: Column(
                children: [
                  Icon(Icons.view_column, size: 36 * scale, color: Colors.black87),
                  Text('*TK-104-0842*', style: TextStyle(fontFamily: 'monospace', fontSize: 8.5 * scale, letterSpacing: 2)),
                ],
              ),
            ),
          ],

          if (_tokenFooterNoteCtrl.text.isNotEmpty) ...[
            SizedBox(height: 8 * scale),
            Text(
              _tokenFooterNoteCtrl.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: noteSize, color: Colors.grey.shade700),
            ),
          ],

          if (_tokenShowCutLine) ...[
            SizedBox(height: 10 * scale),
            Center(
              child: Text('✂ - - - - - - - - TEAR HERE - - - - - - - - ✂', style: TextStyle(fontFamily: 'monospace', fontSize: 9 * scale, color: Colors.grey)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTokenBadge(double scale) {
    switch (_tokenBadgeStyle) {
      case 'BORDER_BOX':
        return Container(
          padding: EdgeInsets.symmetric(vertical: 10 * scale, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text('YOUR TOKEN NUMBER', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10 * scale, letterSpacing: 1.5)),
              SizedBox(height: 2 * scale),
              Text('104', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 38 * scale, color: Colors.black, letterSpacing: 3)),
            ],
          ),
        );
      case 'CIRCLE':
        return Center(
          child: Container(
            width: 100 * scale,
            height: 100 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('TOKEN', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9 * scale, color: Colors.white70, letterSpacing: 1.5)),
                Text('104', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 34 * scale, color: Colors.white)),
              ],
            ),
          ),
        );
      case 'MINIMAL':
        return Container(
          padding: EdgeInsets.symmetric(vertical: 6 * scale),
          child: Column(
            children: [
              Text('TOKEN NUMBER', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10 * scale, color: Colors.grey.shade700, letterSpacing: 1.5)),
              Text('TK-104', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 36 * scale, color: Colors.black, letterSpacing: 2)),
              Container(height: 2, width: 120 * scale, color: Colors.black),
            ],
          ),
        );
      case 'INVERTED_BOX':
      default:
        return Container(
          padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Text('TOKEN NUMBER', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10 * scale, color: Colors.white70, letterSpacing: 1.5)),
              SizedBox(height: 2 * scale),
              Text('104', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 40 * scale, color: Colors.white, letterSpacing: 3)),
            ],
          ),
        );
    }
  }

  Widget _buildTokenItemSummaryRow(String name, String qty, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.5 * scale),
      child: Row(
        children: [
          Expanded(flex: 7, child: Text('• $name', style: TextStyle(fontFamily: 'monospace', fontSize: 9 * scale))),
          Expanded(flex: 3, child: Text(qty, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 9.5 * scale))),
        ],
      ),
    );
  }

  // =========================================================================
  // HELPER REUSABLE WIDGETS
  // =========================================================================
  Widget _buildCardHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: primaryColor, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }

  Widget _buildCardWrapper({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildHeadingFieldWithPresets({
    required String label,
    required TextEditingController controller,
    required List<String> presets,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: _inputDecoration(hint: 'e.g. TAX INVOICE, RETAIL INVOICE, BILL OF SUPPLY'),
          onChanged: (val) {
            onChanged?.call(val);
            setState(() {});
          },
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: presets.map((p) {
            final isSelected = controller.text.trim().toUpperCase() == p.toUpperCase();
            return ActionChip(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              label: Text(p, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.white : const Color(0xFF334155))),
              backgroundColor: isSelected ? const Color(0xFF0B5CAD) : const Color(0xFFF1F5F9),
              side: BorderSide(color: isSelected ? const Color(0xFF0B5CAD) : const Color(0xFFCBD5E1)),
              onPressed: () {
                setState(() {
                  controller.text = p;
                  onChanged?.call(p);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint, {int maxLines = 1, ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: _inputDecoration(hint: hint),
          onChanged: (val) {
            onChanged?.call(val);
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildSwitch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildColorOption(String key, String label, Color color, {required String selectedKey, required ValueChanged<String> onSelect}) {
    final isSelected = selectedKey == key;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
            border: Border.all(color: isSelected ? color : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? color : Colors.black87), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11.5, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
    );
  }

  Widget _dashedDivider([double scale = 1.0]) {
    return Text(
      '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 10 * scale),
    );
  }
}
