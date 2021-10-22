import FlutterMacOS

func cleanServiceType(_ serviceType: String?) -> String? {
    // In the specification http://files.dns-sd.org/draft-cheshire-dnsext-dns-sd.txt 4.1.2 / 7. it looks like
    // the dot doesn't actually belong to the <Service> portion but separates it from the domain portion.
    // The dot is removed here to allow unambiguous identification of services by their name / type combination.
    if let s = serviceType {
        return !s.isEmpty && s.last == "." ? String(s.dropLast()) : s
    } else {
        return nil
    }
}

func serializeServiceInfo(_ service: NetService) -> [String: Any?] {
    var port: Int? = service.port
    if port == -1 {
        port = nil
    }

    var txt: [String: FlutterStandardTypedData]? = nil;
    if let txtRecordData = service.txtRecordData() {
        txt = NetService.dictionary(fromTXTRecord: txtRecordData).mapValues({ (value) -> FlutterStandardTypedData in
            FlutterStandardTypedData(bytes: value)
        })
    }

    return [
        "service.name": service.name,
        "service.type": cleanServiceType(service.type),
        "service.host": service.hostName,
        "service.port": port,
        "service.txt": txt
    ]
}

func deserializeServiceInfo(_ arguments: Any?, domain: String = "local.") -> NetService? {
    let args = arguments as? [String: Any]

    guard let type = args?["service.type"] as? String else {
        return nil;
    }

    guard let name = args?["service.name"] as? String else {
        return nil;
    }

    let port = args?["service.port"] as? Int32 ?? 0 // TODO find a sensible default here since null isn't possible

    return NetService(domain: domain, type: type, name: name, port: port);
}

func deserializeServiceType(_ arguments: Any?) -> String? {
    let args = arguments as? [String: Any]
    let type = args?["service.type"] as? String
    return type
}

func serializeAgentId(_ agentId: String) -> [String: Any?] {
    ["agentId": agentId]
}

func deserializeAgentId(_ arguments: Any?) -> String? {
    let args = arguments as? [String: Any]
    let agentId = args?["agentId"] as? String
    return agentId
}

func serializeErrorCause(_ errorCause: ErrorCause) -> [String: Any?] {
    ["error.cause": errorCause.code]
}

func serializeErrorMessage(_ errorMessage: String) -> [String: Any?] {
    ["error.message": errorMessage]
}
