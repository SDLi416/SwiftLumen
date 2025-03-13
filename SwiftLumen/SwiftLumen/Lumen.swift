import Foundation

// CacheHitError is in the same module, no special import needed

/// Main class for interacting with LLMs
public class Lumen {
    /// The LLM provider
    private let provider: LLMProvider
    
    /// Middleware for processing requests and responses
    private var middleware: [LumenMiddleware] = []
    
    /// Initialize a new Lumen instance
    /// - Parameter provider: The LLM provider to use
    public init(provider: LLMProvider) {
        self.provider = provider
    }
    
    /// Add middleware to the processing pipeline
    /// - Parameter middleware: The middleware to add
    /// - Returns: Self for chaining
    @discardableResult
    public func use(_ middleware: LumenMiddleware) -> Self {
        self.middleware.append(middleware)
        return self
    }
    
    /// Send a completion request with a single prompt
    /// - Parameters:
    ///   - prompt: The prompt text
    ///   - options: Options for the completion request
    /// - Returns: The completion response
    public func complete(_ prompt: String, options: CompletionOptions? = nil) async throws -> CompletionResponse {
        let message = Message.user(prompt)
        return try await complete(messages: [message], options: options)
    }
    
    /// Send a completion request with multiple messages
    /// - Parameters:
    ///   - messages: The conversation history
    ///   - options: Options for the completion request
    /// - Returns: The completion response
    public func complete(messages: [Message], options: CompletionOptions? = nil) async throws -> CompletionResponse {
        do {
            return try await _complete(messages: messages, options: options)
        } catch let error as CacheHitError {
            // If it's a cache hit, directly return the cached response
            return error.response
        }
    }
    
    /// Internal implementation of complete
    private func _complete(messages: [Message], options: CompletionOptions? = nil) async throws -> CompletionResponse {
        let completionOptions = options ?? CompletionOptions(model: provider.defaultModel)
        
        // Apply middleware to messages
        var processedMessages = messages
        for middleware in middleware {
            processedMessages = try await middleware.processMessages(processedMessages)
        }
        
        // Apply middleware to options
        var processedOptions = completionOptions
        for middleware in middleware {
            processedOptions = try await middleware.processOptions(processedOptions)
        }
        
        // Send request to provider
        var response = try await provider.complete(messages: processedMessages, options: processedOptions)
        
        // Apply middleware to response
        for middleware in middleware {
            response = try await middleware.processResponse(response)
        }
        
        return response
    }
    
    /// Send a streaming completion request with a single prompt
    /// - Parameters:
    ///   - prompt: The prompt text
    ///   - options: Options for the completion request
    /// - Returns: An async sequence of completion chunks
    public func completeStream(_ prompt: String, options: CompletionOptions? = nil) async throws -> AsyncThrowingStream<CompletionChunk, Error> {
        let message = Message.user(prompt)
        return try await completeStream(messages: [message], options: options)
    }
    
    /// Send a streaming completion request with multiple messages
    /// - Parameters:
    ///   - messages: The conversation history
    ///   - options: Options for the completion request
    /// - Returns: An async sequence of completion chunks
    public func completeStream(messages: [Message], options: CompletionOptions? = nil) async throws -> AsyncThrowingStream<CompletionChunk, Error> {
        do {
            return try await _completeStream(messages: messages, options: options)
        } catch let error as CacheHitError {
            // If it's a cache hit, create a stream with a single chunk containing the cached response
            return AsyncThrowingStream { continuation in
                let response = error.response
                let chunk = CompletionChunk(
                    text: response.text,
                    message: response.message,
                    toolCalls: response.toolCalls,
                    isComplete: true
                )
                continuation.yield(chunk)
                continuation.finish()
            }
        }
    }
    
    /// Internal implementation of completeStream
    private func _completeStream(messages: [Message], options: CompletionOptions? = nil) async throws -> AsyncThrowingStream<CompletionChunk, Error> {
        let completionOptions = options ?? CompletionOptions(model: provider.defaultModel)
        
        // Apply middleware to messages
        var processedMessages = messages
        for middleware in middleware {
            processedMessages = try await middleware.processMessages(processedMessages)
        }
        
        // Apply middleware to options
        var processedOptions = completionOptions
        for middleware in middleware {
            processedOptions = try await middleware.processOptions(processedOptions)
        }
        
        // Send request to provider
        let stream = try await provider.completeStream(messages: processedMessages, options: processedOptions)
        
        // Apply middleware to chunks
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in stream {
                        var processedChunk = chunk
                        
                        for middleware in self.middleware {
                            processedChunk = try await middleware.processChunk(processedChunk)
                        }
                        
                        continuation.yield(processedChunk)
                        
                        if processedChunk.isComplete {
                            continuation.finish()
                            break
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

/// Protocol for middleware that can process requests and responses
public protocol LumenMiddleware {
    /// Process messages before sending to the provider
    /// - Parameter messages: The messages to process
    /// - Returns: The processed messages
    func processMessages(_ messages: [Message]) async throws -> [Message]
    
    /// Process options before sending to the provider
    /// - Parameter options: The options to process
    /// - Returns: The processed options
    func processOptions(_ options: CompletionOptions) async throws -> CompletionOptions
    
    /// Process a response from the provider
    /// - Parameter response: The response to process
    /// - Returns: The processed response
    func processResponse(_ response: CompletionResponse) async throws -> CompletionResponse
    
    /// Process a chunk from a streaming response
    /// - Parameter chunk: The chunk to process
    /// - Returns: The processed chunk
    func processChunk(_ chunk: CompletionChunk) async throws -> CompletionChunk
}

/// Default implementation of LumenMiddleware
public extension LumenMiddleware {
    func processMessages(_ messages: [Message]) async throws -> [Message] {
        return messages
    }
    
    func processOptions(_ options: CompletionOptions) async throws -> CompletionOptions {
        return options
    }
    
    func processResponse(_ response: CompletionResponse) async throws -> CompletionResponse {
        return response
    }
    
    func processChunk(_ chunk: CompletionChunk) async throws -> CompletionChunk {
        return chunk
    }
} 