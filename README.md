# SwiftLumen

SwiftLumen is a Swift framework for building applications with Large Language Models (LLMs). It provides a simple, type-safe API for interacting with LLMs like OpenAI's GPT models.

## Features

- 🔄 **Multiple LLM Providers**: Support for OpenAI and easy extension for other providers
- ⚡ **Async API Design**: Modern Swift concurrency with async/await
- 🧩 **Type-Safe**: Strong typing for requests and responses
- 🔌 **Middleware System**: Extensible middleware for request/response processing
- 💾 **Built-in Caching**: Efficient caching to reduce API calls
- 🧠 **Prompt Templates**: Simple templating for dynamic prompts
- 🛠️ **Function Calling**: Support for OpenAI's function calling feature

## Installation

### Swift Package Manager

Add SwiftLumen to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftLumen.git", from: "1.0.0")
]
```

## Quick Start

```swift
import SwiftLumen

// Initialize with your API key
let openAI = OpenAIProvider(apiKey: "your-api-key")
let lumen = Lumen(provider: openAI)

// Simple completion
Task {
    do {
        let response = try await lumen.complete("What is the capital of France?")
        print(response.text)
    } catch {
        print("Error: \(error)")
    }
}

// Streaming completion
Task {
    do {
        let stream = try await lumen.completeStream("Tell me a story about robots.")
        for try await chunk in stream {
            print(chunk.text, terminator: "")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

## Advanced Usage

### Using Middleware

```swift
// Add caching middleware
lumen.use(CacheMiddleware(ttl: 3600, maxEntries: 100))

// Create your own middleware
class LoggingMiddleware: LumenMiddleware {
    func processMessages(_ messages: [Message]) async throws -> [Message] {
        print("Sending \(messages.count) messages")
        return messages
    }
    
    func processResponse(_ response: CompletionResponse) async throws -> CompletionResponse {
        print("Received response: \(response.text.prefix(50))...")
        return response
    }
}

lumen.use(LoggingMiddleware())
```

### Prompt Templates

```swift
let template = PromptTemplate("Translate the following text to {{language}}: {{text}}")
let prompt = try template.format(
    "language", "French",
    "text", "Hello, world!"
)

let response = try await lumen.complete(prompt)
```

### Function Calling

```swift
let weatherFunction = FunctionDefinition(
    name: "get_weather",
    description: "Get the current weather in a location",
    parameters: [
        "type": "object",
        "properties": [
            "location": [
                "type": "string",
                "description": "The city and state, e.g. San Francisco, CA"
            ],
            "unit": [
                "type": "string",
                "enum": ["celsius", "fahrenheit"]
            ]
        ],
        "required": ["location"]
    ]
)

let tool = Tool(function: weatherFunction)

let response = try await lumen.complete(
    "What's the weather like in Paris?",
    options: CompletionOptions(
        model: "gpt-4o",
        tools: [tool]
    )
)

if let toolCalls = response.toolCalls {
    // Handle tool calls
}
```

### Custom Base URL

```swift
// For using with a proxy or compatible API
let openAI = OpenAIProvider(
    apiKey: "your-api-key",
    baseURL: URL(string: "https://your-proxy.com/v1")!,
    organization: "your-org-id" // Optional
)
```

## Project Structure

- **SwiftLumen**: Core framework
  - **Providers**: LLM service providers (OpenAI, etc.)
  - **Models**: Data models for requests and responses
  - **Middleware**: Request/response processing middleware
  - **Templates**: Prompt templating system
  - **Errors**: Error handling

## Development

### Requirements

- Swift 5.5+
- Xcode 13.0+

### Running Tests

```bash
swift test
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.