#include "nsd_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include "nsd_error.h"
#include "serialization.h"

#include <memory>
#include <sstream>
#include <iostream>

namespace nsd_windows {

	std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> NsdWindowsPlugin::methodChannel;

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
		catch (std::exception e) {
			result->Error(toErrorCode(ILLEGAL_ARGUMENT), e.what());
		}
	}

	void NsdWindowsPlugin::StartDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		std::optional<std::string> handle = deserializeHandle(arguments);
		if (!handle.has_value()) {
			result->Error(toErrorCode(ILLEGAL_ARGUMENT), "Handle cannot be null");
		}

		std::optional<std::string> serviceType = deserializeServiceType(arguments);
		if (!serviceType.has_value()) {
			result->Error(toErrorCode(ILLEGAL_ARGUMENT), "Service type cannot be null");
		}

		std::cout << "HANDLE: " << handle.value() << std::endl;
		std::cout << "SERVICE TYPE: " << serviceType.value() << std::endl;
		result->Success();
	}

	void NsdWindowsPlugin::StopDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		std::optional<std::string> handle = deserializeHandle(arguments);
		if (!handle.has_value()) {
			result->Error(toErrorCode(ILLEGAL_ARGUMENT), "Handle cannot be null");
		}

		std::cout << "HANDLE: " << handle.value() << std::endl;

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

}  // namespace nsd_windows
