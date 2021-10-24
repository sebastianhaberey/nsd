import nsd_macos
import FlutterMacOS

import XCTest

class nsd_macos_tests: XCTestCase {

    func testTxtConversion() throws {

        let valueA = createFlutterString("Test")
        let valueB = createFlutterString("")
        let valueD = createFlutterBytes([0, 1, 2, 3])

        let txt: [String: FlutterStandardTypedData?] = [
            "attribute-a": valueA,
            "attribute-b": valueB,
            "attribute-c": nil,
            "attribute-d": valueD,
        ]

        guard let recordData = flutterTxtToNativeTxt(txt) else {
            XCTFail("Could not convert flutter txt to native txt")
            return
        }

        guard let txtNew = nativeTxtToFlutterTxt(recordData) else {
            XCTFail("Could not convert native txt to flutter txt")
            return
        }

        XCTAssertEqual(valueA, txtNew["attribute-a"])

        // Apparently the value in a [String : T?] dictionary is of type T?? and needs to be
        // unwrapped for comparison (see https://stackoverflow.com/a/26558526).
        // It will work without unwrapping for non-nil values because swift promotes those to
        // optionals during comparison (see https://stackoverflow.com/a/38587571).

        let actualB = try XCTUnwrap(txtNew["attribute-b"])
        XCTAssertEqual(nil, actualB) // empty data becomes nil because of a bug in the native api

        let actualC = try XCTUnwrap(txtNew["attribute-c"])
        XCTAssertEqual(nil, actualC);

        let actualD = try XCTUnwrap(txtNew["attribute-d"])
        XCTAssertEqual(valueD, actualD);

    }
}

func createFlutterString(_ text: String) -> FlutterStandardTypedData? {
    if let bytes = text.data(using: .utf8) {
        return FlutterStandardTypedData.init(bytes: bytes)
    } else {
        return nil;
    }
}

func createFlutterBytes(_ bytes: [UInt8]) -> FlutterStandardTypedData? {
    FlutterStandardTypedData.init(bytes: Data.init(bytes))
}