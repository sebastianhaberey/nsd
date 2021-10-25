import Flutter

// TODO find out how to unit test these functions without making them public

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

func serializeService(_ netService: NetService) -> [String: Any?] {
    var service: [String: Any?] = [
        "service.name": netService.name,
        "service.type": cleanServiceType(netService.type),
        "service.host": netService.hostName,
    ]

    let port = netService.port;
    if (port >= 0) {
        service["service.port"] = port
    }

    if let recordData = netService.txtRecordData() {
        if let txt = nativeTxtToFlutterTxt(recordData) {
            service["service.txt"] = txt;
        }
    }

    return service
}

func deserializeService(_ arguments: Any?, domain: String = "local.") -> NetService? {
    let args = arguments as? [String: Any]

    guard let type = args?["service.type"] as? String else {
        return nil
    }

    guard let name = args?["service.name"] as? String else {
        return nil
    }

    let port = args?["service.port"] as? Int32 ?? 0 // TODO find a sensible default here since null isn't possible

    let service = NetService(domain: domain, type: type, name: name, port: port)

    if let txt = args?["service.txt"] as? [String: FlutterStandardTypedData?] {
        if let recordData = flutterTxtToNativeTxt(txt) {
            service.setTXTRecord(recordData)
        }
    }

    return service;
}

public func nativeTxtToFlutterTxt(_ recordData: Data) -> [String: FlutterStandardTypedData?]? {

    guard let nativeData = CFNetServiceCreateDictionaryWithTXTData(nil, recordData as CFData)?.takeRetainedValue() as? Dictionary<String, Data?> else {
        return nil
    }

    let flutterData = nativeData.mapValues({ (value) -> FlutterStandardTypedData? in
        value != nil ? FlutterStandardTypedData(bytes: value!) : nil
    })

    return flutterData
}

public func flutterTxtToNativeTxt(_ flutterTxt: [String: FlutterStandardTypedData?]) -> Data? {

    let nativeData = flutterTxt.mapValues({ (value) -> Data? in value?.data })

    // apparently this method is buggy: a Swift dictionary with these values:
    //
    // attribute-a -> Optional<Data> -> 4 bytes (present, non-empty value)
    // attribute-b -> Optional<Data> -> 0 bytes (present, empty value)
    // attribute-c -> Optional<Data> -> nil (present, no value)
    //
    // is converted to:
    //
    // 0b 61 74 74   72 69 62 75   74 65 2d 62   0b 61 74 74   │ ·attribute-b·att │
    // 72 69 62 75   74 65 2d 63   10 61 74 74   72 69 62 75   │ ribute-c·attribu │
    // 74 65 2d 61   3d 54 65 73   74 00 00 00   00 00 00 00   │ te-a=Test······· │
    //
    // The specification states that empty values such as attribute-b should be represented as "attribute-b=".
    // This means that discovery on macOS will return null values for empty strings.

    let nativeTxt = CFNetServiceCreateTXTDataWithDictionary(nil, nativeData as CFDictionary)?.takeRetainedValue() as Data?

    // this is the standard way but it will not take null values at all
    // let recordData = NetService.data(fromTXTRecord: nativeData)

    return nativeTxt;
}

func deserializeServiceType(_ arguments: Any?) -> String? {
    let args = arguments as? [String: Any]
    let type = args?["service.type"] as? String
    return type
}

func serializeHandle(_ value: String) -> [String: Any?] {
    ["handle": value]
}

func deserializeHandle(_ arguments: Any?) -> String? {
    let args = arguments as? [String: Any]
    let handle = args?["handle"] as? String
    return handle
}

func serializeErrorCause(_ value: ErrorCause) -> [String: Any?] {
    ["error.cause": value.code]
}

func serializeErrorMessage(_ value: String) -> [String: Any?] {
    ["error.message": value]
}
