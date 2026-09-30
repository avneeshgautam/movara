package com.avneesh.movara_app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: the health plugin casts the
// host activity to androidx ComponentActivity when it attaches at startup, so
// a plain FlutterActivity crashed the app on launch (ClassCastException).
class MainActivity : FlutterFragmentActivity()
