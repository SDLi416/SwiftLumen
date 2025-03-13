import Foundation

/// Errors that can occur in the SwiftLumen framework
public enum LumenError: Error, LocalizedError {
    /// The provider returned an invalid response
    case invalidResponse
    
    /// An error occurred in the provider
    case providerError(provider: String, code: Int, message: String)
    
    /// The model is not supported by the provider
    case unsupportedModel(model: String, provider: String)
    
    /// The API key is missing
    case missingAPIKey
    
    /// The request timed out
    case timeout
    
    /// The request was rate limited
    case rateLimited(retryAfter: TimeInterval?)
    
    /// An error occurred while processing a tool call
    case toolCallError(name: String, error: Error)
    
    /// A middleware error occurred
    case middlewareError(middleware: String, error: Error)
    
    /// A template error occurred
    case templateError(message: String)
    
    /// A general error occurred
    case general(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The provider returned an invalid response"
        case .providerError(let provider, let code, let message):
            return "Error from \(provider) (code \(code)): \(message)"
        case .unsupportedModel(let model, let provider):
            return "Model '\(model)' is not supported by \(provider)"
        case .missingAPIKey:
            return "API key is missing"
        case .timeout:
            return "The request timed out"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Retry after \(retryAfter) seconds"
            } else {
                return "Rate limited"
            }
        case .toolCallError(let name, let error):
            return "Error in tool call '\(name)': \(error.localizedDescription)"
        case .middlewareError(let middleware, let error):
            return "Error in middleware '\(middleware)': \(error.localizedDescription)"
        case .templateError(let message):
            return "Template error: \(message)"
        case .general(let message):
            return message
        }
    }
} 