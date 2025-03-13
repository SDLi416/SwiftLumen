import XCTest
@testable import SwiftLumen

final class LumenTests: XCTestCase {
    func testMessageCreation() {
        let systemMessage = Message.system("You are a helpful assistant.")
        XCTAssertEqual(systemMessage.role, .system)
        XCTAssertEqual(systemMessage.content, "You are a helpful assistant.")
        
        let userMessage = Message.user("Hello, world!")
        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(userMessage.content, "Hello, world!")
        
        let assistantMessage = Message.assistant("I'm here to help.")
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.content, "I'm here to help.")
        
        let functionMessage = Message.function(name: "get_weather", content: "{\"temperature\": 22, \"unit\": \"celsius\"}")
        XCTAssertEqual(functionMessage.role, .function)
        XCTAssertEqual(functionMessage.content, "{\"temperature\": 22, \"unit\": \"celsius\"}")
        XCTAssertEqual(functionMessage.name, "get_weather")
    }
    
    func testPromptTemplate() throws {
        let template = PromptTemplate("Hello, {{name}}! The weather is {{weather}}.")
        
        let result = try template.format(variables: ["name": "Alice", "weather": "sunny"])
        XCTAssertEqual(result, "Hello, Alice! The weather is sunny.")
        
        let result2 = try template.format("name", "Bob", "weather", "rainy")
        XCTAssertEqual(result2, "Hello, Bob! The weather is rainy.")
        
        XCTAssertThrowsError(try template.format(variables: ["name": "Charlie"])) { error in
            guard case LumenError.templateError(let message) = error else {
                XCTFail("Expected LumenError.templateError")
                return
            }
            XCTAssertTrue(message.contains("Missing variable: weather"))
        }
    }
    
    func testMockProvider() async throws {
        let provider = MockLLMProvider()
        let lumen = Lumen(provider: provider)
        
        let response = try await lumen.complete("Hello")
        XCTAssertEqual(response.text, "Hello, I'm a mock response!")
        
        let stream = try await lumen.completeStream("Hello")
        var streamedText = ""
        for try await chunk in stream {
            streamedText += chunk.text
        }
        XCTAssertEqual(streamedText, "Hello, I'm a mock response!")
    }
    
    func testMiddleware() async throws {
        let provider = MockLLMProvider()
        let lumen = Lumen(provider: provider)
        
        // Add a middleware that adds a prefix to responses
        lumen.use(PrefixMiddleware(prefix: "PREFIX: "))
        
        let response = try await lumen.complete("Hello")
        XCTAssertEqual(response.text, "PREFIX: Hello, I'm a mock response!")
    }
}

// MARK: - Test Helpers

/// A mock LLM provider for testing
class MockLLMProvider: LLMProvider {
    var name: String = "Mock"
    var defaultModel: String = "mock-model"
    var availableModels: [String] = ["mock-model"]
    
    func complete(messages: [Message], options: CompletionOptions) async throws -> CompletionResponse {
        let content = "Hello, I'm a mock response!"
        let message = Message.assistant(content)
        return CompletionResponse(text: content, message: message)
    }
    
    func completeStream(messages: [Message], options: CompletionOptions) async throws -> AsyncThrowingStream<CompletionChunk, Error> {
        let content = "Hello, I'm a mock response!"
        
        return AsyncThrowingStream { continuation in
            Task {
                let message = Message.assistant(content)
                let chunk = CompletionChunk(text: content, message: message, isComplete: true)
                continuation.yield(chunk)
                continuation.finish()
            }
        }
    }
}

/// A middleware that adds a prefix to responses
class PrefixMiddleware: LumenMiddleware {
    let prefix: String
    
    init(prefix: String) {
        self.prefix = prefix
    }
    
    func processResponse(_ response: CompletionResponse) async throws -> CompletionResponse {
        let newText = prefix + response.text
        let newMessage = Message(
            id: response.message.id,
            role: response.message.role,
            content: newText,
            name: response.message.name,
            createdAt: response.message.createdAt
        )
        
        return CompletionResponse(
            text: newText,
            message: newMessage,
            toolCalls: response.toolCalls,
            usage: response.usage
        )
    }
    
    func processChunk(_ chunk: CompletionChunk) async throws -> CompletionChunk {
        if chunk.isComplete {
            let newText = prefix + chunk.text
            let newMessage = Message(
                id: chunk.message.id,
                role: chunk.message.role,
                content: newText,
                name: chunk.message.name,
                createdAt: chunk.message.createdAt
            )
            
            return CompletionChunk(
                text: newText,
                message: newMessage,
                toolCalls: chunk.toolCalls,
                isComplete: true
            )
        }
        
        return chunk
    }
} 