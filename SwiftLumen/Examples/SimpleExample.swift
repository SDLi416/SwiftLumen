import Foundation
import SwiftLumen

/// A simple example of using SwiftLumen
struct SimpleExample {
    /// Run the example
    static func run() async {
        do {
            // Create an OpenAI provider
            let openAI = OpenAIProvider(apiKey: "your-api-key")
            
            // Create a Lumen instance
            let lumen = Lumen(provider: openAI)
            
            // Add cache middleware
            lumen.use(CacheMiddleware())
            
            // Send a simple completion request
            print("Sending completion request...")
            let response = try await lumen.complete("What is the capital of France?")
            print("Response: \(response.text)")
            
            // Send a streaming completion request
            print("\nSending streaming request...")
            let stream = try await lumen.completeStream("Tell me a short story about a robot.")
            
            print("Stream response:")
            for try await chunk in stream {
                print(chunk.text, terminator: "")
            }
            print("\n")
            
            // Use a prompt template
            print("\nUsing prompt template...")
            let template = PromptTemplate("Translate the following text to {{language}}: {{text}}")
            let prompt = try template.format(
                "language", "French",
                "text", "Hello, world!"
            )
            
            let translationResponse = try await lumen.complete(prompt)
            print("Translation: \(translationResponse.text)")
            
            // Use function calling
            print("\nUsing function calling...")
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
                            "enum": ["celsius", "fahrenheit"],
                            "description": "The temperature unit to use"
                        ]
                    ],
                    "required": ["location"]
                ]
            )
            
            let tool = Tool(function: weatherFunction)
            
            let functionResponse = try await lumen.complete(
                "What's the weather like in Paris?",
                options: CompletionOptions(
                    model: "gpt-4o",
                    tools: [tool]
                )
            )
            
            if let toolCalls = functionResponse.toolCalls {
                for toolCall in toolCalls {
                    print("Function call: \(toolCall.function.name)")
                    print("Arguments: \(toolCall.function.arguments)")
                    
                    // In a real app, you would call the actual function here
                    // and then send the result back to the model
                    
                    let weatherResult = "The weather in Paris is 22°C and sunny."
                    
                    let messages: [Message] = [
                        .user("What's the weather like in Paris?"),
                        .assistant(functionResponse.text),
                        .tool(name: toolCall.function.name, content: weatherResult)
                    ]
                    
                    let finalResponse = try await lumen.complete(messages: messages)
                    print("\nFinal response: \(finalResponse.text)")
                }
            } else {
                print("No function calls made.")
            }
            
        } catch {
            print("Error: \(error)")
        }
    }
}

// Run the example
Task {
    await SimpleExample.run()
    
    // Exit the program
    exit(0)
} 