#pragma once

#include "nsd_error.h"

#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <functional>
#include <iostream>
#include <optional>
#include <map>
#include <stdexcept>
#include <variant>
#include <vector>

namespace nsd_windows {

	template<class T>
	std::optional<T> Deserialize(const flutter::EncodableMap& arguments, std::string key)
	{
		auto it = arguments.find(key);

		if (it == arguments.end() || it->second.IsNull()) {
			return std::nullopt;
		}

		return std::optional<T>(std::get<T>(it->second));
	}

	template<class T> T UnwrapOrThrow(const std::optional<T>& optionalValue, ErrorCause errorCause, std::string message) {
		if (optionalValue.has_value()) {
			return optionalValue.value();
		}
		throw NsdError(errorCause, message);
	};

	std::optional<std::string> DeserializeHandle(const flutter::EncodableMap& arguments);
	std::optional<std::string> DeserializeServiceType(const flutter::EncodableMap& arguments);
	std::optional<std::string> DeserializeServiceName(const flutter::EncodableMap& arguments);
	std::optional<int> DeserializeServicePort(const flutter::EncodableMap& arguments);
	std::optional<std::string> DeserializeServiceHost(const flutter::EncodableMap& arguments);

	std::unique_ptr<flutter::EncodableValue> Serialize(flutter::EncodableMap values);
	std::pair<flutter::EncodableValue, flutter::EncodableValue> SerializeHandle(std::string handle);
	std::pair<flutter::EncodableValue, flutter::EncodableValue> SerializeServiceType(std::string serviceType);
	std::pair<flutter::EncodableValue, flutter::EncodableValue> SerializeServiceName(std::string serviceName);
	std::pair<flutter::EncodableValue, flutter::EncodableValue> SerializeServiceHost(std::string serviceHost);
	std::pair<flutter::EncodableValue, flutter::EncodableValue> SerializeServicePort(int servicePort);

	std::wstring ToUtf16(const std::string& string);
	std::string ToUtf8(const std::wstring& wide_string);
	std::string GetErrorMessage(DWORD messageId);
	std::string GetLastErrorMessage();
	std::vector<std::string> Split(std::string text, const char delimiter);
	std::string GetTimeNow();
}
