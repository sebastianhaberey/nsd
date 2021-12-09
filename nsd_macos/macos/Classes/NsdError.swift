func getErrorMessage(_ errorCode: NetService.ErrorCode?) -> String {
    guard let unwrapped = errorCode else {
        return "unknown error";
    }

    if errorCode?.rawValue == 48 {
        // If the publish was done with .listenForConnections and the port is already in use,
        // didNotPublish will be called with NSNetServicesErrorCode = 48 and NSNetServicesErrorDomain = 1.
        // This should not happen any more since publish is always called without .listenForConnections now.
        // see https://stackoverflow.com/a/34880698/8707976
        return "port is already in use"
    }

    switch (unwrapped) {
    case .collisionError:
        return "service could not be published: name already in use"
    case .notFoundError:
        return "service could not be found on the network"
    case .activityInProgress:
        return "cannot process the request at this time"
    case .badArgumentError:
        return "illegal argument"
    case .cancelledError:
        return "client canceled the action"
    case .invalidError:
        return "net service was improperly configured"
    case .timeoutError:
        return "net service has timed out"
    case .missingRequiredConfigurationError:
        return "missing required configuration"
    default:
        return "internal error"
    }
}

func getErrorCode(_ number: NSNumber?) -> NetService.ErrorCode? {
    guard let unwrapped = number else {
        return nil;
    }
    return NetService.ErrorCode.init(rawValue: unwrapped.intValue)
}

func getErrorCause(_ errorCode: NetService.ErrorCode?) -> ErrorCause {
    guard let unwrapped = errorCode else {
        return ErrorCause.internalError;
    }

    switch (unwrapped) {
    case NetService.ErrorCode.badArgumentError:
        return ErrorCause.illegalArgument
    default:
        return ErrorCause.internalError
    }
}

enum ErrorCause {
    case illegalArgument
    case alreadyActive
    case maxLimit
    case internalError

    // error cause as defined by NsdErrorCause enum in nsd_platform_interface
    var code: String {
        switch self {
        case .illegalArgument: return "illegalArgument"
        case .alreadyActive: return "alreadyActive"
        case .maxLimit: return "maxLimit"
        case .internalError: return "internalError"
        }
    }
}

struct NsdError: Error {
    let cause: ErrorCause
    let message: String

    init(_ cause: ErrorCause, _ message: String) {
        self.cause = cause
        self.message = message
    }

    public var localizedDescription: String {
        "\(message) (\(cause.code))"
    }
}

