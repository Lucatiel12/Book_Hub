import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

typedef OfflineCallback = void Function(bool isOffline);

class OfflineBanner extends StatefulWidget {
  final OfflineCallback? onStatusChanged;

  const OfflineBanner({super.key, this.onStatusChanged});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((status) {
      final offline = status == ConnectivityResult.none;
      setState(() => _isOffline = offline);

      if (widget.onStatusChanged != null) {
        widget.onStatusChanged!(offline);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.redAccent,
      padding: const EdgeInsets.all(8),
      child: const Text(
        "You are offline. Some features may not work.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
