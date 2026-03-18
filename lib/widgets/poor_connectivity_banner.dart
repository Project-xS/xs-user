import 'package:flutter/material.dart';

class PoorConnectivityBanner extends StatefulWidget {
  const PoorConnectivityBanner({super.key, this.message});

  final String? message;

  @override
  State<PoorConnectivityBanner> createState() => _PoorConnectivityBannerState();
}

class _PoorConnectivityBannerState extends State<PoorConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _showWifiIcon(double t) {
    // blink-blink-blink-wait
    return (t >= 0.00 && t < 0.08) ||
        (t >= 0.16 && t < 0.24) ||
        (t >= 0.32 && t < 0.40);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message =
        widget.message ?? 'Poor internet connectivity detected';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3D2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFA678)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final showIcon = _showWifiIcon(_controller.value);
              return Opacity(
                opacity: showIcon ? 1.0 : 0.15,
                child: child,
              );
            },
            child: Icon(
              Icons.wifi_tethering_error_rounded,
              color: colorScheme.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
