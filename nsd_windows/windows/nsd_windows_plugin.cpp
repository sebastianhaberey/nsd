#include "nsd_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include "nsd_error.h"
#include "utilities.h"

#include <iostream>
#include <memory>
#include <sstream>
#include <vector>

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
		auto context = std::make_unique<BrowseContext>(this, handle);

		DNS_SERVICE_BROWSE_REQUEST request = {
			.Version = DNS_QUERY_REQUEST_VERSION1,
			.QueryName = serviceTypeW.c_str(),
			.pBrowseCallback = &DnsServiceBrowseCallback,
			.pQueryContext = context.get(),
		};

		auto status = DnsServiceBrowse(&request, &context->canceller);

		if (status != DNS_REQUEST_PENDING) {
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), GetLastErrorMessage());
			return;
		}

		discoveryContextMap[handle] = std::move(context);
		methodChannel->InvokeMethod("onDiscoveryStartSuccessful", Serialize({ SerializeHandle(handle) }));
		result->Success();
	}

	void NsdWindowsPlugin::StopDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		auto handle = UnwrapOrThrow(DeserializeHandle(arguments), ErrorCause::ILLEGAL_ARGUMENT, "Handle cannot be null");

		auto it = discoveryContextMap.find(handle);
		if (it == discoveryContextMap.end()) {
			result->Error(ToErrorCode(ErrorCause::ILLEGAL_ARGUMENT), "Unknown handle");
			return;
		}

		auto status = DnsServiceBrowseCancel(&it->second.get()->canceller);
		discoveryContextMap.erase(handle);

		if (status != ERROR_SUCCESS) {
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), GetLastErrorMessage());
			return;
		}

		result->Success();
	}

	void NsdWindowsPlugin::Register(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		auto handle = UnwrapOrThrow(DeserializeHandle(arguments), ErrorCause::ILLEGAL_ARGUMENT, "Handle cannot be null");
		auto serviceName = UnwrapOrThrow(DeserializeServiceName(arguments), ErrorCause::ILLEGAL_ARGUMENT, "Service name cannot be null");
		auto serviceType = UnwrapOrThrow(DeserializeServiceType(arguments), ErrorCause::ILLEGAL_ARGUMENT, "Service type cannot be null");
		auto servicePort = UnwrapOrThrow(DeserializeServicePort(arguments), ErrorCause::ILLEGAL_ARGUMENT, "Service port cannot be null");

		auto serviceNameW = ToUtf16(serviceName) + L"." + ToUtf16(serviceType) + L".local";
		std::wstring hostNameW(L"localhost");

		PDNS_SERVICE_INSTANCE pServiceInstance = DnsServiceConstructInstance(
			serviceNameW.c_str(), // PCWSTR pServiceName
			hostNameW.c_str(), // PCWSTR pHostName
			nullptr, // PIP4_ADDRESS pIp4 (optional)
			nullptr, // PIP6_ADDRESS pIp6 (optional)
			static_cast<WORD>(servicePort), // WORD wPort
			0, // WORD wPriority
			0, // WORD wWeight
			0, // DWORD dwPropertiesCount
			nullptr, // PCWSTR* keys
			nullptr // PCWSTR* values
		);

		auto context = std::make_unique<BrowseContext>(this, handle);

		DNS_SERVICE_REGISTER_REQUEST request = {
			.Version = DNS_QUERY_REQUEST_VERSION1,
			.InterfaceIndex = 0,
			.pServiceInstance = pServiceInstance,
			.pRegisterCompletionCallback = &DnsServiceRegisterCallback,
			.pQueryContext = context.get(),
			.unicastEnabled = false,
		};

		auto status = DnsServiceRegister(&request, &context->canceller);
		DnsServiceFreeInstance(pServiceInstance);

		if (status != DNS_REQUEST_PENDING) {
			// apparently DnsServiceRegister doesn't always set the correct error code,
			// e.g. returns ERROR_INVALID_PARAMETER but GetLastError() returns 0
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), GetErrorMessage(status));
			return;
		}

		registerContextMap[handle] = std::move(context);
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

			auto name = ToUtf8(record->pName); // "_http._tcp.local"
			auto serviceType = name.substr(0, name.rfind('.'));
			auto serviceName = ToUtf8(record->Data.PTR.pNameHost); // "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"

			methodChannel->InvokeMethod("onServiceDiscovered", Serialize({
					SerializeHandle(handle),
					SerializeServiceType(serviceType),
					SerializeServiceName(serviceName),
				}));

			// TODO TXT
		}
	}

	void NsdWindowsPlugin::OnServiceRegistered(const std::string& handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance)
	{
		auto components = Split(ToUtf8(pInstance->pszInstanceName), '.'); // "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"

		auto serviceName = components.at(0);
		auto serviceType = components.at(1) + "." + components.at(2);
		auto servicePort = pInstance->wPort;
		auto serviceHost = ToUtf8(pInstance->pszHostName);

		methodChannel->InvokeMethod("onRegistrationSuccessful", Serialize({
				SerializeHandle(handle),
				SerializeServiceType(serviceType),
				SerializeServiceName(serviceName),
				SerializeServicePort(servicePort),
				SerializeServiceHost(serviceHost),
			}));
	}

	void DnsServiceBrowseCallback(const DWORD status, void* context, DNS_RECORD* records)
	{
		BrowseContext& browseContext = *static_cast<BrowseContext*>(context);
		browseContext.plugin->OnServiceDiscovered(browseContext.handle, status, records);
	}

	void DnsServiceRegisterCallback(const DWORD status, void* context, PDNS_SERVICE_INSTANCE pInstance)
	{
		BrowseContext& browseContext = *static_cast<BrowseContext*>(context);
		browseContext.plugin->OnServiceRegistered(browseContext.handle, status, pInstance);
	}

	BrowseContext::BrowseContext(NsdWindowsPlugin* const plugin, std::string& handle) : plugin(plugin), handle(handle), canceller()
	{
	}

	BrowseContext::~BrowseContext()
	{
	}

}  // namespace nsd_windows
