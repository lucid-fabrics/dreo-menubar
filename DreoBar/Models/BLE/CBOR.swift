import Foundation

/// Minimal CBOR (RFC 8949) value covering exactly what the Dreo BLE "HeFi"
/// provisioning protocol uses: definite-length maps with text-string keys,
/// arrays, unsigned/negative integers, byte strings, text strings, bool,
/// and null. No indefinite-length items, tags, or floats: confirmed by live
/// capture (2026-07-27) that the protocol never uses them.
indirect enum CBORValue: Equatable {
    case unsigned(UInt64)
    case negative(Int64)
    case bytes(Data)
    case text(String)
    case array([CBORValue])
    /// Ordered key/value pairs, not a `Dictionary`: this protocol's fan
    /// firmware turned out to parse maps positionally rather than by key
    /// lookup, so encoding must reproduce the real app's exact field order
    /// (confirmed against a live capture, 2026-07-27) or the fan silently
    /// ignores the message.
    case map([(String, CBORValue)])
    case bool(Bool)
    case null

    static func == (lhs: CBORValue, rhs: CBORValue) -> Bool {
        switch (lhs, rhs) {
        case (.unsigned(let left), .unsigned(let right)): return left == right
        case (.negative(let left), .negative(let right)): return left == right
        case (.bytes(let left), .bytes(let right)): return left == right
        case (.text(let left), .text(let right)): return left == right
        case (.array(let left), .array(let right)): return left == right
        case (.map(let left), .map(let right)):
            return left.count == right.count && zip(left, right).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.bool(let left), .bool(let right)): return left == right
        case (.null, .null): return true
        default: return false
        }
    }
}

extension CBORValue {
    var intValue: Int? {
        switch self {
        case .unsigned(let value): return Int(value)
        case .negative(let value): return Int(value)
        default: return nil
        }
    }

    var stringValue: String? {
        if case .text(let value) = self { return value }
        return nil
    }

    var dataValue: Data? {
        if case .bytes(let value) = self { return value }
        return nil
    }

    var arrayValue: [CBORValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    subscript(key: String) -> CBORValue? {
        if case .map(let entries) = self { return entries.first(where: { $0.0 == key })?.1 }
        return nil
    }
}

enum CBORError: Error, Equatable {
    case truncated
    case unsupportedMajorType(UInt8)
    case invalidMapKey
}

enum CBOR {
    static func encode(_ value: CBORValue) -> Data {
        var data = Data()
        encode(value, into: &data)
        return data
    }

    static func decode(_ data: Data) throws -> CBORValue {
        var bytes = [UInt8](data)[...]
        return try decodeValue(&bytes)
    }

    // MARK: - Encoding

    private static func encode(_ value: CBORValue, into data: inout Data) {
        switch value {
        case .unsigned(let magnitude):
            encodeHeader(major: 0, length: magnitude, into: &data)
        case .negative(let number):
            // CBOR stores negative integers as -1-n in the unsigned argument.
            encodeHeader(major: 1, length: UInt64(bitPattern: -1 - number), into: &data)
        case .bytes(let bytes):
            encodeHeader(major: 2, length: UInt64(bytes.count), into: &data)
            data.append(bytes)
        case .text(let string):
            let utf8 = Array(string.utf8)
            encodeHeader(major: 3, length: UInt64(utf8.count), into: &data)
            data.append(contentsOf: utf8)
        case .array(let items):
            encodeHeader(major: 4, length: UInt64(items.count), into: &data)
            for item in items { encode(item, into: &data) }
        case .map(let entries):
            encodeHeader(major: 5, length: UInt64(entries.count), into: &data)
            for (key, item) in entries {
                encode(.text(key), into: &data)
                encode(item, into: &data)
            }
        case .bool(let flag):
            data.append(flag ? 0xF5 : 0xF4)
        case .null:
            data.append(0xF6)
        }
    }

