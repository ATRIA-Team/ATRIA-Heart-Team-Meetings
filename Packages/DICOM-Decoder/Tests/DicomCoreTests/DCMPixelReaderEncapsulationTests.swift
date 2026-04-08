import XCTest
@testable import DicomCore

final class DCMPixelReaderEncapsulationTests: XCTestCase {

    func testExtractEncapsulatedSingleFrameReassemblesFragments() {
        let payload = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05])
        let encapsulated = makeEncapsulatedPixelData(
            basicOffsetTable: [0],
            items: [
                Data(payload.prefix(2)),
                Data(payload.dropFirst(2))
            ]
        )

        let extracted = DCMPixelReader.extractEncapsulatedSingleFrame(
            data: encapsulated,
            offset: 0,
            numberOfFrames: 1,
            transferSyntaxUID: DicomTransferSyntax.jpeg2000.rawValue
        )

        XCTAssertEqual(extracted, payload)
    }

    func testExtractEncapsulatedSingleFrameRejectsMultiFrameBOT() {
        let encapsulated = makeEncapsulatedPixelData(
            basicOffsetTable: [0, 128],
            items: [Data([0x01, 0x02])]
        )

        let extracted = DCMPixelReader.extractEncapsulatedSingleFrame(
            data: encapsulated,
            offset: 0,
            numberOfFrames: 1,
            transferSyntaxUID: DicomTransferSyntax.jpeg2000.rawValue
        )

        XCTAssertNil(extracted)
    }

    func testExtractEncapsulatedSingleFrameRejectsMultiFrameMetadata() {
        let encapsulated = makeEncapsulatedPixelData(
            basicOffsetTable: [0],
            items: [Data([0x01, 0x02])]
        )

        let extracted = DCMPixelReader.extractEncapsulatedSingleFrame(
            data: encapsulated,
            offset: 0,
            numberOfFrames: 2,
            transferSyntaxUID: DicomTransferSyntax.jpeg2000Lossless.rawValue
        )

        XCTAssertNil(extracted)
    }

    private func makeEncapsulatedPixelData(basicOffsetTable: [UInt32], items: [Data]) -> Data {
        var data = Data()
        appendItem(tag: 0xE000FFFE, payload: makeBOTPayload(from: basicOffsetTable), to: &data)
        for item in items {
            appendItem(tag: 0xE000FFFE, payload: item, to: &data)
        }
        appendUInt32LE(0xE0DDFFFE, to: &data)
        appendUInt32LE(0, to: &data)
        return data
    }

    private func makeBOTPayload(from offsets: [UInt32]) -> Data {
        var data = Data()
        for offset in offsets {
            appendUInt32LE(offset, to: &data)
        }
        return data
    }

    private func appendItem(tag: UInt32, payload: Data, to data: inout Data) {
        appendUInt32LE(tag, to: &data)
        appendUInt32LE(UInt32(payload.count), to: &data)
        data.append(payload)
    }

    private func appendUInt32LE(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value >> 16))
        data.append(UInt8(truncatingIfNeeded: value >> 24))
    }
}
