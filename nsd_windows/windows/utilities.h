#pragma once

#include "nsd_error.h"

#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <functional>
#include <iostream>
#include <optional>
#include <map>
#include <stdexcept>
#include <sstream>
#include <variant>
#include <vector>

namespace nsd_windows {

	template<class T, typename F>
	T Deserialize(const flutter::EncodableMap& arguments, std::string key, F&& throwFunc)
	{
		auto it = arguments.find(key);

		if (it == arguments.end() || it->second.IsNull()) {
			throwFunc();
			std::stringstream s;
			s << "Missing value: " << key << std::endl;
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, s.str());
		}

		return std::get<T>(it->second);
	}

	template<class T>
	T Deserialize(const flutter::EncodableMap& arguments, std::string key)
	{
		return Deserialize<T>(arguments, key, []() {});
	}

	template <class T, typename F> typename std::vector<T>::iterator FindIf(std::vector<T>& values, F&& predicate) {
		for (std::vector<T>::iterator it = values.begin(); it != values.end(); it++) {
			if (predicate(*it)) {
				return it;
			}
		}
		return values.end();
	}

	std::unique_ptr<flutter::EncodableValue> CreateMethodResult(flutter::EncodableMap values);

	std::wstring ToUtf16(const std::string& string);
	std::string ToUtf8(const std::wstring& wide_string);
	std::string GetErrorMessage(DWORD messageId);
	std::string GetLastErrorMessage();
	std::vector<std::string> Split(std::string text, const char delimiter);
	std::string GetTimeNow();
	std::wstring GetComputerName();
	PWCHAR CreateUtf16CString(std::string value);
	PWCHAR CreateUtf16CString(std::wstring value);
}
