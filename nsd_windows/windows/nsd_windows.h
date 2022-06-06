#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <windns.h>

#include <memory>

#pragma warning(disable : 4458) // declaration hides class member (used intentionally in method parameters vs local variables)
#pragma comment(lib, "dnsapi.lib")


namespace nsd_windows {

	class NsdWindows;

	struct ServiceInfo {

		enum Status {
			STATUS_FOUND,
			STATUS_LOST
		};

		std::optional<std::string> name;
		std::optional<std::string> type;
		std::optional<std::string> host;
		std::optional<int> port;
		Status status;
	};


	struct DiscoveryContext {

		NsdWindows* nsdWindows;
		std::string handle;
		DNS_SERVICE_CANCEL canceller;
		std::vector<ServiceInfo> services;
	};


	struct ResolveContext {

		NsdWindows* nsdWindows;
		std::string handle;
		DNS_SERVICE_CANCEL canceller;
	};

	struct RegisterContext {

		NsdWindows* nsdWindows;
		std::string handle;
		DNS_SERVICE_CANCEL canceller;
		DNS_SERVICE_REGISTER_REQUEST request;
	};

	class NsdWindows {
	public:

		static void DnsServiceBrowseCallback(const DWORD status, LPVOID context, PDNS_RECORD records);
		static void DnsServiceRegisterCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance);
		static void DnsServiceUnregisterCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance);
		static void DnsServiceResolveCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance);

		NsdWindows(std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel);
		virtual ~NsdWindows();

		NsdWindows(const NsdWindows&) = delete; // disallow copy
		NsdWindows& operator=(const NsdWindows&) = delete; // disallow assign

		void OnServiceDiscovered(const std::string handle, const DWORD status, PDNS_RECORD records);
		void OnServiceResolved(const std::string handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance);
		void OnServiceRegistered(const std::string handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance);
		void OnServiceUnregistered(const std::string handle, const DWORD status, PDNS_SERVICE_INSTANCE pInstance);

	private:

		static std::optional<ServiceInfo> GetServiceInfoFromRecords(const PDNS_RECORD& records);
		static std::optional<ServiceInfo> GetServiceInfoFromPtrRecord(const PDNS_RECORD& record);

		std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel;
		std::map<std::string, std::unique_ptr<DiscoveryContext>> discoveryContextMap;
		std::map<std::string, std::unique_ptr<RegisterContext>> registerContextMap;
		std::map<std::string, std::unique_ptr<ResolveContext>> resolveContextMap;

		bool systemRequirementsSatisfied;

		void HandleMethodCall(
			const flutter::MethodCall<flutter::EncodableValue>& method_call,
			std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);

		void StartDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void StopDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Resolve(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Register(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Unregister(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);

	};

}  // namespace nsd_windows
