import 'package:flutter/foundation.dart';

// AUTOMATICALLY DETECT CORRECT ADDRESS FOR ALL PLATFORMS:
// 1. Local development on PC: http://127.0.0.1:5000
// 2. Local Wi-Fi on Phone (LAN IP): http://<IP>:5000
// 3. Android Emulator: http://10.0.2.2:5000
// 4. Live Cloud Production Web (Vercel / Firebase): points to Render Cloud Backend
const String cloudBackendUrl = 'https://note2quiz-nrc3.onrender.com';

String getBaseUrl() {
  if (kIsWeb) {
    final host = Uri.base.host;
    // Localhost development
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      return 'http://127.0.0.1:5000';
    }
    // Local Area Network (Wi-Fi test via phone IP e.g. 10.10.0.7 or 192.168.x.x)
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host)) {
      return 'http://$host:5000';
    }
    // Production Cloud Domain (Vercel, Firebase, Custom domain)
    return cloudBackendUrl;
  }
  return 'http://10.0.2.2:5000';
}

final String baseUrl = getBaseUrl();