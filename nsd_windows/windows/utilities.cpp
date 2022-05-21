#include "utilities.h"

#include <codecvt>
#include <chrono>
#include <ctime>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stringapiset.h>
#include <strsafe.h>

namespace nsd_windows {

	flutter::EncodableMap WindowsTxtToFlutterTxt(const std::vector<PCWSTR>& keys, const std::vector<PCWSTR>& values) {
		flutter::EncodableMap txt;

		for (int i = 0; i < keys.size(); i++) {

			const auto key = ToUtf8(keys[i]);
			const auto codeUnitsString = ToUtf8(values[i]);
			const auto codeUnitsList = std::vector<unsigned char>(codeUnitsString.begin(), codeUnitsString.end());

			if (codeUnitsList.empty()) {

				// Windows doesn't distinguish between "empty value" ("foo=") and "no value" (e.g. "foo") as described in RFC6763,
				// instead all "no value" will be empty. We treat both these value types as "no value" to be consistent with the other platforms.
				// see https://datatracker.ietf.org/doc/html/rfc6763#section-6.4

				txt[key] = std::monostate();
			}
			else {
				txt[key] = codeUnitsList;
			}
		}
		return txt;
	}

	flutter::EncodableMap WindowsTxtToFlutterTxt(const DWORD count, const PWSTR* keys, const PWSTR* values) {
		return WindowsTxtToFlutterTxt(std::vector<PCWSTR>(keys, keys + count), std::vector<PCWSTR>(values, values + count));
	}

	std::tuple<std::vector<PCWSTR>, std::vector<PCWSTR>> FlutterTxtToWindowsTxt(const flutter::EncodableMap& txt) {
		std::vector<PCWSTR> keys;
		std::vector<PCWSTR> values;

		for (auto it = txt.begin(); it != txt.end(); it++) {

			const auto key = CreateUtf16CString(std::get<std::string>(it->first));

			if (it->second.IsNull()) {
				keys.push_back(key);
				values.push_back(nullptr);
			}
			else if (std::holds_alternative<std::vector<unsigned char>>(it->second)) { // list of UTF-8 code units
				keys.push_back(key);
				const auto& codeUnitsList = std::get<std::vector<unsigned char>>(it->second);
				const std::string codeUnitsString(codeUnitsList.begin(), codeUnitsList.end());

				// Non-UTF-8 code units such as '255' will be replaced with U+FFFD by MultiByteToWideChar, so they will not survive the journey
				values.push_back(CreateUtf16CString(codeUnitsString));
			}
			else {
				// ignore value
			}
		}

		return { keys, values };
	}

	std::unique_ptr<flutter::EncodableValue> CreateMethodResult(const flutter::EncodableMap values) {
		return std::move(std::make_unique<flutter::EncodableValue>(values));
	}

	std::wstring ToUtf16(const std::string string)
	{
		// see https://stackoverflow.com/a/69410299/8707976

		if (string.empty())
		{
			return L"";
		}

		const auto size_needed = MultiByteToWideChar(CP_UTF8, 0, &string.at(0), (int)string.size(), nullptr, 0);
		if (size_needed <= 0)
		{
			throw std::runtime_error("MultiByteToWideChar() failed: " + std::to_string(size_needed));
			// see https://docs.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-multibytetowidechar for error codes
		}

		std::wstring result(size_needed, 0);
		MultiByteToWideChar(CP_UTF8, 0, &string.at(0), (int)string.size(), &result.at(0), size_needed);
		return result;
	}

	std::string ToUtf8(const std::wstring wide_string)
	{
		// see https://stackoverflow.com/a/69410299/8707976

		if (wide_string.empty())
		{
			return "";
		}

		const auto size_needed = WideCharToMultiByte(CP_UTF8, 0, &wide_string.at(0), (int)wide_string.size(), nullptr, 0, nullptr, nullptr);
		if (size_needed <= 0)
		{
			throw std::runtime_error("WideCharToMultiByte() failed: " + std::to_string(size_needed));
			// see https://docs.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-multibytetowidechar for error codes
		}

		std::string result(size_needed, 0);
		WideCharToMultiByte(CP_UTF8, 0, &wide_string.at(0), (int)wide_string.size(), &result.at(0), size_needed, nullptr, nullptr);
		return result;
	}

	std::string GetErrorMessage(const DWORD messageId)
	{
		// see https://docs.microsoft.com/en-us/windows/win32/debug/retrieving-the-last-error-code

		LPVOID pBuffer = nullptr;

		FormatMessage(
			FORMAT_MESSAGE_ALLOCATE_BUFFER |
			FORMAT_MESSAGE_FROM_SYSTEM |
			FORMAT_MESSAGE_IGNORE_INSERTS,
			nullptr,
			messageId,
			MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
			(LPTSTR)&pBuffer,
			0,
			nullptr
		);

		std::string message = ToUtf8((LPTSTR)pBuffer);

		LocalFree(pBuffer);
		return message;
	}

	std::string GetLastErrorMessage()
	{
		return GetErrorMessage(GetLastError());
	}

	std::vector<std::string> Split(const std::string text, const char delimiter) {
		std::istringstream in(text);
		std::vector<std::string> out;
		std::string current;
		while (std::getline(in, current, delimiter)) {
			out.push_back(current);
		}
		return out;
	}

	std::string GetTimeNow() {
		std::time_t const now_c = std::time(nullptr);
		std::stringstream stringstream;
		stringstream << std::put_time(std::localtime(&now_c), "%F %T");
		return stringstream.str();
	}

	std::wstring GetComputerName() {
		DWORD size = 0;
		GetComputerNameEx(ComputerNameDnsHostname, nullptr, &size);
		std::vector<wchar_t> computerName(size);
		if (!GetComputerNameEx(ComputerNameDnsHostname, &computerName[0], &size)) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, "Could not determine computer name");
		}
		return &computerName[0];
	}

	PWCHAR CreateUtf16CString(const std::wstring value) {
		const auto size = value.length() + 1;
		const PWCHAR pCString = new wchar_t[size];
		wcscpy_s(pCString, size, value.c_str());
		return pCString;
	}

	PWCHAR CreateUtf16CString(const std::string value) {
		return CreateUtf16CString(ToUtf16(value));
	}

	bool HasKey(const flutter::EncodableMap& map, const std::string key) {
		auto it = map.find(key);
		return it != map.end() && !it->second.IsNull() && !std::holds_alternative<std::monostate>(it->second);
	}
}