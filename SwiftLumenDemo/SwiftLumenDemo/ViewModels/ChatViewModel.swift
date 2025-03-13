import Foundation
import SwiftUI
import SwiftLumen

/// 管理聊天界面的视图模型
class ChatViewModel: ObservableObject {
    /// 聊天消息列表
    @Published var messages: [ChatMessage] = []
    
    /// 当前输入的消息
    @Published var inputMessage: String = ""
    
    /// 是否正在加载
    @Published var isLoading: Bool = false
    
    /// API密钥
    @AppStorage("apiKey") private var apiKey: String = ""
    
    /// API基础URL
    @AppStorage("baseURL") private var baseURLString: String = ""
    
    /// 组织ID
    @AppStorage("organization") private var organization: String = ""
    
    /// 是否显示API密钥设置
    @Published var showingAPIKeySettings: Bool = false
    
    /// 临时API密钥（用于设置）
    @Published var tempAPIKey: String = ""
    
    /// 临时API基础URL（用于设置）
    @Published var tempBaseURL: String = ""
    
    /// 临时组织ID（用于设置）
    @Published var tempOrganization: String = ""
    
    /// 是否使用流式响应
    @AppStorage("useStreaming") var useStreaming: Bool = true
    
    /// 初始化
    init() {
        // 如果没有API密钥，显示设置界面
        if apiKey.isEmpty {
            showingAPIKeySettings = true
        } else {
            // 配置LumenService
            configureService()
            
            // 添加欢迎消息
            messages.append(ChatMessage.ai("你好！我是由SwiftLumen驱动的AI助手。有什么我可以帮助你的吗？"))
        }
        
        // 初始化临时变量
        tempAPIKey = apiKey
        tempBaseURL = baseURLString
        tempOrganization = organization
    }
    
    /// 配置服务
    private func configureService() {
        var baseURL: URL? = nil
        if !baseURLString.isEmpty {
            baseURL = URL(string: baseURLString)
        }
        
        let org = organization.isEmpty ? nil : organization
        
        LumenService.shared.configure(
            apiKey: apiKey,
            baseURL: baseURL,
            organization: org
        )
    }
    
    /// 保存API设置
    func saveAPISettings() {
        apiKey = tempAPIKey
        baseURLString = tempBaseURL
        organization = tempOrganization
        
        showingAPIKeySettings = false
        
        // 配置LumenService
        configureService()
        
        // 添加欢迎消息
        messages.append(ChatMessage.ai("你好！我是由SwiftLumen驱动的AI助手。有什么我可以帮助你的吗？"))
    }
    
    /// 发送消息
    func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let userMessage = ChatMessage.user(inputMessage)
        messages.append(userMessage)
        
        let messageToSend = inputMessage
        inputMessage = ""
        
