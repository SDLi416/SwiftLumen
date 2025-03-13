import Foundation

/// Represents a role in a conversation with an LLM
public enum MessageRole: String, Codable {
    case system
    case user
    case assistant
    case function
    case tool
}

/// Represents a message in a conversation with an LLM
public struct Message: Codable, Equatable, Identifiable {
    /// Unique identifier for the message
    public let id: UUID
    
    /// The role of the message sender
    public let role: MessageRole
    
    /// The content of the message
    public let content: String
    
    /// Optional name for the message sender (used for function/tool messages)
    public let name: String?
    
    /// Creation timestamp
    public let createdAt: Date
    
    /// Initialize a new message
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID)
    ///   - role: The role of the message sender
    ///   - content: The content of the message
    ///   - name: Optional name for the message sender
    ///   - createdAt: Creation timestamp (defaults to current date)
    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        name: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.name = name
        self.createdAt = createdAt
    }
    
    // Convenience initializers
    
    /// Create a system message
    public static func system(_ content: String) -> Message {
        Message(role: .system, content: content)
    }
    
    /// Create a user message
    public static func user(_ content: String) -> Message {
        Message(role: .user, content: content)
    }
    
    /// Create an assistant message
    public static func assistant(_ content: String) -> Message {
        Message(role: .assistant, content: content)
    }
    
    /// Create a function message
    public static func function(name: String, content: String) -> Message {
        Message(role: .function, content: content, name: name)
    }
    
    /// Create a tool message
    public static func tool(name: String, content: String) -> Message {
        Message(role: .tool, content: content, name: name)
    }
} 