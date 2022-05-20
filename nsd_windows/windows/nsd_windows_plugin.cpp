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

	void NsdWindowsPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
		auto methodChannel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
			registrar->messenger(), "com.haberey/nsd", &flutter::StandardMethodCodec::GetInstance());
		auto nsdWindowsPlugin = std::make_unique<NsdWindowsPlugin>(std::move(methodChannel));
		registrar->AddPlugin(std::move(nsdWindowsPlugin));
	}

	NsdWindowsPlugin::NsdWindowsPlugin(std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel) {
		this->methodChannel = std::move(methodChannel);
		this->methodChannel->SetMethodCallHandler(
			[plugin = this](const auto& call, auto result) { plugin->HandleMethodCall(call, result);
			});
	}

	NsdWindowsPlugin::~NsdWindowsPlugin() {}

	void NsdWindowsPlugin::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& methodCall,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result) {

		const auto& method_name = methodCall.method_name();

		try {
			const flutter::EncodableMap& arguments = std::get<flutter::EncodableMap>(*methodCall.arguments());

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
		const auto handle = Deserialize<std::string>(arguments, "handle");
		const auto serviceType = Deserialize<std::string>(arguments, "service.type");

		auto context = std::make_unique<DiscoveryContext>();
		context->plugin = this;
		context->handle = handle;

		auto& request = context->request;
		request.Version = DNS_QUERY_REQUEST_VERSION1;
		request.InterfaceIndex = 0;
		request.QueryName = CreateUtf16CString(serviceType + ".local");
		request.pBrowseCallback = &DnsServiceBrowseCallback;
		request.pQueryContext = context.get();

		const auto status = DnsServiceBrowse(&request, &context->canceller);

		if (status != DNS_REQUEST_PENDING) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		discoveryContextMap[handle] = std::move(context);
		methodChannel->InvokeMethod("onDiscoveryStartSuccessful", CreateMethodResult({ { "handle", handle } }));
		result->Success();
	}

	void NsdWindowsPlugin::StopDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		const auto handle = Deserialize<std::string>(arguments, "handle");

		const auto it = discoveryContextMap.find(handle);
		if (it == discoveryContextMap.end()) {
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, "Unknown handle");
		}

		auto& context = *it->second.get();

		const auto status = DnsServiceBrowseCancel(&context.canceller);
		discoveryContextMap.erase(it);

		if (status != ERROR_SUCCESS) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		methodChannel->InvokeMethod("onDiscoveryStopSuccessful", CreateMethodResult({ { "handle", handle } }));
		result->Success();
	}

	void NsdWindowsPlugin::Resolve(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		const auto handle = Deserialize<std::string>(arguments, "handle");
		const auto serviceName = Deserialize<std::string>(arguments, "service.name");
		const auto serviceType = Deserialize<std::string>(arguments, "service.type");

		auto context = std::make_unique<ResolveContext>();
		context->plugin = this;
		context->handle = handle;

		auto& request = context->request;
		request.Version = DNS_QUERY_REQUEST_VERSION1;
		request.InterfaceIndex = 0;
		request.QueryName = CreateUtf16CString(serviceName + "." + serviceType + ".local");
		request.pResolveCompletionCallback = &DnsServiceResolveCallback;
		request.pQueryContext = context.get();

		const auto status = DnsServiceResolve(&request, &context->canceller);

		if (status != DNS_REQUEST_PENDING) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		resolveContextMap[handle] = std::move(context);
		result->Success();
	}

	void NsdWindowsPlugin::Register(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		const auto handle = Deserialize<std::string>(arguments, "handle");
		const auto serviceName = Deserialize<std::string>(arguments, "service.name");
		const auto serviceType = Deserialize<std::string>(arguments, "service.type");
		const auto servicePort = Deserialize<int>(arguments, "service.port");

		const auto computerName = GetComputerName();

		auto context = std::make_unique<RegisterContext>();
		context->plugin = this;
		context->handle = handle;

		// see https://docs.microsoft.com/en-us/windows/win32/api/windns/nf-windns-dnsserviceconstructinstance

		const PDNS_SERVICE_INSTANCE pServiceInstance = DnsServiceConstructInstance(
			CreateUtf16CString(serviceName + "." + serviceType + ".local"), // PCWSTR pServiceName
			CreateUtf16CString(computerName + L".local"), // PCWSTR pHostName
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

		auto& request = context->request;
		request.Version = DNS_QUERY_REQUEST_VERSION1;
		request.InterfaceIndex = 0;
		request.pServiceInstance = pServiceInstance;
		request.pRegisterCompletionCallback = &DnsServiceRegisterCallback;
		request.pQueryContext = context.get();
		request.unicastEnabled = false;

		const auto status = DnsServiceRegister(&request, &context->canceller);

		if (status != DNS_REQUEST_PENDING) {
			DnsServiceFreeInstance(pServiceInstance);
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		registerContextMap[handle] = std::move(context);
		result->Success();
	}

	void NsdWindowsPlugin::Unregister(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		const auto handle = Deserialize<std::string>(arguments, "handle");

		const auto it = registerContextMap.find(handle);
		if (it == registerContextMap.end()) {
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, "Unknown handle");
		}

		auto& context = *it->second.get();
		auto& request = context.request;

		request.pRegisterCompletionCallback = &DnsServiceUnregisterCallback; // switch callback for request reuse

		const auto status = DnsServiceDeRegister(&request, nullptr);

		if (status != DNS_REQUEST_PENDING) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		result->Success();
	}

	void NsdWindowsPlugin::OnServiceDiscovered(const std::string handle, const DWORD status, PDNS_RECORD records)
	{
		//std::cout << GetTimeNow() << " " << "OnServiceDiscovered()" << std::endl;

		if (status != ERROR_SUCCESS) {
			//std::cout << GetTimeNow() << " " << "OnServiceDiscovered(): ERROR: " << GetErrorMessage(status) << std::endl;
			DnsRecordListFree(records, DnsFreeRecordList);
			return;
		}

		const auto serviceInfoO = GetServiceInfoFromRecords(records);
		if (!serviceInfoO.has_value()) {
			// must be deleted as described here: https://docs.microsoft.com/en-us/windows/win32/api/windns/nc-windns-dns_service_browse_callback
			DnsRecordListFree(records, DnsFreeRecordList);
			return;
		}

		const ServiceInfo& serviceInfo = serviceInfoO.value();
		std::vector<ServiceInfo>& services = discoveryContextMap.at(handle)->services;

		const auto it = FindIf(services, [compare = serviceInfo](ServiceInfo& current) -> bool {
			return
				current.name == compare.name &&
				current.type == compare.type;
			});

		if (serviceInfo.status == ServiceInfo::STATUS_FOUND) {

			if (it == services.end()) {
				services.push_back(serviceInfo);
				methodChannel->InvokeMethod("onServiceDiscovered", CreateMethodResult({
						{ "handle", handle },
						{ "service.name", serviceInfo.name.value() },
						{ "service.type", serviceInfo.type.value() }
					}));
			}
		}
		else {

			if (it != services.end()) {
				services.erase(it);
				methodChannel->InvokeMethod("onServiceLost", CreateMethodResult({
						{ "handle", handle },
						{ "service.name", serviceInfo.name.value() },
						{ "service.type", serviceInfo.type.value() }
					}));
			}
		}

		DnsRecordListFree(records, DnsFreeRecordList);
	}

	void NsdWindowsPlugin::OnServiceResolved(const std::string handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance)
	{
		const auto it = resolveContextMap.find(handle);
		if (it == resolveContextMap.end()) {
			//std::cout << "OnServiceResolved(): ERROR: Unknown handle: " << handle << std::endl;
			DnsServiceFreeInstance(pInstance);
			return;
		}

		if (status != ERROR_SUCCESS) {
			methodChannel->InvokeMethod("onResolveFailed", CreateMethodResult({
					{ "handle", handle },
					{ "error.cause", ToErrorCode(ErrorCause::INTERNAL_ERROR) },
					{ "error.message", GetErrorMessage(status) },
				}));
			DnsServiceFreeInstance(pInstance);
			return;
		}

		const auto components = Split(ToUtf8(pInstance->pszInstanceName), '.'); // "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"
		const auto serviceName = components.at(0);
		const auto serviceType = components.at(1) + "." + components.at(2);
		const auto servicePort = pInstance->wPort;
		const auto serviceHost = ToUtf8(pInstance->pszHostName);

		DnsServiceFreeInstance(pInstance);
		resolveContextMap.erase(it);

		methodChannel->InvokeMethod("onResolveSuccessful", CreateMethodResult({
				{ "handle", handle },
				{ "service.type", serviceType },
				{ "service.name", serviceName },
				{ "service.port", servicePort },
				{ "service.host", serviceHost },
			}));
	}

	void NsdWindowsPlugin::OnServiceRegistered(const std::string handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance)
	{
		const auto it = registerContextMap.find(handle);
		if (it == registerContextMap.end()) {
			//std::cout << "OnServiceRegistered(): ERROR: Unknown handle: " << handle << std::endl;
			DnsServiceFreeInstance(pInstance);
			return;
		}

		auto& context = *it->second.get();
		auto& request = context.request;

		if (status != ERROR_SUCCESS) {
			DnsServiceFreeInstance(request.pServiceInstance);
			DnsServiceFreeInstance(pInstance);
			methodChannel->InvokeMethod("onRegistrationFailed", CreateMethodResult({
					{ "handle", handle },
					{ "error.cause", ToErrorCode(ErrorCause::INTERNAL_ERROR) },
					{ "error.message", GetErrorMessage(status) },
				}));
			methodChannel->InvokeMethod("onRegistrationFailed", CreateMethodResult({ { "handle", handle } }));
			return;
		}

		const auto components = Split(ToUtf8(pInstance->pszInstanceName), '.'); // "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"

		const auto serviceName = components.at(0);
		const auto serviceType = components.at(1) + "." + components.at(2);
		const auto servicePort = pInstance->wPort;
		const auto serviceHost = ToUtf8(pInstance->pszHostName);

		// later, the existing request must be reused with the newly received instance for unregistering 
		DnsServiceFreeInstance(request.pServiceInstance); // free existing instance
		request.pServiceInstance = pInstance; // replace with newly received instance

		methodChannel->InvokeMethod("onRegistrationSuccessful", CreateMethodResult({
				{ "handle", handle },
				{ "service.type", serviceType },
				{ "service.name", serviceName },
				{ "service.port", servicePort },
				{ "service.host", serviceHost },
			}));
	}

	void NsdWindowsPlugin::OnServiceUnregistered(const std::string handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance)
	{
		DnsServiceFreeInstance(pInstance); // not used and must be freed

		const auto it = registerContextMap.find(handle);
		if (it == registerContextMap.end()) {
			//std::cout << "OnServiceUnregistered(): ERROR: Unknown handle: " << handle << std::endl;
			return;
		}

		auto& context = *it->second.get();
		auto& request = context.request;

		DnsServiceFreeInstance(request.pServiceInstance);
		registerContextMap.erase(it);

		if (status != ERROR_SUCCESS) {
			methodChannel->InvokeMethod("onUnregistrationFailed", CreateMethodResult({
					{ "handle", handle },
					{ "error.cause", ToErrorCode(ErrorCause::INTERNAL_ERROR) },
					{ "error.message", GetErrorMessage(status) },
				}));
			return;
		}

		methodChannel->InvokeMethod("onUnregistrationSuccessful", CreateMethodResult({ { "handle", handle } }));
	}

	void NsdWindowsPlugin::DnsServiceBrowseCallback(const DWORD status, LPVOID context, PDNS_RECORD records)
	{
		DiscoveryContext& discoveryContext = *static_cast<DiscoveryContext*>(context);
		discoveryContext.plugin->OnServiceDiscovered(discoveryContext.handle, status, records);
	}

	void NsdWindowsPlugin::DnsServiceResolveCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance)
	{
		ResolveContext& resolveContext = *static_cast<ResolveContext*>(context);
		resolveContext.plugin->OnServiceResolved(resolveContext.handle, status, pInstance);
	}

	void NsdWindowsPlugin::DnsServiceRegisterCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance)
	{
		RegisterContext& registerContext = *static_cast<RegisterContext*>(context);
		registerContext.plugin->OnServiceRegistered(registerContext.handle, status, pInstance);
	}

	void NsdWindowsPlugin::DnsServiceUnregisterCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance)
	{
		RegisterContext& registerContext = *static_cast<RegisterContext*>(context);
		registerContext.plugin->OnServiceUnregistered(registerContext.handle, status, pInstance);
	}

	std::optional<ServiceInfo> NsdWindowsPlugin::GetServiceInfoFromRecords(const PDNS_RECORD& records) {

		// record properties see https://docs.microsoft.com/en-us/windows/win32/api/windns/ns-windns-dns_recordw
		// seen: DNS_TYPE_A (0x0001), DNS_TYPE_TEXT (0x0010), DNS_TYPE_AAAA (0x001c), DNS_TYPE_SRV (0x0021)

		for (auto record = records; record; record = record->pNext) {
			if (record->wType == DNS_TYPE_PTR) { // 0x0012
				return GetServiceInfoFromPtrRecord(record);
			}
		}

		return std::nullopt;
	}

	std::optional<nsd_windows::ServiceInfo> NsdWindowsPlugin::GetServiceInfoFromPtrRecord(const PDNS_RECORD& record)
	{
		const auto name = ToUtf8(record->pName); // PTR name field, e.g. "_http._tcp.local"
		const auto nameHost = ToUtf8(record->Data.PTR.pNameHost); // PTR rdata field DNAME, e.g. "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"
		const auto ttl = record->dwTtl;

		const auto components = Split(nameHost, '.');

		ServiceInfo serviceInfo;
		serviceInfo.name = components[0];
		serviceInfo.type = components[1] + "." + components[2];
		serviceInfo.status = (ttl > 0) ? ServiceInfo::STATUS_FOUND : ServiceInfo::STATUS_LOST;

		//std::cout << GetTimeNow() << " " << "Record: PTR: name: " << name << ", domain name: " << nameHost << ", ttl: " << ttl << std::endl;
		return serviceInfo;
	}

}  // namespace nsd_windows
