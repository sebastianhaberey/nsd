#pragma once

#include <stdexcept>
#include <string>

namespace nsd_windows {

	enum ErrorCause
	{
		ILLEGAL_ARGUMENT,
		ALREADY_ACTIVE,
		MAX_LIMIT,
		INTERNAL_ERROR,
	};

	std::string ToErrorCode(const ErrorCause errorCause);

	class NsdError : public std::runtime_error {
	public:
		const ErrorCause errorCause;
		NsdError(ErrorCause errorCause, std::string message);
		virtual ~NsdError();

	};
}
