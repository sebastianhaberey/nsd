#include "utilities.h"

#include <codecvt>
#include <chrono>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <stringapiset.h>
#include <strsafe.h>
#include <sstream>

namespace nsd_windows {

	std::optional<std::string> DeserializeHandle(const flutter::EncodableMap& arguments)
	{
		return Deserialize<std::string>(arguments, "handle");
	}

	std::optional<std::string> DeserializeServiceType(const flutter::EncodableMap& arguments)
	{
		return Deserialize<std::string>(arguments, "service.type");
	}

	std::optional<std::string> DeserializeServiceName(const flutter::EncodableMap& arguments)
	{
		return Deserialize<std::string>(arguments, "service.name");
	}

	std::optional<std::string> DeserializeServiceHost(const flutter::EncodableMap& arguments)
	{
		return Deserialize<std::string>(arguments, "service.host");
	}

	std::optional<int> DeserializeServicePort(const flutter::EncodableMap& arguments)
	{
		return Deserialize<int>(arguments, "service.port");
	}

	std::pair<flutter::EncodableValue, flutter::EncodableValue> SerializeHandle(std::string handle) {
		return { "handle", handle };
	}

	std::pair<flutter::EncodableValue, flutter::EncodableValue> SerializeServiceType(std::string serviceType) {
		return { "service.type", serviceType };
	}

	std::pair<flutter::EncodableValue, flutter::EncodableValue> SerializeServiceName(std::string serviceName) {
		return { "service.name", serviceName };
	}

	std::pair<flutter::EncodableValue, flutter::EncodableValue> SerializeServiceHost(std::string serviceHost) {
		return { "service.host", serviceHost };
	}

	std::pair<flutter::EncodableValue, flutter::EncodableValue> SerializeServicePort(int servicePort) {
		return { "service.port", servicePort };
	}

	std::unique_ptr<flutter::EncodableValue> Serialize(flutter::EncodableMap values) {
		return std::move(std::make_unique<flutter::EncodableValue>(values));
	}

	std::wstring ToUtf16(const std::string& string)
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

	std::string ToUtf8(const std::wstring& wide_string)
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

	std::string GetErrorMessage(DWORD messageId)
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

	std::vector<std::string> Split(std::string text, const char delimiter) {
		std::vector<std::string> strings;
		std::istringstream f(text);
		std::string s;
		while (std::getline(f, s, delimiter)) {
			strings.push_back(s);
		}
		return strings;
	}

	std::string GetTimeNow() {
		std::time_t const now_c = std::time(nullptr);
		std::stringstream stringstream;
		stringstream << std::put_time(std::localtime(&now_c), "%F %T");
		return stringstream.str();
	}
}