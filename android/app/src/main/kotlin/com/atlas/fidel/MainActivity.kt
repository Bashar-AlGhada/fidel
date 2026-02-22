package com.atlas.fidel

import com.atlas.fidel.system.SystemChannels
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  private var systemChannels: SystemChannels? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    systemChannels = SystemChannels(this).also { it.register(flutterEngine) }
  }

  override fun onDestroy() {
    systemChannels?.dispose()
    systemChannels = null
    super.onDestroy()
  }
}
