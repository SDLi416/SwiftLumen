import Foundation

/// Protocol defining the capabilities of an LLM provider
public protocol LLMProvider {
    /// The name of the provider
    var name: String { get }
    
    /// The default model to use
    var defaultModel: String { get }
    
    /// Available models for this provider
    var availableModels: [String] { get }
    
    /// Send a completion request to the LLM
    /// - Parameters:
    ///   - messages: The conversation history
    ///   - options: Options for the completion request
    /// - Returns: The completion response
    func complete(messages: [Message], options: CompletionOptions) async throws -> CompletionResponse
    
    /// Send a streaming completion request to the LLM
    /// - Parameters:
    ///   - messages: The conversation history
    ///   - options: Options for the completion request
    /// - Returns: An async sequence of completion chunks
    func completeStream(messages: [Message], options: CompletionOptions) async throws -> AsyncThrowingStream<CompletionChunk, Error>
}

/// Options for a completion request
public struct CompletionOptions {
    /// The model to use for the completion
    public let model: String
    
    /// The maximum number of tokens to generate
    public let maxTokens: Int?
    
    /// The temperature for sampling (0.0-2.0)
    public let temperature: Double?
    
    /// The top-p sampling parameter (0.0-1.0)
    public let topP: Double?
    
    /// Stop sequences that will end generation
    public let stopSequences: [String]?
    
    /// Function calling configuration
    public let tools: [Tool]?
    
    /// Whether to return JSON
    public let responseFormat: ResponseFormat?
    
    /// Initialize completion options
    /// - Parameters:
    ///   - model: The model to use
    ///   - maxTokens: Maximum tokens to generate
    ///   - temperature: Temperature for sampling
    ///   - topP: Top-p sampling parameter
    ///   - stopSequences: Stop sequences
    ///   - tools: Available tools
    ///   - responseFormat: Response format
    public init(
        model: String,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        stopSequences: [String]? = nil,
        tools: [Tool]? = nil,
        responseFormat: ResponseFormat? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.stopSequences = stopSequences
        self.tools = tools
        self.responseFormat = responseFormat
    }
}

/// Response format options
public enum ResponseFormat: String, Codable {
    case json
    case text
}

/// Represents a tool that can be called by the LLM
public struct Tool: Codable {
    /// The type of the tool
    public let type: ToolType
    
    /// The function definition
    public let function: FunctionDefinition
    
    /// Initialize a new tool
    /// - Parameters:
    ///   - type: The tool type
    ///   - function: The function definition
    public init(type: ToolType = .function, function: FunctionDefinition) {
        self.type = type
        self.function = function
    }
}

/// The type of a tool
public enum ToolType: String, Codable {
    case function
}

/// Defines a function that can be called by the LLM
public struct FunctionDefinition: Codable {
    /// The name of the function
    public let name: String
    
    /// Description of what the function does
    public let description: String
    
    /// The parameters of the function in JSON Schema format
    public let parameters: [String: Any]
    
    /// Initialize a new function definition
    /// - Parameters:
    ///   - name: The function name
    ///   - description: Function description
    ///   - parameters: Function parameters
    public init(name: String, description: String, parameters: [String: Any]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
    
    // Codable conformance for parameters dictionary
    private enum CodingKeys: String, CodingKey {
        case name, description, parameters
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        
        let parametersData = try container.decode(Data.self, forKey: .parameters)
        guard let parametersDict = try JSONSerialization.jsonObject(with: parametersData) as? [String: Any] else {
            throw DecodingError.dataCorruptedError(forKey: .parameters, in: container, debugDescription: "Parameters must be a dictionary")
        }
        parameters = parametersDict
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        
        let parametersData = try JSONSerialization.data(withJSONObject: parameters)
        try container.encode(parametersData, forKey: .parameters)
    }
}

/// Response from a completion request
public struct CompletionResponse {
    /// The generated text
    public let text: String
    
    /// The complete message object
    public let message: Message
    
    /// Tool calls made by the model
    public let toolCalls: [ToolCall]?
    
    /// Usage statistics
    public let usage: Usage?
    
    /// Initialize a completion response
    /// - Parameters:
    ///   - text: The generated text
    ///   - message: The complete message
    ///   - toolCalls: Tool calls made by the model
    ///   - usage: Usage statistics
    public init(
        text: String,
        message: Message,
        toolCalls: [ToolCall]? = nil,
        usage: Usage? = nil
    ) {
        self.text = text
        self.message = message
        self.toolCalls = toolCalls
        self.usage = usage
    }
}

/// A chunk of a streaming completion response
public struct CompletionChunk {
    /// The text in this chunk
    public let text: String
    
    /// The delta message object
    public let message: Message
    
    /// Tool calls in this chunk
    public let toolCalls: [ToolCall]?
    
    /// Whether this is the final chunk
    public let isComplete: Bool
    
    /// Initialize a completion chunk
    /// - Parameters:
    ///   - text: The text in this chunk
    ///   - message: The delta message
    ///   - toolCalls: Tool calls in this chunk
    ///   - isComplete: Whether this is the final chunk
    public init(
        text: String,
        message: Message,
        toolCalls: [ToolCall]? = nil,
        isComplete: Bool = false
    ) {
        self.text = text
        self.message = message
        self.toolCalls = toolCalls
        self.isComplete = isComplete
    }
}

/// Represents a tool call made by the model
public struct ToolCall: Codable, Identifiable {
    /// Unique identifier for the tool call
    public let id: String
    
    /// The type of the tool
    public let type: ToolType
    
    /// The function call
    public let function: FunctionCall
    
    /// Initialize a new tool call
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - type: The tool type
    ///   - function: The function call
    public init(id: String, type: ToolType, function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Represents a function call made by the model
public struct FunctionCall: Codable {
    /// The name of the function
    public let name: String
    
    /// The arguments passed to the function
    public let arguments: String
    
    /// Initialize a new function call
    /// - Parameters:
    ///   - name: The function name
    ///   - arguments: The function arguments as a JSON string
    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// Usage statistics for a completion request
public struct Usage: Codable {
    /// Number of prompt tokens
    public let promptTokens: Int
    
    /// Number of completion tokens
    public let completionTokens: Int
    
    /// Total number of tokens
    public let totalTokens: Int
    
    /// Initialize usage statistics
    /// - Parameters:
    ///   - promptTokens: Number of prompt tokens
    ///   - completionTokens: Number of completion tokens
    ///   - totalTokens: Total number of tokens
    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
} 