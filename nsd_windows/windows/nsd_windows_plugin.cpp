#include "nsd_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include "nsd_error.h"
#include "utilities.h"

#include <memory>
#include <sstream>
#include <iostream>

namespace nsd_windows {

	// static
	void NsdWindowsPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows* registrar) {
		auto methodChannel =
			std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
				registrar->messenger(), "com.haberey/nsd",
				&flutter::StandardMethodCodec::GetInstance());

		auto nsdWindowsPlugin = std::make_unique<NsdWindowsPlugin>(std::move(methodChannel));
		registrar->AddPlugin(std::move(nsdWindowsPlugin));
	}

	NsdWindowsPlugin::NsdWindowsPlugin(std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel) {
		this->methodChannel = std::move(methodChannel);
		this->methodChannel->SetMethodCallHandler(
			[plugin = this](const auto& call, auto result) { plugin->HandleMethodCall(call, std::move(result));
			});
	}

	NsdWindowsPlugin::~NsdWindowsPlugin() {}

	void NsdWindowsPlugin::HandleMethodCall(
		const flutter::MethodCall<flutter::EncodableValue>& methodCall,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

		const auto& method_name = methodCall.method_name();

		try {
			const flutter::EncodableMap& arguments =
				std::get<flutter::EncodableMap>(*methodCall.arguments());

			if (method_name == "startDiscovery") {
				StartDiscovery(arguments, result);
			}
			else if (method_name == "stopDiscovery") {
				StopDiscovery(arguments, result);
			}
			else if (method_name == "register") {
				Register(arguments, result);
			}
			else if (method_name == "resolve") {
				Resolve(arguments, result);
			}
			else if (method_name == "unregister") {
				Unregister(arguments, result);
			}
			else {
				result->NotImplemented();
			}
		}
		catch (NsdError e) {
			result->Error(ToErrorCode(e.errorCause), e.what());
		}
		catch (std::exception e) {
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), e.what());
		}
	}

	void NsdWindowsPlugin::StartDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		auto handle = UnwrapOrThrow(DeserializeHandle(arguments), ErrorCause::ILLEGAL_ARGUMENT, "Handle cannot be null");
		auto serviceType = UnwrapOrThrow(DeserializeServiceType(arguments), ErrorCause::ILLEGAL_ARGUMENT, "Service type cannot be null");
		auto serviceTypeW = ToUtf16(serviceType);
		auto browseContext = std::make_unique<BrowseContext>(this, handle);

		DNS_SERVICE_BROWSE_REQUEST request = {
			.Version = DNS_QUERY_REQUEST_VERSION1,
			.QueryName = serviceTypeW.c_str(),
			.pBrowseCallback = &DnsServiceBrowseCallback,
			.pQueryContext = browseContext.get(),
		};

		auto status = DnsServiceBrowse(&request, &browseContext->canceller);

		if (status != DNS_REQUEST_PENDING) {
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), GetLastErrorMessage());
			return;
		}

		browseContextMap[handle] = std::move(browseContext);
		methodChannel->InvokeMethod("onDiscoveryStartSuccessful", Serialize({ SerializeHandle(handle) }));
		result->Success();
	}

	void NsdWindowsPlugin::StopDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		auto handle = UnwrapOrThrow(DeserializeHandle(arguments), ErrorCause::ILLEGAL_ARGUMENT, "Handle cannot be null");

		auto it = browseContextMap.find(handle);
		if (it == browseContextMap.end()) {
			result->Error(ToErrorCode(ErrorCause::ILLEGAL_ARGUMENT), "Unknown handle");
			return;
		}

		auto status = DnsServiceBrowseCancel(&it->second.get()->canceller);

		if (status != ERROR_SUCCESS) {
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), GetLastErrorMessage());
			return;
		}

		result->Success();
	}

	void NsdWindowsPlugin::Register(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		result->Success();
	}

	void NsdWindowsPlugin::Resolve(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		result->Success();
	}

	void NsdWindowsPlugin::Unregister(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		result->Success();
	}

	void NsdWindowsPlugin::OnServiceDiscovered(const std::string& handle, const DWORD status, DNS_RECORD* records)
	{
		if (status != ERROR_SUCCESS) {
			return;
		}

		for (auto record = records; record; record = record->pNext) {

			if (record->wType != DNS_TYPE_PTR) {
				continue;
			}

			auto name = ToUtf8(record->pName); // Name: "_http._tcp.local"
			auto serviceType = name.substr(0, name.rfind('.'));
			auto serviceName = ToUtf8(record->Data.PTR.pNameHost); // NameHost: "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"

			methodChannel->InvokeMethod("onServiceDiscovered", Serialize({
					SerializeHandle(handle),
					SerializeServiceType(serviceType),
					SerializeServiceName(serviceName),
				}));

			// TODO TXT
		}
	}

	void DnsServiceBrowseCallback(const DWORD status, void* context, DNS_RECORD* records)
	{
		BrowseContext& browseContext = *static_cast<BrowseContext*>(context);
		browseContext.plugin->OnServiceDiscovered(browseContext.handle, status, records);
	}

	BrowseContext::BrowseContext(NsdWindowsPlugin* const plugin, std::string& handle) : plugin(plugin), handle(handle), canceller()
	{
	}

	BrowseContext::~BrowseContext()
	{
	}

}  // namespace nsd_windows
