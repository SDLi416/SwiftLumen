import Foundation

/// Middleware for caching LLM responses
public class CacheMiddleware: LumenMiddleware {
    /// Cache entry
    private struct CacheEntry {
        let response: CompletionResponse
        let timestamp: Date
    }
    
    /// Cache storage
    private var cache: [String: CacheEntry] = [:]
    
    /// Time-to-live for cache entries
    private let ttl: TimeInterval
    
    /// Maximum number of entries in the cache
    private let maxEntries: Int
    
    /// Whether to cache streaming responses
    private let cacheStreaming: Bool
    
    /// Initialize a new cache middleware
    /// - Parameters:
    ///   - ttl: Time-to-live for cache entries in seconds (default: 1 hour)
    ///   - maxEntries: Maximum number of entries in the cache (default: 100)
    ///   - cacheStreaming: Whether to cache streaming responses (default: true)
    public init(ttl: TimeInterval = 3600, maxEntries: Int = 100, cacheStreaming: Bool = true) {
        self.ttl = ttl
        self.maxEntries = maxEntries
        self.cacheStreaming = cacheStreaming
    }
    
    /// Process a response from the provider
    /// - Parameter response: The response to process
    /// - Returns: The processed response
    public func processResponse(_ response: CompletionResponse) async throws -> CompletionResponse {
        // Store the response in the cache
        let key = try cacheKey(for: response.message)
        cache[key] = CacheEntry(response: response, timestamp: Date())
        
        // Prune the cache if it exceeds the maximum size
        if cache.count > maxEntries {
            pruneCache()
        }
        
        return response
    }
    
    /// Process messages before sending to the provider
    /// - Parameter messages: The messages to process
    /// - Returns: The processed messages
    public func processMessages(_ messages: [Message]) async throws -> [Message] {
        // Check if we have a cached response for these messages
        if let lastMessage = messages.last, lastMessage.role == .user {
            let key = try cacheKey(for: lastMessage)
            
            if let entry = cache[key], Date().timeIntervalSince(entry.timestamp) < ttl {
                // Throw a special error to short-circuit the request
                throw CacheHitError(response: entry.response)
            }
        }
        
        return messages
    }
    
    /// Process options before sending to the provider
    /// - Parameter options: The options to process
    /// - Returns: The processed options
    public func processOptions(_ options: CompletionOptions) async throws -> CompletionOptions {
        return options
    }
    
    /// Process a chunk from a streaming response
    /// - Parameter chunk: The chunk to process
    /// - Returns: The processed chunk
    public func processChunk(_ chunk: CompletionChunk) async throws -> CompletionChunk {
        // If this is the last chunk and streaming caching is enabled, cache the complete response
        if cacheStreaming && chunk.isComplete {
            let response = CompletionResponse(
                text: chunk.text,
                message: chunk.message,
                toolCalls: chunk.toolCalls
            )
            
            let key = try cacheKey(for: chunk.message)
            cache[key] = CacheEntry(response: response, timestamp: Date())
            
            // Prune the cache if it exceeds the maximum size
            if cache.count > maxEntries {
                pruneCache()
            }
        }
        
        return chunk
    }
    
    // MARK: - Private Methods
    
    /// Generate a cache key for a message
    /// - Parameter message: The message
    /// - Returns: A cache key
    private func cacheKey(for message: Message) throws -> String {
        let data = try JSONEncoder().encode(message)
        return data.base64EncodedString()
    }
    
    /// Prune the cache to remove old entries
    private func pruneCache() {
        let now = Date()
        
        // Remove expired entries
        cache = cache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) < ttl
        }
        
        // If still too large, remove oldest entries
        if cache.count > maxEntries {
            let sortedEntries = cache.sorted { $0.value.timestamp > $1.value.timestamp }
            let entriesToKeep = sortedEntries.prefix(maxEntries)
            cache = Dictionary(uniqueKeysWithValues: entriesToKeep.map { ($0.key, $0.value) })
        }
    }
}

/// Error thrown when a cache hit occurs
public struct CacheHitError: Error {
    public let response: CompletionResponse
} 