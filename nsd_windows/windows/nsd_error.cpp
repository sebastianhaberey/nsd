#include "nsd_error.h"

namespace nsd_windows {

	std::string toErrorCode(const ErrorCause errorCause)
	{
		switch (errorCause) {
		case ILLEGAL_ARGUMENT:
			return "illegalArgument";

		case ALREADY_ACTIVE:
			return "alreadyActive";

		case MAX_LIMIT:
			return "maxLimit";

		case INTERNAL_ERROR:
			return "internalError";

		}
	}
}