    private static func encodeHeader(major: UInt8, length: UInt64, into data: inout Data) {
        let majorByte = major << 5
        switch length {
        case 0..<24:
            data.append(majorByte | UInt8(length))
        case 24...0xFF:
            data.append(majorByte | 24)
            data.append(UInt8(length))
        case 0x100...0xFFFF:
            data.append(majorByte | 25)
            data.append(UInt8((length >> 8) & 0xFF))
            data.append(UInt8(length & 0xFF))
        case 0x1_0000...0xFFFF_FFFF:
            data.append(majorByte | 26)
            for shift in stride(from: 24, through: 0, by: -8) {
                data.append(UInt8((length >> shift) & 0xFF))
            }
        default:
            data.append(majorByte | 27)
            for shift in stride(from: 56, through: 0, by: -8) {
                data.append(UInt8((length >> shift) & 0xFF))
            }
        }
    }

    // MARK: - Decoding

    private static func decodeValue(_ bytes: inout ArraySlice<UInt8>) throws -> CBORValue {
        guard let first = bytes.popFirst() else { throw CBORError.truncated }
        let major = first >> 5
        let info = first & 0x1F

        switch major {
        case 0:
            return .unsigned(try decodeLength(info, &bytes))
        case 1:
            return .negative(-1 - Int64(bitPattern: try decodeLength(info, &bytes)))
        case 2:
            return .bytes(try takeBytes(Int(try decodeLength(info, &bytes)), &bytes))
        case 3:
            return try decodeText(info, &bytes)
        case 4:
            return try decodeArray(info, &bytes)
        case 5:
            return try decodeMap(info, &bytes)
        case 7:
            return try decodeSimple(info, first)
        default:
            throw CBORError.unsupportedMajorType(major)
        }
    }

    private static func decodeText(_ info: UInt8, _ bytes: inout ArraySlice<UInt8>) throws -> CBORValue {
        let length = try decodeLength(info, &bytes)
        let raw = try takeBytes(Int(length), &bytes)
        guard let string = String(data: raw, encoding: .utf8) else { throw CBORError.invalidMapKey }
        return .text(string)
    }

    private static func decodeArray(_ info: UInt8, _ bytes: inout ArraySlice<UInt8>) throws -> CBORValue {
        let count = try decodeLength(info, &bytes)
        var items: [CBORValue] = []
        for _ in 0..<count { items.append(try decodeValue(&bytes)) }
        return .array(items)
    }

    private static func decodeMap(_ info: UInt8, _ bytes: inout ArraySlice<UInt8>) throws -> CBORValue {
        let count = try decodeLength(info, &bytes)
        var entries: [(String, CBORValue)] = []
        for _ in 0..<count {
            let key = try decodeValue(&bytes)
            let value = try decodeValue(&bytes)
            guard let keyString = key.stringValue else { throw CBORError.invalidMapKey }
            entries.append((keyString, value))
        }
        return .map(entries)
    }

    private static func decodeSimple(_ info: UInt8, _ first: UInt8) throws -> CBORValue {
        switch info {
        case 20: return .bool(false)
        case 21: return .bool(true)
        case 22: return .null
        default: throw CBORError.unsupportedMajorType(first)
        }
    }

    private static func decodeLength(_ info: UInt8, _ bytes: inout ArraySlice<UInt8>) throws -> UInt64 {
        switch info {
        case 0..<24:
            return UInt64(info)
        case 24:
            return UInt64(try takeByte(&bytes))
        case 25:
            return try takeUInt(byteCount: 2, &bytes)
        case 26:
            return try takeUInt(byteCount: 4, &bytes)
        case 27:
            return try takeUInt(byteCount: 8, &bytes)
        default:
            throw CBORError.unsupportedMajorType(info)
        }
    }

    private static func takeByte(_ bytes: inout ArraySlice<UInt8>) throws -> UInt8 {
        guard let byte = bytes.popFirst() else { throw CBORError.truncated }
        return byte
    }

    private static func takeUInt(byteCount: Int, _ bytes: inout ArraySlice<UInt8>) throws -> UInt64 {
        guard bytes.count >= byteCount else { throw CBORError.truncated }
        var value: UInt64 = 0
        for _ in 0..<byteCount {
            value = (value << 8) | UInt64(bytes.removeFirst())
        }
        return value
    }

    private static func takeBytes(_ count: Int, _ bytes: inout ArraySlice<UInt8>) throws -> Data {
        guard bytes.count >= count else { throw CBORError.truncated }
        let taken = Data(bytes.prefix(count))
        bytes.removeFirst(count)
        return taken
    }
}
