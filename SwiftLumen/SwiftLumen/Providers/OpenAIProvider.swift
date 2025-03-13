import Foundation

/// Provider for OpenAI's API
public class OpenAIProvider: LLMProvider {
    /// The name of the provider
    public let name = "OpenAI"
    
    /// The default model to use
    public let defaultModel = "gpt-4o"
    
    /// Available models for this provider
    public let availableModels = [
        "gpt-4o",
        "gpt-4o-mini",
        "gpt-4-turbo",
        "gpt-4",
        "gpt-3.5-turbo"
    ]
    
    /// The API key for authentication
    private let apiKey: String
    
    /// The base URL for the API
    private let baseURL: URL
    
    /// The organization ID (optional)
    private let organization: String?
    
    /// Initialize a new OpenAI provider
    /// - Parameters:
    ///   - apiKey: The API key for authentication
    ///   - baseURL: The base URL for the API (defaults to OpenAI's API)
    ///   - organization: The organization ID (optional)
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        organization: String? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.organization = organization
    }
    
    /// Send a completion request to OpenAI
    /// - Parameters:
    ///   - messages: The conversation history
    ///   - options: Options for the completion request
    /// - Returns: The completion response
    public func complete(messages: [Message], options: CompletionOptions) async throws -> CompletionResponse {
        let requestBody = try createRequestBody(messages: messages, options: options)
        let request = try createRequest(endpoint: "/chat/completions", body: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LumenError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw try handleErrorResponse(data: data, statusCode: httpResponse.statusCode)
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAICompletionResponse.self, from: data)
        return try mapToCompletionResponse(openAIResponse)
    }
    
    /// Send a streaming completion request to OpenAI
    /// - Parameters:
    ///   - messages: The conversation history
    ///   - options: Options for the completion request
    /// - Returns: An async sequence of completion chunks
    public func completeStream(messages: [Message], options: CompletionOptions) async throws -> AsyncThrowingStream<CompletionChunk, Error> {
        var requestBody = try createRequestBody(messages: messages, options: options)
        requestBody["stream"] = true
        
        let request = try createRequest(endpoint: "/chat/completions", body: requestBody)
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LumenError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var data = Data()
            for try await byte in asyncBytes {
                data.append(byte)
            }
            throw try handleErrorResponse(data: data, statusCode: httpResponse.statusCode)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var fullContent = ""
                    var buffer = ""
                    
                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = line.dropFirst(6)
                            
                            if data == "[DONE]" {
                                let finalChunk = CompletionChunk(
                                    text: "",
                                    message: Message.assistant(""),
                                    isComplete: true
                                )
                                continuation.yield(finalChunk)
                                continuation.finish()
                                break
                            }
                            
                            guard let chunkData = data.data(using: .utf8) else {
                                continue
                            }
                            
                            let chunkResponse = try JSONDecoder().decode(OpenAICompletionChunkResponse.self, from: chunkData)
                            
                            if let choice = chunkResponse.choices.first,
                               let content = choice.delta.content {
                                fullContent += content
                                buffer += content
                                
                                let chunk = CompletionChunk(
                                    text: content,
                                    message: Message.assistant(fullContent)
                                )
                                
                                continuation.yield(chunk)
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createRequestBody(messages: [Message], options: CompletionOptions) throws -> [String: Any] {
        var body: [String: Any] = [
            "model": options.model,
            "messages": messages.map { message in
                var messageDict: [String: Any] = [
                    "role": message.role.rawValue,
                    "content": message.content
                ]
                
                if let name = message.name {
                    messageDict["name"] = name
                }
                
                return messageDict
            }
        ]
        
        if let maxTokens = options.maxTokens {
            body["max_tokens"] = maxTokens
        }
        
        if let temperature = options.temperature {
            body["temperature"] = temperature
        }
        
        if let topP = options.topP {
            body["top_p"] = topP
        }
        
        if let stopSequences = options.stopSequences {
            body["stop"] = stopSequences
        }
        
        if let tools = options.tools {
            body["tools"] = tools.map { tool in
                var toolDict: [String: Any] = [
                    "type": tool.type.rawValue,
                    "function": [
                        "name": tool.function.name,
                        "description": tool.function.description,
                        "parameters": tool.function.parameters
                    ]
                ]
                return toolDict
            }
        }
        
        if let responseFormat = options.responseFormat {
            body["response_format"] = ["type": responseFormat.rawValue]
        }
        
        return body
    }
    
    private func createRequest(endpoint: String, body: [String: Any]) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        if let organization = organization {
            request.addValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    private func handleErrorResponse(data: Data, statusCode: Int) throws -> Error {
        do {
            let errorResponse = try JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            return LumenError.providerError(
                provider: name,
                code: statusCode,
                message: errorResponse.error.message
            )
        } catch {
            return LumenError.providerError(
                provider: name,
                code: statusCode,
                message: "Unknown error"
            )
        }
    }
    
    private func mapToCompletionResponse(_ response: OpenAICompletionResponse) throws -> CompletionResponse {
        guard let choice = response.choices.first else {
            throw LumenError.invalidResponse
        }
        
        let content = choice.message.content ?? ""
        
        let message = Message(
            role: MessageRole(rawValue: choice.message.role) ?? .assistant,
            content: content,
            name: choice.message.name
        )
        
        var toolCalls: [ToolCall]?
        if let openAIToolCalls = choice.message.toolCalls, !openAIToolCalls.isEmpty {
            toolCalls = openAIToolCalls.map { toolCall in
                ToolCall(
                    id: toolCall.id,
                    type: ToolType(rawValue: toolCall.type) ?? .function,
                    function: FunctionCall(
                        name: toolCall.function.name,
                        arguments: toolCall.function.arguments
                    )
                )
            }
        }
        
        var usage: Usage?
        if let openAIUsage = response.usage {
            usage = Usage(
                promptTokens: openAIUsage.promptTokens,
                completionTokens: openAIUsage.completionTokens,
                totalTokens: openAIUsage.totalTokens
            )
        }
        
        return CompletionResponse(
            text: content,
            message: message,
            toolCalls: toolCalls,
            usage: usage
        )
    }
}

// MARK: - OpenAI API Models

private struct OpenAICompletionResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

private struct OpenAIChoice: Decodable {
    let index: Int
    let message: OpenAIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

private struct OpenAIMessage: Decodable {
    let role: String
    let content: String?
    let name: String?
    let toolCalls: [OpenAIToolCall]?
    
    enum CodingKeys: String, CodingKey {
        case role, content, name
        case toolCalls = "tool_calls"
    }
}

private struct OpenAIToolCall: Decodable {
    let id: String
    let type: String
    let function: OpenAIFunctionCall
}

private struct OpenAIFunctionCall: Decodable {
    let name: String
    let arguments: String
}

private struct OpenAIUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

private struct OpenAICompletionChunkResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChunkChoice]
}

private struct OpenAIChunkChoice: Decodable {
    let index: Int
    let delta: OpenAIDelta
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

private struct OpenAIDelta: Decodable {
    let role: String?
    let content: String?
    let toolCalls: [OpenAIToolCall]?
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }
}

private struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError
}

private struct OpenAIError: Decodable {
    let message: String
    let type: String?
    let param: String?
    let code: String?
} 