        if useStreaming {
            sendStreamingMessage(messageToSend)
        } else {
            sendRegularMessage(messageToSend)
        }
    }
    
    /// 发送常规消息
    /// - Parameter message: 要发送的消息
    private func sendRegularMessage(_ message: String) {
        isLoading = true
        
        // 添加一个加载中的消息
        let loadingMessage = ChatMessage.loading()
        messages.append(loadingMessage)
        
        Task {
            do {
                let response = try await LumenService.shared.sendMessage(message)
                
                await MainActor.run {
                    // 移除加载中的消息
                    messages.removeLast()
                    
                    // 添加AI的响应
                    messages.append(ChatMessage.ai(response))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // 移除加载中的消息
                    messages.removeLast()
                    
                    // 添加错误消息
                    messages.append(ChatMessage.ai("抱歉，发生了错误：\(error.localizedDescription)"))
                    isLoading = false
                }
            }
        }
    }
    
    /// 发送流式消息
    /// - Parameter message: 要发送的消息
    private func sendStreamingMessage(_ message: String) {
        isLoading = true
        
        // 添加一个空的AI消息，用于流式更新
        let streamingMessage = ChatMessage.ai("")
        messages.append(streamingMessage)
        
        // 保存消息索引，以便更新
        let messageIndex = messages.count - 1
        
        // 用于累积响应文本
        var responseText = ""
        
        Task {
            do {
                try await LumenService.shared.sendMessageStream(
                    message,
                    onChunk: { chunk in
                        responseText += chunk
                        
                        Task { @MainActor in
                            // 更新消息内容
                            if messageIndex < self.messages.count {
                                self.messages[messageIndex].content = responseText
                            }
                        }
                    },
                    onComplete: {
                        Task { @MainActor in
                            self.isLoading = false
                        }
                    }
                )
            } catch {
                await MainActor.run {
                    // 更新为错误消息
                    if messageIndex < messages.count {
                        messages[messageIndex].content = "抱歉，发生了错误：\(error.localizedDescription)"
                    }
                    isLoading = false
                }
            }
        }
    }
    
    /// 使用提示模板发送消息
    /// - Parameters:
    ///   - template: 模板字符串
    ///   - variables: 变量字典
    func sendTemplatedMessage(template: String, variables: [String: String]) {
        // 构建显示的消息内容
        var displayMessage = "使用模板：\(template)\n变量："
        for (key, value) in variables {
            displayMessage += "\n- \(key): \(value)"
        }
        
        let userMessage = ChatMessage.user(displayMessage)
        messages.append(userMessage)
        
        isLoading = true
        
        // 添加一个加载中的消息
        let loadingMessage = ChatMessage.loading()
        messages.append(loadingMessage)
        
        Task {
            do {
                let response = try await LumenService.shared.sendTemplatedMessage(
                    templateString: template,
                    variables: variables
                )
                
                await MainActor.run {
                    // 移除加载中的消息
                    messages.removeLast()
                    
                    // 添加AI的响应
                    messages.append(ChatMessage.ai(response))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // 移除加载中的消息
                    messages.removeLast()
                    
                    // 添加错误消息
                    messages.append(ChatMessage.ai("抱歉，发生了错误：\(error.localizedDescription)"))
                    isLoading = false
                }
            }
        }
    }
    
    /// 使用函数调用发送消息
    /// - Parameters:
    ///   - message: 要发送的消息
    ///   - functionName: 函数名称
    ///   - functionDescription: 函数描述
    ///   - parameters: 函数参数
    ///   - handler: 函数处理器
    func sendMessageWithFunctionCall(
        _ message: String,
        functionName: String,
        functionDescription: String,
        parameters: [String: Any],
        handler: @escaping (String, String) async -> String
    ) {
        let userMessage = ChatMessage.user(message)
        messages.append(userMessage)
        
        isLoading = true
        
        // 添加一个加载中的消息
        let loadingMessage = ChatMessage.loading()
        messages.append(loadingMessage)
        
        Task {
            do {
                let response = try await LumenService.shared.sendMessageWithFunctionCall(
                    message,
                    functionName: functionName,
                    functionDescription: functionDescription,
                    parameters: parameters,
                    onFunctionCall: handler
                )
                
                await MainActor.run {
                    // 移除加载中的消息
                    messages.removeLast()
                    
                    // 添加AI的响应
                    messages.append(ChatMessage.ai(response))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // 移除加载中的消息
                    messages.removeLast()
                    
                    // 添加错误消息
                    messages.append(ChatMessage.ai("抱歉，发生了错误：\(error.localizedDescription)"))
                    isLoading = false
                }
            }
        }
    }
    
    /// 获取天气示例函数
    /// - Parameters:
    ///   - location: 位置
    ///   - unit: 温度单位
    /// - Returns: 天气信息
    func getWeather(location: String, unit: String = "celsius") -> String {
        // 这只是一个模拟函数，实际应用中应该调用真实的天气API
        let temperature = Int.random(in: 0...35)
        let conditions = ["晴朗", "多云", "雨天", "雪天", "大风"].randomElement()!
        
        return "当前\(location)的天气：\(temperature)°\(unit == "celsius" ? "C" : "F")，\(conditions)。"
    }
} 
