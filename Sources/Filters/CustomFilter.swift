import Foundation

struct CustomFilter: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var parameters: FilterParameters

    func asPreset() -> FilterPreset {
        let shortCode = String(name.prefix(4)).uppercased()
        return FilterPreset(
            id: id.uuidString,
            name: name,
            code: shortCode.isEmpty ? "CSTM" : shortCode,
            isBuiltIn: false,
            parameters: parameters
        )
    }
}
