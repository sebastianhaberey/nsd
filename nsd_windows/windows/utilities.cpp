#include "utilities.h"

#include <windows.h>

#include <codecvt>
#include <stringapiset.h>
#include <strsafe.h>


namespace nsd_windows {

	std::optional<std::string> DeserializeHandle(const flutter::EncodableMap& arguments)
	{
		return Deserialize<std::string>(arguments, "handle");
	}

	std::optional<std::string> DeserializeServiceType(const flutter::EncodableMap& arguments)
	{
		return Deserialize<std::string>(arguments, "service.type");
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

	std::string GetLastErrorMessage()
	{
		// Retrieve the system error message for the last-error code

		LPVOID lpMsgBuf;
		DWORD dw = GetLastError();

		FormatMessage(
			FORMAT_MESSAGE_ALLOCATE_BUFFER |
			FORMAT_MESSAGE_FROM_SYSTEM |
			FORMAT_MESSAGE_IGNORE_INSERTS,
			NULL,
			dw,
			MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
			(LPTSTR)&lpMsgBuf,
			0, NULL);


		std::string message = ToUtf8((LPTSTR)lpMsgBuf);

		LocalFree(lpMsgBuf);
		return message;
	}
}