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
		auto handle = Deserialize<std::string>(arguments, "handle");
		auto serviceType = Deserialize<std::string>(arguments, "service.type");

		auto context = std::make_unique<DiscoveryContext>();
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
		methodChannel->InvokeMethod("onDiscoveryStartSuccessful", CreateMethodResult({ { "handle", handle } }));
		result->Success();
	}

	void NsdWindowsPlugin::StopDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		auto handle = Deserialize<std::string>(arguments, "handle");

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
		auto handle = Deserialize<std::string>(arguments, "handle");
		auto serviceName = Deserialize<std::string>(arguments, "service.name");
		auto serviceType = Deserialize<std::string>(arguments, "service.type");
		auto servicePort = Deserialize<int>(arguments, "service.port");

		auto computerName = GetComputerName();

		auto context = std::make_unique<RegisterContext>();
		context->plugin = this;
		context->handle = handle;
		context->serviceName = ToUtf16(serviceName) + L"." + ToUtf16(serviceType) + L".local";  // TODO this is only here so it doesn't get destroyed
		context->hostName = computerName + L".local"; // TODO this is only here so it doesn't get destroyed

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

		context->pRequestInstance = pServiceInstance;

		context->request.Version = DNS_QUERY_REQUEST_VERSION1;
		context->request.InterfaceIndex = 0;
		context->request.pServiceInstance = pServiceInstance;
		context->request.pRegisterCompletionCallback = &DnsServiceRegisterCallback;
		context->request.pQueryContext = context.get();
		context->request.unicastEnabled = false;

		auto status = DnsServiceRegister(&context->request, &context->canceller);

		if (status != DNS_REQUEST_PENDING) {
			// apparently DnsServiceRegister doesn't call SetLastError() as mentioned in the documentation,
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
		auto handle = Deserialize<std::string>(arguments, "handle");
		auto& context = registerContextMap.at(handle);
		auto& request = context->request;

		request.pServiceInstance = context->pReceivedInstance; // received instance can be different, e.g. in case of name conflicts, use more recent instance to deregister
		auto status = DnsServiceDeRegister(&request, nullptr);

		DnsServiceFreeInstance(context->pRequestInstance);
		DnsServiceFreeInstance(context->pReceivedInstance);

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

		auto serviceInfoOptional = GetServiceInfoFromRecords(records);
		if (serviceInfoOptional.has_value()) {

			ServiceInfo& serviceInfo = serviceInfoOptional.value();
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
		}

		// must be deleted as described here: https://docs.microsoft.com/en-us/windows/win32/api/windns/nc-windns-dns_service_browse_callback
		DnsRecordListFree(records, DnsFreeRecordList);
	}

	void NsdWindowsPlugin::OnServiceRegistered(const std::string& handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance)
	{
		if (status != ERROR_SUCCESS) {
			std::cout << "OnServiceRegistered(): ERROR: " << GetErrorMessage(status) << std::endl;
			DnsServiceFreeInstance(pInstance);
			return;
		}

		auto components = Split(ToUtf8(pInstance->pszInstanceName), '.'); // "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"

		auto serviceName = components.at(0);
		auto serviceType = components.at(1) + "." + components.at(2);
		auto servicePort = pInstance->wPort;
		auto serviceHost = ToUtf8(pInstance->pszHostName);

		auto& context = registerContextMap.at(handle);

		context->pReceivedInstance = pInstance;

		methodChannel->InvokeMethod("onRegistrationSuccessful", CreateMethodResult({
				{ "handle", handle },
				{ "service.type", serviceType },
				{ "service.name", serviceName },
				{ "service.port", servicePort },
				{ "service.host", serviceHost },
			}));
	}

	void NsdWindowsPlugin::DnsServiceBrowseCallback(const DWORD status, LPVOID context, PDNS_RECORD records)
	{
		DiscoveryContext& discoveryContext = *static_cast<DiscoveryContext*>(context);
		discoveryContext.plugin->OnServiceDiscovered(discoveryContext.handle, status, records);
	}

	void NsdWindowsPlugin::DnsServiceRegisterCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance)
	{
		RegisterContext& registerContext = *static_cast<RegisterContext*>(context);
		registerContext.plugin->OnServiceRegistered(registerContext.handle, status, pInstance);
	}

	std::optional<ServiceInfo> NsdWindowsPlugin::GetServiceInfoFromRecords(PDNS_RECORD records) {

		ServiceInfo serviceInfo;

		for (auto record = records; record; record = record->pNext) {

			// record properties see https://docs.microsoft.com/en-us/windows/win32/api/windns/ns-windns-dns_recordw
			// seen: DNS_TYPE_A (0x0001), DNS_TYPE_TEXT (0x0010), DNS_TYPE_AAAA (0x001c), DNS_TYPE_SRV (0x0021)

			switch (record->wType) {

			case DNS_TYPE_PTR: { // 0x0012

				auto name = ToUtf8(record->pName); // PTR name field, e.g. "_http._tcp.local"
				auto nameHost = ToUtf8(record->Data.PTR.pNameHost); // PTR rdata field DNAME, e.g. "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"
				auto ttl = record->dwTtl;

				serviceInfo.type = name.substr(0, name.rfind('.'));
				serviceInfo.name = nameHost.substr(0, nameHost.find('.'));
				serviceInfo.status = (ttl > 0) ? ServiceInfo::STATUS_FOUND : ServiceInfo::STATUS_LOST;

				std::cout << GetTimeNow() << " " << "Record: PTR: name: " << name << ", domain name: " << nameHost << ", ttl: " << ttl << std::endl;
				break;
			}

			case DNS_TYPE_SRV: { // 0x0021

				auto hostname = ToUtf8(record->Data.SRV.pNameTarget);
				auto port = record->Data.SRV.wPort;
				auto ttl = record->dwTtl;

				serviceInfo.host = hostname;
				serviceInfo.port = port;

				std::cout << GetTimeNow() << " " << "Record: SRV: host: " << hostname << ", port: " << port << ", ttl: " << ttl << std::endl;
				break;
			}

			case DNS_TYPE_TEXT: {
				std::cout << GetTimeNow() << " " << "Record: TXT" << std::endl; // TODO
				break;
			}

			case DNS_TYPE_A: {
				auto ip4 = record->Data.A.IpAddress;
				std::cout << GetTimeNow() << " " << "Record: A: IP adress: " << std::hex << ip4 << std::endl;
				break;
			}


			default: {
				std::cout << GetTimeNow() << " " << "Record: skipping type 0x" << std::hex << record->wType << std::endl;
			}
			}
		}

		return serviceInfo;
	}

}  // namespace nsd_windows
