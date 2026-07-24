import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:serial_stream/app_theme.dart';

class DNSSetupScreen extends StatefulWidget {
  const DNSSetupScreen({Key? key}) : super(key: key);

  @override
  State<DNSSetupScreen> createState() => _DNSSetupScreenState();
}

class _DNSSetupScreenState extends State<DNSSetupScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final String dnsAddress = "dns.adguard.com";
  bool _isAnimationComplete = false;
  bool _isAndroidTV = false;
  bool _hasCheckedDeviceType = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedDeviceType) {
      _checkDeviceType();
      _hasCheckedDeviceType = true;
    }
  }

  void _checkDeviceType() {
    // Check for Android TV using MediaQuery (now safe to call)
    final screenSize = MediaQuery.of(context).size;
    final shortestSide = screenSize.shortestSide;
    final aspectRatio = screenSize.width / screenSize.height;

    // Android TV typically has larger screens and different aspect ratios
    _isAndroidTV =
        Platform.isAndroid && (shortestSide > 600 || aspectRatio > 1.5);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start animations
    _fadeController.forward();
    _slideController.forward().then((_) {
      if (mounted) {
        setState(() {
          _isAnimationComplete = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 600;
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.isDark ? const Color(0xFF0A0E21) : c.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 40.0 : 20.0,
                vertical: 20.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isLargeScreen ? 800 : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildHeader(isLargeScreen, c),
                      SizedBox(height: isLargeScreen ? 40 : 30),
                      _buildDeviceTypeIndicator(isLargeScreen),
                      SizedBox(height: isLargeScreen ? 20 : 15),
                      _buildProblemCard(isLargeScreen),
                      SizedBox(height: isLargeScreen ? 30 : 25),
                      _buildSolutionCard(isLargeScreen),
                      SizedBox(height: isLargeScreen ? 30 : 25),
                      _buildDNSCard(isLargeScreen),
                      SizedBox(height: isLargeScreen ? 40 : 30),
                      _buildActionButtons(isLargeScreen),
                      SizedBox(height: isLargeScreen ? 30 : 20),
                      _buildAndroidStepsGuide(isLargeScreen),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isLargeScreen, AppColors c) {
    return Column(
      children: [
        Hero(
          tag: 'Serial Stream',
          child: Container(
            width: isLargeScreen ? 120 : 100,
            height: isLargeScreen ? 120 : 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color.fromARGB(255, 232, 232, 235), Color.fromARGB(255, 234, 177, 106)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 234, 177, 106).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: CircleAvatar(
                  radius: 50.0,
                  backgroundColor: Colors.transparent,
                  child: Image.asset(
                    'asserts/logo.png',
                    width: isLargeScreen ? 120 : 100,
                    height: isLargeScreen ? 120 : 100,
                    fit: BoxFit.cover,
                  )),
            ),
          ),
        ),
        SizedBox(height: isLargeScreen ? 25 : 20),
        Text(
          'Serial Stream',
          style: TextStyle(
            fontSize: isLargeScreen ? 36 : 28,
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: isLargeScreen ? 12 : 8),
        Text(
          'Android Setup Guide',
          style: TextStyle(
            fontSize: isLargeScreen ? 18 : 16,
            color: c.textMuted,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceTypeIndicator(bool isLargeScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isAndroidTV
            ? Colors.orange.withOpacity(0.2)
            : Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isAndroidTV
              ? Colors.orange.withOpacity(0.5)
              : Colors.green.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isAndroidTV ? Icons.tv : Icons.smartphone,
            color: _isAndroidTV ? Colors.orange : Colors.green,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isAndroidTV ? 'Android TV Detected' : 'Android Phone Detected',
            style: TextStyle(
              color: _isAndroidTV ? Colors.orange : Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemCard(bool isLargeScreen) {
    return _buildGlassCard(
      isLargeScreen: isLargeScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Common Issues',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 20 : 16),
          _buildProblemItem('Videos not loading or playing'),
          _buildProblemItem('App not functioning properly'),
          _buildProblemItem('Shows and episodes not displaying'),
          _buildProblemItem('Connection timeouts or errors'),
          _buildProblemItem('Slow streaming or buffering issues'),
        ],
      ),
    );
  }

  Widget _buildProblemItem(String problem) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(
            Icons.close,
            color: Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              problem,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionCard(bool isLargeScreen) {
    return _buildGlassCard(
      isLargeScreen: isLargeScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.greenAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Simple Solution',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 20 : 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change your Android device\'s DNS settings to use AdGuard\'s private DNS server.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isLargeScreen ? 16 : 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Works on all Android versions (4.0+)',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: isLargeScreen ? 14 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDNSCard(bool isLargeScreen) {
    return _buildGlassCard(
      isLargeScreen: isLargeScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.dns,
                  color: Colors.purpleAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'DNS Address',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 20 : 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Private DNS Address:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isLargeScreen ? 14 : 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            dnsAddress,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isLargeScreen ? 18 : 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildCopyButton(isLargeScreen),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AdGuard DNS blocks ads and malware',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: isLargeScreen ? 12 : 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyButton(bool isLargeScreen) {
    return AnimatedScale(
      scale: _isAnimationComplete ? 1.0 : 0.8,
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _copyDNSAddress,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.copy,
              color: Colors.white,
              size: isLargeScreen ? 20 : 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isLargeScreen) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: isLargeScreen ? 56 : 48,
          child: ElevatedButton.icon(
            onPressed: _openAndroidDNSSettings,
            icon: Icon(
              _isAndroidTV ? Icons.tv_outlined : Icons.settings,
              color: Colors.white,
            ),
            label: Text(
              _isAndroidTV
                  ? 'Open Android TV Settings'
                  : 'Open Android Settings',
              style: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: const Color(0xFF667eea).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        SizedBox(height: isLargeScreen ? 16 : 12),
        SizedBox(
          width: double.infinity,
          height: isLargeScreen ? 56 : 48,
          child: OutlinedButton.icon(
            onPressed: _showDetailedAndroidGuide,
            icon: const Icon(Icons.help_outline),
            label: Text(
              'Step-by-Step Guide',
              style: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        if (_isAndroidTV) ...[
          SizedBox(height: isLargeScreen ? 12 : 8),
          SizedBox(
            width: double.infinity,
            height: isLargeScreen ? 48 : 44,
            child: TextButton.icon(
              onPressed: _showAndroidTVInstructions,
              icon: const Icon(Icons.tv, size: 18),
              label: const Text('Android TV Specific Guide'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                backgroundColor: Colors.orange.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAndroidStepsGuide(bool isLargeScreen) {
    return _buildGlassCard(
      isLargeScreen: isLargeScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isAndroidTV
                ? 'Quick Android TV Setup'
                : 'Quick Android Phone Setup',
            style: TextStyle(
              fontSize: isLargeScreen ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isLargeScreen ? 20 : 16),
          if (_isAndroidTV) ...[
            _buildStepItem(1, 'Navigate to Settings using your remote'),
            _buildStepItem(2, 'Go to Device Preferences → Network'),
            _buildStepItem(3, 'Select your WiFi connection'),
            _buildStepItem(4, 'Choose "Modify network"'),
            _buildStepItem(5, 'Set DNS to "Manual" and enter dns.adguard.com'),
            _buildStepItem(6, 'Save and restart your Android TV'),
          ] else ...[
            _buildStepItem(1, 'Copy the DNS address above'),
            _buildStepItem(2, 'Go to Settings → Network & Internet'),
            _buildStepItem(3, 'Tap "Private DNS" or "Advanced"'),
            _buildStepItem(4, 'Select "Private DNS provider hostname"'),
            _buildStepItem(5, 'Paste: dns.adguard.com'),
            _buildStepItem(6, 'Save settings and restart the app'),
          ],
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required bool isLargeScreen,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  void _copyDNSAddress() async {
    await Clipboard.setData(ClipboardData(text: dnsAddress));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('DNS address copied: $dnsAddress'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _openAndroidDNSSettings() async {
    try {
      // Try multiple Android settings intents
      final settingsIntents = [
        'android.settings.WIRELESS_SETTINGS',
        'android.settings.WIFI_SETTINGS',
        'android.settings.NETWORK_OPERATOR_SETTINGS',
        'android.settings.SETTINGS',
      ];

      bool launched = false;
      for (String intent in settingsIntents) {
        try {
          final uri =
              Uri.parse('android.intent.action.MAIN').replace(path: intent);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            break;
          }
        } catch (e) {
          continue;
        }
      }

      if (!launched) {
        _showAndroidSettingsInstructions();
      }
    } catch (e) {
      _showAndroidSettingsInstructions();
    }
  }

  void _showAndroidSettingsInstructions() {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          _isAndroidTV ? 'Android TV Settings' : 'Android Settings',
          style: TextStyle(color: c.textPrimary),
        ),
        content: Text(
          _isAndroidTV
              ? 'Using your remote, navigate to:\n\n'
                  '1. Settings\n'
                  '2. Device Preferences\n'
                  '3. Network\n'
                  '4. Select your WiFi\n'
                  '5. Modify network\n'
                  '6. Set DNS to Manual'
              : 'Please manually navigate to:\n\n'
                  'Settings → Network & Internet → Private DNS\n\n'
                  'Or:\n\n'
                  'Settings → Connections → More connection settings → Private DNS',
          style: TextStyle(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showAndroidTVInstructions() {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Android TV Specific Instructions',
          style: TextStyle(color: Colors.white),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Android TV DNS Setup:\n\n'
            '1. Press HOME on your remote\n'
            '2. Navigate to Settings (gear icon)\n'
            '3. Select "Device Preferences"\n'
            '4. Choose "Network"\n'
            '5. Select your WiFi network\n'
            '6. Press and hold OK, then select "Modify network"\n'
            '7. Select "Advanced options"\n'
            '8. Change "IP settings" to "Static"\n'
            '9. Set DNS 1 to: dns.adguard.com\n'
            '10. Save and restart your Android TV\n\n'
            'Note: Some Android TV versions may have slightly different menu names.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showDetailedAndroidGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'Android DNS Setup Guide',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDetailedAndroidGuide('Android 9+ (API 28+)', [
                      'Open Settings app',
                      'Go to "Network & Internet"',
                      'Tap on "Private DNS"',
                      'Select "Private DNS provider hostname"',
                      'Enter: dns.adguard.com',
                      'Save settings and test connectivity',
                    ]),
                    const SizedBox(height: 24),
                    _buildDetailedAndroidGuide('Android 7-8 (API 24-27)', [
                      'Open Settings app',
                      'Go to "Wi-Fi" or "Network & Internet"',
                      'Long press your connected WiFi network',
                      'Select "Modify network" or "Network details"',
                      'Tap "Advanced options"',
                      'Change "IP settings" to "Static"',
                      'Set DNS 1 to: dns.adguard.com',
                      'Save and reconnect to WiFi',
                    ]),
                    const SizedBox(height: 24),
                    _buildDetailedAndroidGuide('Android 4-6 (Older Versions)', [
                      'Open Settings app',
                      'Go to "Wi-Fi" settings',
                      'Long press your connected network',
                      'Select "Modify network"',
                      'Check "Show advanced options"',
                      'Change "IP settings" to "Static"',
                      'Fill in your current IP details',
                      'Set DNS 1 to: dns.adguard.com',
                      'Save changes and restart WiFi',
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedAndroidGuide(String version, List<String> steps) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.android,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                version,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
