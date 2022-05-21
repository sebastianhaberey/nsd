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

using namespace std::string_literals;

namespace nsd_windows {

	typedef flutter::EncodableMap FlutterTxt;

	struct WindowsTxt {
		DWORD size = 0;
		PCWSTR* keys = nullptr;
		PCWSTR* values = nullptr;
	};

	template<class T>
	std::optional<T> DeserializeO(const flutter::EncodableMap& arguments, const std::string key)
	{
		auto it = arguments.find(key);

		if (it == arguments.end() || it->second.IsNull() || std::holds_alternative<std::monostate>(it->second)) {
			return std::nullopt;
		}

		return std::get<T>(it->second);
	}

	template<class T, typename F>
	T Deserialize(const flutter::EncodableMap& arguments, const std::string key, const F&& throwFunc)
	{
		std::optional<T> valueO = DeserializeO<T>(arguments, key);
		if (!valueO.has_value()) {
			throwFunc();
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, "Missing value: "s + key);
		}

		return valueO.value();
	}

	template<class T>
	T Deserialize(const flutter::EncodableMap& arguments, const std::string key)
	{
		return Deserialize<T>(arguments, key, []() {});
	}

	template <class T, typename F> typename std::vector<T>::iterator FindIf(std::vector<T>& values, const F&& predicate) {
		for (std::vector<T>::iterator it = values.begin(); it != values.end(); it++) {
			if (predicate(*it)) {
				return it;
			}
		}
		return values.end();
	}

	FlutterTxt WindowsTxtToFlutterTxt(const DWORD count, const PWSTR* keys, const PWSTR* values);
	WindowsTxt FlutterTxtToWindowsTxt(const FlutterTxt& txt);

	std::unique_ptr<flutter::EncodableValue> CreateMethodResult(const flutter::EncodableMap values);

	std::wstring ToUtf16(const std::string string);
	std::string ToUtf8(const std::wstring wide_string);
	std::string GetErrorMessage(const DWORD messageId);
	std::string GetLastErrorMessage();
	std::vector<std::string> Split(const std::string text, const char delimiter);
	std::string GetTimeNow();
	std::wstring GetComputerName();
	PWCHAR CreateUtf16CString(const std::string value);
	PWCHAR CreateUtf16CString(const std::wstring value);
}
