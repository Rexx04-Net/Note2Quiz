import 'package:flutter/foundation.dart';

// AUTOMATICALLY DETECT CORRECT ADDRESS FOR ALL PLATFORMS:
// 1. Web on PC: uses http://127.0.0.1:5000
// 2. Web on iPhone / iPad / Other PC: automatically uses the current host IP (e.g. http://192.168.x.x:5000 or http://172.20.10.4:5000)
// 3. Android Emulator: uses http://10.0.2.2:5000
// 4. Physical Mobile Device (Native): uses PC LAN IP or localhost
String getBaseUrl() {
  if (kIsWeb) {
    final host = Uri.base.host;
    if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
      return 'http://$host:5000';
    }
    return 'http://127.0.0.1:5000';
  }
  return 'http://10.0.2.2:5000';
}

final String baseUrl = getBaseUrl();