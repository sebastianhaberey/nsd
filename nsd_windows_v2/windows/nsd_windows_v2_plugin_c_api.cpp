#include "include/nsd_windows_v2/nsd_windows_v2_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "nsd_windows_v2_plugin.h"

void NsdWindowsV2PluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  nsd_windows_v2::NsdWindowsV2Plugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
