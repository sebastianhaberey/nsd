#ifndef FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_

#pragma warning(disable : 4458) // declaration hides class member (used 

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>


namespace nsd_windows {

	class NsdWindowsPlugin : public flutter::Plugin {
	public:
		static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

		NsdWindowsPlugin(std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel);
		virtual ~NsdWindowsPlugin();

		// Disallow copy and assign.
		NsdWindowsPlugin(const NsdWindowsPlugin&) = delete;
		NsdWindowsPlugin& operator=(const NsdWindowsPlugin&) = delete;

	private:

		static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
			methodChannel;

		void HandleMethodCall(
			const flutter::MethodCall<flutter::EncodableValue>& method_call,
			std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		void StartDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void StopDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Register(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Resolve(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Unregister(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
	};

}  // namespace nsd_windows

#endif  // FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_
