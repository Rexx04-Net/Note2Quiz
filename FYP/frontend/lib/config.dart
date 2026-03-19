import 'package:flutter/foundation.dart'; // ✅ THIS is what was missing!

// AUTOMATICALLY DETECT CORRECT ADDRESS
// 1. Web uses localhost
// 2. Android Emulator uses 10.0.2.2
// 3. iOS Simulator uses localhost

final String baseUrl = kIsWeb 
    ? 'http://127.0.0.1:5000' // (Change to 'http://localhost:5000' if 127.0.0.1 still gives network errors)
    : 'http://10.0.2.2:5000';