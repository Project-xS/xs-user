import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:xs_user/api_service.dart';

class QrDisplayScreen extends StatefulWidget {
  final int orderId;

  const QrDisplayScreen({super.key, required this.orderId});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  Uint8List? _qrBytes;
  bool _isLoading = true;
  String? _error;
  double? _previousBrightness;

  @override
  void initState() {
    super.initState();
    _boostBrightness();
    _fetchQr();
  }

  @override
  void dispose() {
    _restoreBrightness();
    super.dispose();
  }

  Future<void> _boostBrightness() async {
    try {
      _previousBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (_) {
      // Brightness control not available — continue without it
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      if (_previousBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_previousBrightness!);
      } else {
        await ScreenBrightness().resetScreenBrightness();
      }
    } catch (_) {
      // Ignore
    }
  }

  Future<void> _fetchQr() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bytes = await ApiService().getOrderQrCode(widget.orderId);
      if (mounted) {
        setState(() {
          _qrBytes = bytes;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Order #${widget.orderId}',
          style: GoogleFonts.montserrat(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _error != null
            ? _buildErrorView()
            : _buildQrView(),
      ),
    );
  }

  Widget _buildQrView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_rounded, size: 32, color: Colors.grey[600]),
          const SizedBox(height: 12),
          Text(
            'Show this to the merchant',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'They will scan this QR code to verify your order',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.memory(
              _qrBytes!,
              width: 280,
              height: 280,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _fetchQr,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(
              'Regenerate QR',
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchQr,
            icon: const Icon(Icons.refresh),
            label: Text(
              'Retry',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A3A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
