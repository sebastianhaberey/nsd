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

	template<class T, typename F>
	T Deserialize(const flutter::EncodableMap& arguments, const std::string key, const F&& throwFunc)
	{
		if (!HasKey(arguments, key)) {
			throwFunc();
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, "Missing value: "s + key);
		}

		return std::get<T>((arguments.find(key))->second);
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

	flutter::EncodableMap WindowsTxtToFlutterTxt(const std::vector<PCWSTR>& keys, const std::vector<PCWSTR>& values);
	flutter::EncodableMap WindowsTxtToFlutterTxt(const DWORD count, const PWSTR* keys, const PWSTR* values);
	std::tuple<std::vector<PCWSTR>, std::vector<PCWSTR>> FlutterTxtToWindowsTxt(const flutter::EncodableMap& txt);

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
	bool HasKey(const flutter::EncodableMap& map, const std::string key);
}
