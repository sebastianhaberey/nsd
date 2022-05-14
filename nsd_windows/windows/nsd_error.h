#pragma once

#include <string>

namespace nsd_windows {

	enum ErrorCause
	{
		ILLEGAL_ARGUMENT,
		ALREADY_ACTIVE,
		MAX_LIMIT,
		INTERNAL_ERROR,
	};

	std::string toErrorCode(const ErrorCause errorCause);
}
