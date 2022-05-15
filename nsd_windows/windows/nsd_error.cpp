#include "nsd_error.h"

namespace nsd_windows {

	std::string ToErrorCode(const ErrorCause errorCause)
	{
		switch (errorCause) {
		case ILLEGAL_ARGUMENT:
			return "illegalArgument";

		case ALREADY_ACTIVE:
			return "alreadyActive";

		case MAX_LIMIT:
			return "maxLimit";

		case INTERNAL_ERROR:
		default:
			return "internalError";
		}
	}

	NsdError::NsdError(ErrorCause errorCause, std::string message) : std::runtime_error(message), errorCause(errorCause)
	{
	}

	NsdError::~NsdError()
	{
	}
}

