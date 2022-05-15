#ifndef FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_

#pragma warning(disable : 4458) // declaration hides class member (used 

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <windns.h>

#pragma comment(lib, "dnsapi.lib")


namespace nsd_windows {

	struct BrowseContext;

	class NsdWindowsPlugin : public flutter::Plugin {
	public:
		static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

		NsdWindowsPlugin(std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel);
		virtual ~NsdWindowsPlugin();

		// Disallow copy and assign.
		NsdWindowsPlugin(const NsdWindowsPlugin&) = delete;
		NsdWindowsPlugin& operator=(const NsdWindowsPlugin&) = delete;

		void OnServiceDiscovered(const std::string& handle, const DWORD status, DNS_RECORD* records);
		void OnServiceRegistered(const std::string& handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance);

	private:

		std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel;
		std::map<std::string, std::unique_ptr<BrowseContext>> discoveryContextMap;
		std::map<std::string, std::unique_ptr<BrowseContext>> registerContextMap;

		void HandleMethodCall(
			const flutter::MethodCall<flutter::EncodableValue>& method_call,
			std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		void StartDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void StopDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Register(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Resolve(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Unregister(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);

	};

	void DnsServiceBrowseCallback(const DWORD status, void* context, DNS_RECORD* records);
	void DnsServiceRegisterCallback(const DWORD status, void* context, PDNS_SERVICE_INSTANCE pInstance);

	struct BrowseContext {

		BrowseContext(NsdWindowsPlugin* const plugin, std::string& handle);
		virtual ~BrowseContext();

		NsdWindowsPlugin* const plugin;
		const std::string handle;
		DNS_SERVICE_CANCEL canceller;
	};

}  // namespace nsd_windows

#endif  // FLUTTER_PLUGIN_NSD_WINDOWS_PLUGIN_H_
