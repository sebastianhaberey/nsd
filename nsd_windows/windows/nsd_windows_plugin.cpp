#include "nsd_windows_plugin.h"

#include "nsd_error.h"
#include "utilities.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <windows.h>

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

		auto context = std::make_unique<BrowseContext>();
		context->plugin = this;
		context->handle = handle;
		context->serviceType = ToUtf16(serviceType) + L".local";
		context->request.Version = DNS_QUERY_REQUEST_VERSION1;
		context->request.InterfaceIndex = 0;
		context->request.QueryName = context->serviceType.c_str();
		context->request.pBrowseCallback = &DnsServiceBrowseCallback;
		context->request.pQueryContext = context.get();

		auto status = DnsServiceBrowse(&context->request, &context->canceller);

		if (status != DNS_REQUEST_PENDING) {
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), GetErrorMessage(status));
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
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), GetErrorMessage(status));
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

		auto context = std::make_unique<RegisterContext>();
		context->plugin = this;
		context->handle = handle;
		context->serviceName = ToUtf16(serviceName) + L"." + ToUtf16(serviceType) + L".local";  // TODO this is only here so it doesn't get destroyed
		context->hostName = L"localhost"; // TODO this is only here so it doesn't get destroyed

		// see https://docs.microsoft.com/en-us/windows/win32/api/windns/nf-windns-dnsserviceconstructinstance

		PDNS_SERVICE_INSTANCE pServiceInstance = DnsServiceConstructInstance(
			context->serviceName.c_str(), // PCWSTR pServiceName
			context->hostName.c_str(), // PCWSTR pHostName
			nullptr, // PIP4_ADDRESS pIp4 (optional)
			nullptr, // PIP6_ADDRESS pIp6 (optional)
			static_cast<WORD>(servicePort), // WORD wPort
			0, // WORD wPriority
			0, // WORD wWeight
			0, // DWORD dwPropertiesCount
			nullptr, // PCWSTR* keys
			nullptr // PCWSTR* values
		);

		// TODO TXT

		context->request.Version = DNS_QUERY_REQUEST_VERSION1;
		context->request.InterfaceIndex = 0;
		context->request.pServiceInstance = pServiceInstance;
		context->request.pRegisterCompletionCallback = &DnsServiceRegisterCallback;
		context->request.pQueryContext = context.get();
		context->request.unicastEnabled = false;

		auto status = DnsServiceRegister(&context->request, &context->canceller);

		if (status != DNS_REQUEST_PENDING) {
			// apparently DnsServiceRegister doesn't always set the correct error code,
			// e.g. returns ERROR_INVALID_PARAMETER but GetLastError() returns 0
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), GetErrorMessage(status));
			DnsServiceFreeInstance(pServiceInstance);
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
		auto handle = UnwrapOrThrow(DeserializeHandle(arguments), ErrorCause::ILLEGAL_ARGUMENT, "Handle cannot be null");
		auto& context = registerContextMap.at(handle);
		auto status = DnsServiceDeRegister(&context->request, nullptr);

		DnsServiceFreeInstance(context->request.pServiceInstance);

		if (status != DNS_REQUEST_PENDING) {
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), GetErrorMessage(status));
			return;
		}

		result->Success();
	}

	void NsdWindowsPlugin::OnServiceDiscovered(const std::string& handle, const DWORD status, PDNS_RECORD records)
	{
		std::cout << GetTimeNow() << " " << "OnServiceDiscovered()" << std::endl;

		if (status != ERROR_SUCCESS) {
			std::cout << GetTimeNow() << " " << "OnServiceDiscovered(): ERROR: " << GetErrorMessage(status) << std::endl;
			DnsRecordListFree(records, DnsFreeRecordList);
			return;
		}

		for (auto record = records; record; record = record->pNext) {

			if (record->wType != DNS_TYPE_PTR) {
				// seen: DNS_TYPE_A (0x0001), DNS_TYPE_TEXT (0x0010), DNS_TYPE_AAAA (0x001c), DNS_TYPE_SRV (0x0021)
				std::cout << GetTimeNow() << " " << "OnServiceDiscovered(): skipping record type 0x" << std::hex << record->wType << std::endl;
				continue;
			}

			// record properties see https://docs.microsoft.com/en-us/windows/win32/api/windns/ns-windns-dns_recordw

			auto name = ToUtf8(record->pName); // "_http._tcp.local"
			auto serviceType = name.substr(0, name.rfind('.'));
			auto serviceName = ToUtf8(record->Data.PTR.pNameHost); // "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"
			std::cout << GetTimeNow() << " " << "OnServiceDiscovered(): processing record for " 
				<< serviceName << ", flags: " << std::hex << record->Flags.DW << ", TTL: " << record->dwTtl << std::endl;

			methodChannel->InvokeMethod("onServiceDiscovered", Serialize({
					SerializeHandle(handle),
					SerializeServiceType(serviceType),
					SerializeServiceName(serviceName),
				}));

			// TODO TXT
		}

		// must be deleted as described here: https://docs.microsoft.com/en-us/windows/win32/api/windns/nc-windns-dns_service_browse_callback
		DnsRecordListFree(records, DnsFreeRecordList);
	}

	void NsdWindowsPlugin::OnServiceRegistered(const std::string& handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance)
	{
		if (status != ERROR_SUCCESS) {
			std::cout << "OnServiceRegistered(): ERROR: " << GetErrorMessage(status) << std::endl;
			return;
		}

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

	void DnsServiceBrowseCallback(const DWORD status, PVOID context, PDNS_RECORD records)
	{
		BrowseContext& browseContext = *static_cast<BrowseContext*>(context);
		browseContext.plugin->OnServiceDiscovered(browseContext.handle, status, records);
	}

	void DnsServiceRegisterCallback(const DWORD status, PVOID context, PDNS_SERVICE_INSTANCE pInstance)
	{
		RegisterContext& registerContext = *static_cast<RegisterContext*>(context);
		registerContext.plugin->OnServiceRegistered(registerContext.handle, status, pInstance);
	}

}  // namespace nsd_windows
