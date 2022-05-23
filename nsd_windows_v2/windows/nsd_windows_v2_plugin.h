#ifndef FLUTTER_PLUGIN_NSD_WINDOWS_V2_PLUGIN_H_
#define FLUTTER_PLUGIN_NSD_WINDOWS_V2_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace nsd_windows_v2 {

class NsdWindowsV2Plugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  NsdWindowsV2Plugin();

  virtual ~NsdWindowsV2Plugin();

  // Disallow copy and assign.
  NsdWindowsV2Plugin(const NsdWindowsV2Plugin&) = delete;
  NsdWindowsV2Plugin& operator=(const NsdWindowsV2Plugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace nsd_windows_v2

#endif  // FLUTTER_PLUGIN_NSD_WINDOWS_V2_PLUGIN_H_
