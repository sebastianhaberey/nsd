#include "nsd_windows.h"

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

	NsdWindows::NsdWindows(std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel) {
		this->methodChannel = std::move(methodChannel);
		this->methodChannel->SetMethodCallHandler(
			[nsdWindows = this](const auto& call, auto result) { nsdWindows->HandleMethodCall(call, result);
			});
		this->systemRequirementsSatisfied = CheckSystemRequirementsSatisfied();
	}

	NsdWindows::~NsdWindows() {}

	void NsdWindows::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& methodCall,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result) {

		const auto& method_name = methodCall.method_name();

		try {
			const auto& arguments = std::get<flutter::EncodableMap>(*methodCall.arguments());

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
		catch (const NsdError& e) {
			result->Error(ToErrorCode(e.errorCause), e.what());
		}
		catch (const std::exception& e) {
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), e.what());
		}
	}

	void NsdWindows::StartDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		if (!this->systemRequirementsSatisfied) {
			throw NsdError(ErrorCause::OPERATION_NOT_SUPPORTED, "Plugin requires at least Windows 10, build 18362");
		}

		auto handle = Deserialize<std::string>(arguments, "handle");
		auto serviceType = Deserialize<std::string>(arguments, "service.type");

		auto context = std::make_unique<DiscoveryContext>();
		context->nsdWindows = this;
		context->handle = handle;

		auto queryName = ToUtf16(serviceType + ".local");

		DNS_SERVICE_BROWSE_REQUEST request{};
		request.Version = DNS_QUERY_REQUEST_VERSION1;
		request.InterfaceIndex = 0;
		request.QueryName = queryName.c_str();
		request.pBrowseCallback = &DnsServiceBrowseCallback;
		request.pQueryContext = context.get();

		auto status = DnsServiceBrowse(&request, &context->canceller);

		if (status != DNS_REQUEST_PENDING) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		discoveryContextMap[handle] = std::move(context);
		methodChannel->InvokeMethod("onDiscoveryStartSuccessful", CreateMethodResult({ { "handle", handle } }));
		result->Success();
	}

	void NsdWindows::StopDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		auto handle = Deserialize<std::string>(arguments, "handle");

		auto it = discoveryContextMap.find(handle);
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

	void NsdWindows::Resolve(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		auto handle = Deserialize<std::string>(arguments, "handle");
		auto serviceName = Deserialize<std::string>(arguments, "service.name");
		auto serviceType = Deserialize<std::string>(arguments, "service.type");

		auto context = std::make_unique<ResolveContext>();
		context->nsdWindows = this;
		context->handle = handle;

		auto queryName = ToUtf16(serviceName + "." + serviceType + ".local");

		DNS_SERVICE_RESOLVE_REQUEST request{};
		request.Version = DNS_QUERY_REQUEST_VERSION1;
		request.InterfaceIndex = 0;
		request.QueryName = const_cast<PWSTR>(queryName.c_str());
		request.pResolveCompletionCallback = &DnsServiceResolveCallback;
		request.pQueryContext = context.get();

		const auto status = DnsServiceResolve(&request, &context->canceller);

		if (status != DNS_REQUEST_PENDING) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		resolveContextMap[handle] = std::move(context);
		result->Success();
	}

	void NsdWindows::Register(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		if (!this->systemRequirementsSatisfied) {
			throw NsdError(ErrorCause::OPERATION_NOT_SUPPORTED, "Plugin requires at least Windows 10, build 18362");
		}

		auto handle = Deserialize<std::string>(arguments, "handle");
		auto serviceName = Deserialize<std::string>(arguments, "service.name");
		auto serviceType = Deserialize<std::string>(arguments, "service.type");
		auto servicePort = Deserialize<int>(arguments, "service.port");
		auto serviceTxt = FlutterTxtToWindowsTxt(DeserializeOptional<flutter::EncodableMap>(arguments, "service.txt"));

		auto computerName = GetComputerName();

		// see https://docs.microsoft.com/en-us/windows/win32/api/windns/nf-windns-dnsserviceconstructinstance

		auto serviceNameW = ToUtf16(serviceName + "." + serviceType + ".local");
		auto hostNameW = computerName + L".local";

		PDNS_SERVICE_INSTANCE pServiceInstance = DnsServiceConstructInstance(
			serviceNameW.c_str(), // PCWSTR pServiceName
			hostNameW.c_str(), // PCWSTR pHostName
			nullptr, // PIP4_ADDRESS pIp4 (optional)
			nullptr, // PIP6_ADDRESS pIp6 (optional)
			static_cast<WORD>(servicePort), // WORD wPort
			0, // WORD wPriority
			0, // WORD wWeight
			serviceTxt->size, // DWORD dwPropertiesCount
			serviceTxt->pKeyPointers, // PCWSTR* keys
			serviceTxt->pValuePointers // PCWSTR* values
		);

		auto context = std::make_unique<RegisterContext>();
		context->nsdWindows = this;
		context->handle = handle;

		auto& request = context->request;
		request.Version = DNS_QUERY_REQUEST_VERSION1;
		request.InterfaceIndex = 0;
		request.pServiceInstance = pServiceInstance;
		request.pRegisterCompletionCallback = &DnsServiceRegisterCallback;
		request.pQueryContext = context.get();
		request.unicastEnabled = false;

		auto status = DnsServiceRegister(&request, &context->canceller);

		DnsServiceFreeInstance(request.pServiceInstance);
		request.pServiceInstance = nullptr; // will be replaced by OnServiceResolved()
		request.pRegisterCompletionCallback = nullptr; // will be replaced by Unregister()

		if (status != DNS_REQUEST_PENDING) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		registerContextMap[handle] = std::move(context);
		result->Success();
	}

	void NsdWindows::Unregister(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		auto handle = Deserialize<std::string>(arguments, "handle");

		auto it = registerContextMap.find(handle);
		if (it == registerContextMap.end()) {
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, "Unknown handle");
		}

		auto& context = *it->second.get();
		auto& request = context.request;

		request.pRegisterCompletionCallback = &DnsServiceUnregisterCallback; // set callback for request reuse

		auto status = DnsServiceDeRegister(&request, nullptr);

		DnsServiceFreeInstance(request.pServiceInstance);
		request.pServiceInstance = nullptr;

		if (status != DNS_REQUEST_PENDING) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		result->Success();
	}

	void NsdWindows::OnServiceDiscovered(const std::string handle, const DWORD status, PDNS_RECORD records)
	{
		//std::cout << GetTimeNow() << " " << "OnServiceDiscovered()" << std::endl;

		if (status != ERROR_SUCCESS) {
			//std::cout << GetTimeNow() << " " << "OnServiceDiscovered(): ERROR: " << GetErrorMessage(status) << std::endl;
			DnsRecordListFree(records, DnsFreeRecordList);
			return;
		}

		auto serviceInfoO = GetServiceInfoFromRecords(records);
		if (!serviceInfoO.has_value()) {
			// must be deleted as described here: https://docs.microsoft.com/en-us/windows/win32/api/windns/nc-windns-dns_service_browse_callback
			DnsRecordListFree(records, DnsFreeRecordList);
			return;
		}

		ServiceInfo& serviceInfo = serviceInfoO.value();
		std::vector<ServiceInfo>& services = discoveryContextMap.at(handle)->services;

		auto it = FindIf(services, [compare = serviceInfo](ServiceInfo& current) -> bool {
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
						{ "service.type", serviceInfo.type.value() },
					}));
			}
		}
		else {

			if (it != services.end()) {
				services.erase(it);
				methodChannel->InvokeMethod("onServiceLost", CreateMethodResult({
						{ "handle", handle },
						{ "service.name", serviceInfo.name.value() },
						{ "service.type", serviceInfo.type.value() },
					}));
			}
		}

		DnsRecordListFree(records, DnsFreeRecordList);
	}

	void NsdWindows::OnServiceResolved(const std::string handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance)
	{
		auto it = resolveContextMap.find(handle);
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

		auto components = Split(ToUtf8(pInstance->pszInstanceName), '.'); // "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"
		auto serviceName = components.at(0);
		auto serviceType = components.at(1) + "." + components.at(2);
		auto servicePort = pInstance->wPort;
		auto serviceHost = ToUtf8(pInstance->pszHostName);
		auto serviceTxt = WindowsTxtToFlutterTxt(pInstance->dwPropertyCount, pInstance->keys, pInstance->values);

		DnsServiceFreeInstance(pInstance);
		resolveContextMap.erase(it);

		methodChannel->InvokeMethod("onResolveSuccessful", CreateMethodResult({
				{ "handle", handle },
				{ "service.type", serviceType },
				{ "service.name", serviceName },
				{ "service.port", servicePort },
				{ "service.host", serviceHost },
				{ "service.txt", serviceTxt },
			}));
	}

	void NsdWindows::OnServiceRegistered(const std::string handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance)
	{
		auto it = registerContextMap.find(handle);
		if (it == registerContextMap.end()) {
			//std::cout << "OnServiceRegistered(): ERROR: Unknown handle: " << handle << std::endl;
			DnsServiceFreeInstance(pInstance);
			return;
		}

		auto& context = *it->second.get();
		auto& request = context.request;

		if (status != ERROR_SUCCESS) {
			DnsServiceFreeInstance(pInstance);
			methodChannel->InvokeMethod("onRegistrationFailed", CreateMethodResult({
					{ "handle", handle },
					{ "error.cause", ToErrorCode(ErrorCause::INTERNAL_ERROR) },
					{ "error.message", GetErrorMessage(status) },
				}));
			methodChannel->InvokeMethod("onRegistrationFailed", CreateMethodResult({ { "handle", handle } }));
			return;
		}

		auto components = Split(ToUtf8(pInstance->pszInstanceName), '.'); // "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"

		auto serviceName = components.at(0);
		auto serviceType = components.at(1) + "." + components.at(2);
		auto servicePort = pInstance->wPort;
		auto serviceHost = ToUtf8(pInstance->pszHostName);
		auto serviceTxt = WindowsTxtToFlutterTxt(pInstance->dwPropertyCount, pInstance->keys, pInstance->values);

		// the existing request must be reused with the newly received instance for unregistering 
		request.pServiceInstance = pInstance;

		methodChannel->InvokeMethod("onRegistrationSuccessful", CreateMethodResult({
				{ "handle", handle },
				{ "service.type", serviceType },
				{ "service.name", serviceName },
				{ "service.port", servicePort },
				{ "service.host", serviceHost },
				{ "service.txt", serviceTxt },
			}));
	}

	void NsdWindows::OnServiceUnregistered(const std::string handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance)
	{
		DnsServiceFreeInstance(pInstance); // not used

		auto it = registerContextMap.find(handle);
		if (it == registerContextMap.end()) {
			//std::cout << "OnServiceUnregistered(): ERROR: Unknown handle: " << handle << std::endl;
			return;
		}

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

	void NsdWindows::DnsServiceBrowseCallback(const DWORD status, LPVOID context, PDNS_RECORD records)
	{
		DiscoveryContext& discoveryContext = *static_cast<DiscoveryContext*>(context);
		discoveryContext.nsdWindows->OnServiceDiscovered(discoveryContext.handle, status, records);
	}

	void NsdWindows::DnsServiceResolveCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance)
	{
		ResolveContext& resolveContext = *static_cast<ResolveContext*>(context);
		resolveContext.nsdWindows->OnServiceResolved(resolveContext.handle, status, pInstance);
	}

	void NsdWindows::DnsServiceRegisterCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance)
	{
		RegisterContext& registerContext = *static_cast<RegisterContext*>(context);
		registerContext.nsdWindows->OnServiceRegistered(registerContext.handle, status, pInstance);
	}

	void NsdWindows::DnsServiceUnregisterCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance)
	{
		RegisterContext& registerContext = *static_cast<RegisterContext*>(context);
		registerContext.nsdWindows->OnServiceUnregistered(registerContext.handle, status, pInstance);
	}

	std::optional<ServiceInfo> NsdWindows::GetServiceInfoFromRecords(const PDNS_RECORD& records) {

		// record properties see https://docs.microsoft.com/en-us/windows/win32/api/windns/ns-windns-dns_recordw
		// seen: DNS_TYPE_A (0x0001), DNS_TYPE_TEXT (0x0010), DNS_TYPE_AAAA (0x001c), DNS_TYPE_SRV (0x0021)

		for (auto record = records; record; record = record->pNext) {
			if (record->wType == DNS_TYPE_PTR) { // 0x0012
				return GetServiceInfoFromPtrRecord(record);
			}
		}

		return std::nullopt;
	}

	std::optional<nsd_windows::ServiceInfo> NsdWindows::GetServiceInfoFromPtrRecord(const PDNS_RECORD& record)
	{
		auto nameHost = ToUtf8(record->Data.PTR.pNameHost); // PTR rdata field DNAME, e.g. "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"
		auto ttl = record->dwTtl;

		auto components = Split(nameHost, '.');

		ServiceInfo serviceInfo;
		serviceInfo.name = components[0];
		serviceInfo.type = components[1] + "." + components[2];
		serviceInfo.status = (ttl > 0) ? ServiceInfo::STATUS_FOUND : ServiceInfo::STATUS_LOST;

		//std::cout << GetTimeNow() << " " << "Record: PTR: name: " << name << ", domain name: " << nameHost << ", ttl: " << ttl << std::endl;
		return serviceInfo;
	}

}  // namespace nsd_windows
