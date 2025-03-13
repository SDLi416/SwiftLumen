import Foundation
import SwiftLumen

/// 处理与SwiftLumen框架交互的服务
class LumenService {
    /// 单例实例
    static let shared = LumenService()
    
    /// Lumen实例
    private var lumen: Lumen?
    
    /// 私有初始化方法
    private init() {}
    
    /// 配置服务
    /// - Parameters:
    ///   - apiKey: OpenAI API密钥
    ///   - baseURL: API基础URL（可选，默认为OpenAI官方API）
    ///   - organization: 组织ID（可选）
    func configure(apiKey: String, baseURL: URL? = nil, organization: String? = nil) {
        // 创建OpenAI提供者
        let openAI: OpenAIProvider
        
        if let baseURL = baseURL {
            openAI = OpenAIProvider(apiKey: apiKey, baseURL: baseURL, organization: organization)
        } else {
            openAI = OpenAIProvider(apiKey: apiKey, organization: organization)
        }
        
        // 创建Lumen实例
        lumen = Lumen(provider: openAI)
        
        // 添加缓存中间件
        lumen?.use(CacheMiddleware())
    }
    
    /// 发送消息并获取响应
    /// - Parameter message: 要发送的消息
    /// - Returns: AI的响应
    func sendMessage(_ message: String) async throws -> String {
        guard let lumen = lumen else {
            throw NSError(domain: "LumenService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Lumen未配置"])
        }
        
        let response = try await lumen.complete(message)
        return response.text
    }
    
    /// 发送消息并获取流式响应
    /// - Parameters:
    ///   - message: 要发送的消息
    ///   - onChunk: 每收到一个响应块时的回调
    ///   - onComplete: 响应完成时的回调
    func sendMessageStream(_ message: String, onChunk: @escaping (String) -> Void, onComplete: @escaping () -> Void) async throws {
        guard let lumen = lumen else {
            throw NSError(domain: "LumenService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Lumen未配置"])
        }
        
        let stream = try await lumen.completeStream(message)
        
        for try await chunk in stream {
            onChunk(chunk.text)
            
            if chunk.isComplete {
                onComplete()
            }
        }
    }
    
    /// 使用提示模板发送消息
    /// - Parameters:
    ///   - templateString: 模板字符串
    ///   - variables: 变量字典
    /// - Returns: AI的响应
    func sendTemplatedMessage(templateString: String, variables: [String: String]) async throws -> String {
        guard let lumen = lumen else {
            throw NSError(domain: "LumenService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Lumen未配置"])
        }
        
        let template = PromptTemplate(templateString)
        let prompt = try template.format(variables: variables)
        
        let response = try await lumen.complete(prompt)
        return response.text
    }
    
    /// 使用函数调用发送消息
    /// - Parameters:
    ///   - message: 要发送的消息
    ///   - functionName: 函数名称
    ///   - functionDescription: 函数描述
    ///   - parameters: 函数参数
    ///   - onFunctionCall: 函数被调用时的回调
    /// - Returns: 最终的AI响应
    func sendMessageWithFunctionCall(
        _ message: String,
        functionName: String,
        functionDescription: String,
        parameters: [String: Any],
        onFunctionCall: @escaping (String, String) async -> String
    ) async throws -> String {
        guard let lumen = lumen else {
            throw NSError(domain: "LumenService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Lumen未配置"])
        }
        
        // 创建函数定义
        let functionDefinition = FunctionDefinition(
            name: functionName,
            description: functionDescription,
            parameters: parameters
        )
        
        // 创建工具
        let tool = Tool(function: functionDefinition)
        
        // 发送请求
        let response = try await lumen.complete(
            message,
            options: CompletionOptions(
                model: "gpt-4o-mini",
                tools: [tool]
            )
        )
        
        // 处理函数调用
        if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
            let toolCall = toolCalls[0]
            
            // 调用函数并获取结果
            let functionResult = await onFunctionCall(toolCall.function.name, toolCall.function.arguments)
            
            // 将函数结果发送回模型
            let messages: [Message] = [
                .user(message),
                .assistant(response.text),
                .tool(name: toolCall.function.name, content: functionResult)
            ]
            
            let finalResponse = try await lumen.complete(messages: messages)
            return finalResponse.text
        }
        
        return response.text
    }
} 
