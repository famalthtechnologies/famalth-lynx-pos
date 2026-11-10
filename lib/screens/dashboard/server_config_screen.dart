import 'dart:io' show Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:retailpos/screens/splash_screen.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../widgets/app_setup_qr_dialog.dart';
import '../settings/outlet_setup_screen.dart';
import 'cloud_migration_screen.dart';

class ServerConfigScreen extends StatefulWidget {
  final Widget? nextScreen;
  const ServerConfigScreen({super.key, this.nextScreen});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen>
    with SingleTickerProviderStateMixin {
  final _urlCtrl = TextEditingController();
  final _outletCodeCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isProcessingQr = false;

  late bool _isScanMode;
  bool _isTorchOn = false;
  bool _isFrontCamera = false;

  late final MobileScannerController _scannerController;
  late final AnimationController _laserAnimCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = AppConfig.baseUrl;
    _outletCodeCtrl.text = ""; // Keep clean to prevent pre-filling default/previous outlets

    // Default to QR Scan mode on mobile platforms (Android/iOS) and Web;
    // On Windows/Linux desktop POS, default to manual form since desktop PCs typically lack front QR cameras.
    final bool isMobileOrWeb = kIsWeb || (Platform.isAndroid || Platform.isIOS);
    _isScanMode = isMobileOrWeb;

    _scannerController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode, BarcodeFormat.all],
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimCtrl.dispose();
    _scannerController.dispose();
    _urlCtrl.dispose();
    _outletCodeCtrl.dispose();
    super.dispose();
  }

  bool get _isCustomerApp =>
      widget.nextScreen != null &&
      widget.nextScreen.runtimeType.toString().toLowerCase().contains('customer');

  void _openQrShareDialog() {
    final url = _urlCtrl.text.trim().isNotEmpty ? _urlCtrl.text.trim() : AppConfig.baseUrl;
    final outlet = _outletCodeCtrl.text.trim().isNotEmpty
        ? _outletCodeCtrl.text.trim()
        : (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter or scan a Server URL first to share."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    AppSetupQrDialog.show(
      context,
      serverUrl: url,
      outletCode: outlet,
      mode: _isCustomerApp ? AppSetupQrMode.customer : AppSetupQrMode.staff,
    );
  }

  Future<void> _handleQrDetection(BarcodeCapture capture) async {
    if (_isProcessingQr || _isLoading) return;
    if (capture.barcodes.isEmpty) return;

    final rawVal = capture.barcodes.first.rawValue;
    if (rawVal == null || rawVal.trim().isEmpty) return;

    await _processScannedData(rawVal);
  }

  Future<void> _processScannedData(String raw) async {
    if (_isProcessingQr || _isLoading) return;
    setState(() {
      _isProcessingQr = true;
      _isLoading = true;
    });

    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();

      final payload = AppConfigQrPayload.parse(raw);
      if (payload == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unrecognized QR format. Please scan a valid Store Setup QR code."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _urlCtrl.text = payload.serverUrl;
      if (payload.outletCode != null && payload.outletCode!.isNotEmpty) {
        _outletCodeCtrl.text = payload.outletCode!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "QR Detected: ${payload.serverUrl}${payload.outletCode != null ? ' (${payload.outletCode})' : ''}. Connecting...",
            ),
            backgroundColor: const Color(0xFF0284C7),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await _checkAndProceed();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Auto-config error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingQr = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndScanImage() async {
    if (_isProcessingQr || _isLoading) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      setState(() => _isLoading = true);

      final BarcodeCapture? capture = await _scannerController.analyzeImage(path);
      if (capture == null || capture.barcodes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No QR code found in selected image. Please choose a clear QR code image."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final rawVal = capture.barcodes.first.rawValue;
      if (rawVal != null && rawVal.trim().isNotEmpty) {
        await _processScannedData(rawVal);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error reading image: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAndProceed() async {
    final url = _urlCtrl.text.trim();
    final outletCode = _outletCodeCtrl.text.trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Server URL is required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String finalUrl = url;
      if (finalUrl.endsWith('/')) {
        finalUrl = finalUrl.substring(0, finalUrl.length - 1);
      }

      if (outletCode.isEmpty) {
        // No outlet code entered -> New user registration flow
        await AppConfig.saveConfig(finalUrl, []);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => widget.nextScreen ?? const OutletSetupScreen(),
          ),
          (route) => false,
        );
        return;
      }

      // Outlet code entered -> Check server for specific outlet existence securely
      final res = await ApiClient.post(
        "$finalUrl/api/public/outlet/check",
        {'outlet_code': outletCode},
      );

      if (res['success'] == true && res['exists'] == true) {
        // Outlet exists -> Save configuration and proceed to Login / Splash
        await AppConfig.saveConfig(finalUrl, [outletCode]);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Outlet '$outletCode' verified successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => widget.nextScreen ?? const SplashScreen(),
          ),
          (route) => false,
        );
      } else {
        // Outlet code not found -> Prompt registration
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Outlet code '$outletCode' not found. Proceeding to registration...",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        await AppConfig.saveConfig(finalUrl, []);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => widget.nextScreen ?? const OutletSetupScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _shouldShowCloudMigration {
    // Hide on mobile platforms (Android & iOS)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return false;
    }

    // Only show on desktop operating systems (Windows, Linux, macOS)
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    if (!isDesktop) return false;

    // Do not show when launched for companion/client apps (customer app, waiter app, rider app, retailer app, supplier app)
    if (widget.nextScreen != null) {
      final target = widget.nextScreen.runtimeType.toString().toLowerCase();
      if (target.contains('customer') ||
          target.contains('rider') ||
          target.contains('waiter') ||
          target.contains('retailer') ||
          target.contains('supplier') ||
          target.contains('captain') ||
          target.contains('billing')) {
        return false;
      }
    }

    return AppConfig.isLocalServer;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(_isScanMode ? "Auto-Connect Setup" : "System Configuration"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          // Share Store QR (Friends & Family for Customer App, or Companion App Setup for Staff)
          IconButton(
            icon: Icon(
              _isCustomerApp ? Icons.share_rounded : Icons.qr_code_2_rounded,
              color: const Color(0xFF0284C7),
            ),
            tooltip: _isCustomerApp
                ? "Share Store with Family & Friends"
                : "Share Store Setup QR",
            onPressed: _openQrShareDialog,
          ),
          // Toggle between Scanner and Manual Configuration
          IconButton(
            icon: Icon(
              _isScanMode ? Icons.tune_rounded : Icons.qr_code_scanner_rounded,
              color: const Color(0xFF475569),
            ),
            tooltip: _isScanMode ? "Manual Configuration" : "Scan Setup QR Code",
            onPressed: () {
              setState(() {
                _isScanMode = !_isScanMode;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _isScanMode ? _buildScannerView() : _buildManualFormView(),
        ),
      ),
    );
  }

  /// Modern QR Scanner view with Camera Viewfinder, Laser Animation, Torch, Image Upload & Manual Switch
  Widget _buildScannerView() {
    return Container(
      width: 440,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0284C7), size: 24),
              ),
              const SizedBox(width: 10),
              const Text(
                "Scan Store Setup QR",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Point device camera at your Store Setup QR code to configure automatically.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 20),

          // Camera Viewfinder Box
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _handleQrDetection,
                    errorBuilder: (context, error, child) {
                      return Container(
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_off_rounded, size: 48, color: Colors.amber),
                              const SizedBox(height: 10),
                              Text(
                                error.errorDetails?.message ?? "Camera unavailable on this device",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.photo_library_outlined, size: 16),
                                label: const Text("Upload QR Image Instead", style: TextStyle(fontSize: 12)),
                                onPressed: _pickAndScanImage,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Overlay Brackets & Animated Laser Line
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Stack(
                        children: [
                          // Custom 4 Corners Overlay
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ScannerCornerPainter(
                                color: const Color(0xFF0284C7),
                                cornerLength: 26,
                                strokeWidth: 3.5,
                              ),
                            ),
                          ),
                          // Moving Scan Line
                          AnimatedBuilder(
                            animation: _laserAnimCtrl,
                            builder: (context, child) {
                              return Align(
                                alignment: Alignment(0, (_laserAnimCtrl.value * 2) - 1),
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Camera Control Buttons: Torch & Camera Switch
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      radius: 20,
                      child: IconButton(
                        icon: Icon(
                          _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: _isTorchOn ? Colors.amber : Colors.white,
                          size: 18,
                        ),
                        onPressed: () async {
                          await _scannerController.toggleTorch();
                          setState(() => _isTorchOn = !_isTorchOn);
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 18),
                        onPressed: () async {
                          await _scannerController.switchCamera();
                          setState(() => _isFrontCamera = !_isFrontCamera);
                        },
                      ),
                    ),
                  ),

                  // Loading Overlay
                  if (_isLoading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.65),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              "Verifying connection...",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action 1: Upload QR Image / Screenshot
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text(
              "Upload QR Image / Screenshot",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            onPressed: _isLoading ? null : _pickAndScanImage,
          ),
          const SizedBox(height: 10),

          // Action 2: Manual Config Option Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF475569)),
            label: const Text(
              "Manual Server Configuration",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF334155)),
            ),
            onPressed: () {
              setState(() => _isScanMode = false);
            },
          ),
          const SizedBox(height: 12),

          // Share Store QR Option
          Center(
            child: TextButton.icon(
              icon: Icon(
                _isCustomerApp ? Icons.family_restroom_rounded : Icons.share_rounded,
                size: 16,
                color: const Color(0xFF0284C7),
              ),
              label: Text(
                _isCustomerApp
                    ? "Share Store with Family & Friends to Purchase"
                    : "Share Server Details via QR",
                style: const TextStyle(
                  color: Color(0xFF0284C7),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              onPressed: _openQrShareDialog,
            ),
          ),
        ],
      ),
    );
  }

  /// Traditional manual entry view with Server URL & Outlet Code text fields
  Widget _buildManualFormView() {
    final bool canProceed = _urlCtrl.text.trim().isNotEmpty && !_isLoading;

    return Container(
      width: 450,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Switch to Scan Mode Pill
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _isScanMode = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF0284C7)),
                    SizedBox(width: 6),
                    Text(
                      "Switch to QR Scanner",
                      style: TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Icon(Icons.dns_rounded, size: 48, color: Color(0xFF0284C7)),
          const SizedBox(height: 14),
          const Text(
            "Terminal Setup",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            "Configure server URL and enter your outlet code manually to connect.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Server URL Field
          TextField(
            controller: _urlCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: "Server URL",
              hintText: "http://192.168.1.50:3000",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 18),

          // Outlet Code Field (Optional)
          TextField(
            controller: _outletCodeCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: "Outlet Code (Optional)",
              hintText: "e.g. NYC_STORE (Leave blank for new store)",
              helperText:
                  "Enter your outlet code if you have one, or leave blank to register a new store.",
              helperMaxLines: 2,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.storefront_rounded),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: canProceed ? _checkAndProceed : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text("Verifying..."),
                      ],
                    )
                  : Text(
                      _outletCodeCtrl.text.trim().isNotEmpty
                          ? "Verify & Connect Outlet"
                          : "Save & Register New Store",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Alternate Action: Upload QR Screenshot in manual view
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            icon: const Icon(Icons.photo_library_outlined, size: 17),
            label: const Text(
              "Upload QR Image to Auto-Fill",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _isLoading ? null : _pickAndScanImage,
          ),
          const SizedBox(height: 8),

          // Share Store QR Option
          Center(
            child: TextButton.icon(
              icon: Icon(
                _isCustomerApp ? Icons.family_restroom_rounded : Icons.share_rounded,
                size: 16,
                color: const Color(0xFF0284C7),
              ),
              label: Text(
                _isCustomerApp
                    ? "Share Store with Family & Friends to Purchase"
                    : "Share Server Details via QR",
                style: const TextStyle(
                  color: Color(0xFF0284C7),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              onPressed: _openQrShareDialog,
            ),
          ),

          if (_shouldShowCloudMigration) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.rocket_launch_rounded, color: Color(0xFF0284C7), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Working Offline? Migrate to Cloud",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Transfer all your local products, inventory, customers and billing records to your online server with 1 click.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CloudMigrationScreen()),
                      );
                    },
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text(
                      "Launch 1-Click Migration Wizard",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Custom painter for camera viewfinder corner brackets
class _ScannerCornerPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;

  _ScannerCornerPainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final l = cornerLength;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), Offset(l, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, l), paint);

    // Top-Right
    canvas.drawLine(Offset(w, 0), Offset(w - l, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, l), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, h), Offset(l, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - l), paint);

    // Bottom-Right
    canvas.drawLine(Offset(w, h), Offset(w - l, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - l), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
