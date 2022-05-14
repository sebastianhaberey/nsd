#pragma once

#include <flutter/standard_method_codec.h>

#include <optional>
#include <variant>

namespace nsd_windows {
	
	template<class T>
	std::optional<T> deserialize(const flutter::EncodableMap& arguments, const std::string key)
	{
		auto it = arguments.find(key);

		if (it == arguments.end() || it->second.IsNull()) {
			return std::nullopt;
		}

		return std::optional<T>(std::get<T>(it->second));
	}

	std::optional<std::string> deserializeHandle(const flutter::EncodableMap& arguments);

	std::optional<std::string> deserializeServiceType(const flutter::EncodableMap& arguments);
}
