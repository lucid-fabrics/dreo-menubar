import Foundation

/// Consumes one slot of an unkeyed container without inspecting it. An empty
/// struct decodes successfully from any JSON value, which is what lets the
/// helper below skip past an element it could not parse.
private struct SkippedElement: Decodable {}

extension KeyedDecodingContainer {
    /// Decodes an array element by element, dropping entries that fail
    /// instead of failing the whole array, and treating a missing key as
    /// empty.
    ///
    /// Dreo ships a per-model UI schema blob whose shape varies by product,
    /// and adds new product types server-side without warning. A device the
    /// app has never seen (or one still being provisioned, which comes back
    /// with almost nothing in `controlsConf`) must not take down every other
    /// device on the account.
    func decodeLossyArray<T: Decodable>(_: T.Type, forKey key: Key) -> [T] {
        guard var container = try? nestedUnkeyedContainer(forKey: key) else { return [] }
        var result: [T] = []
        while !container.isAtEnd {
            if let element = try? container.decode(T.self) {
                result.append(element)
            } else if (try? container.decode(SkippedElement.self)) == nil {
                // Could not even skip the slot, so the container can't be
                // advanced any further. Stop rather than spin forever.
                break
            }
        }
        return result
    }
}
