import Foundation

public struct AIToolDefinition {
    public let name: String
    public let description: String
    public let jsonSchema: String
    
    public init(name: String, description: String, jsonSchema: String) {
        self.name = name
        self.description = description
        self.jsonSchema = jsonSchema
    }
}
