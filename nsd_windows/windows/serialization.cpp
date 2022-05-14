#include "serialization.h"

std::optional<std::string> nsd_windows::deserializeHandle(const flutter::EncodableMap& arguments)
{
	return deserialize<std::string>(arguments, "handle");
}

std::optional<std::string> nsd_windows::deserializeServiceType(const flutter::EncodableMap& arguments)
{
	return deserialize<std::string>(arguments, "service.type");
}
