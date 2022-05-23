#ifndef FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace nsd_windows {

class NsdWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  NsdWindowsPlugin();

  virtual ~NsdWindowsPlugin();

  // Disallow copy and assign.
  NsdWindowsPlugin(const NsdWindowsPlugin&) = delete;
  NsdWindowsPlugin& operator=(const NsdWindowsPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace nsd_windows

#endif  // FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_
