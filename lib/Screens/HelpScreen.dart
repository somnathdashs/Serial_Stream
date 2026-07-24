import 'package:flutter/material.dart';
import 'package:serial_stream/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text("Help Guide"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: c.primary.withValues(alpha: 0.3), width: 2),
                ),
                child: Icon(
                  Icons.cloud_off,
                  size: 60,
                  color: c.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Trouble Connecting to the Server",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You might face problems like no show loading, no image loading, or a server error message.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: c.textMuted),
              ),
              const SizedBox(height: 24),
              _buildSectionCard(
                c,
                icon: Icons.wifi_off,
                iconColor: c.primary,
                title: "Quick Fix",
                children: [
                  _BulletPoint(
                    text: "Turn off your internet for a while (10 seconds) and then turn it back on.",
                    color: c.textMuted,
                  ),
                  _BulletPoint(
                    text: "For Wi-Fi, turn off your gateway device (turn off the Wi-Fi switch) and turn it back on.",
                    color: c.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                c,
                icon: Icons.alarm,
                iconColor: Colors.amber,
                title: "If the problem persists",
                children: [
                  _BulletPoint(
                    text: "The server might really be down. Please wait for 12 hours and check the app again.",
                    color: c.textMuted,
                  ),
                  _BulletPoint(
                    text: "If the problem continues, please contact us through 'Feedback'.",
                    color: c.primary,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(AppColors c, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  final Color color;

  const _BulletPoint({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("•", style: TextStyle(fontSize: 18, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, color: color, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
