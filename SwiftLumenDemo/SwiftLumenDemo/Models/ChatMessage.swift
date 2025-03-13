import Foundation
import SwiftLumen

/// 表示聊天界面中的一条消息
struct ChatMessage: Identifiable {
    /// 消息的唯一标识符
    let id = UUID()
    
    /// 消息的发送者类型
    let sender: MessageSender
    
    /// 消息的内容
    var content: String
    
    /// 消息的发送时间
    let timestamp: Date
    
    /// 是否正在加载（用于流式响应）
    var isLoading: Bool = false
    
    /// 初始化一个新的聊天消息
    /// - Parameters:
    ///   - sender: 消息的发送者
    ///   - content: 消息的内容
    ///   - timestamp: 消息的发送时间（默认为当前时间）
    ///   - isLoading: 是否正在加载
    init(sender: MessageSender, content: String, timestamp: Date = Date(), isLoading: Bool = false) {
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.isLoading = isLoading
    }
    
    /// 从SwiftLumen的Message创建ChatMessage
    /// - Parameter message: SwiftLumen的Message对象
    /// - Returns: 对应的ChatMessage
    static func from(message: Message) -> ChatMessage {
        let sender: MessageSender = message.role == .user ? .user : .ai
        return ChatMessage(sender: sender, content: message.content)
    }
    
    /// 创建一个用户消息
    /// - Parameter content: 消息内容
    /// - Returns: 用户消息
    static func user(_ content: String) -> ChatMessage {
        return ChatMessage(sender: .user, content: content)
    }
    
    /// 创建一个AI消息
    /// - Parameter content: 消息内容
    /// - Returns: AI消息
    static func ai(_ content: String) -> ChatMessage {
        return ChatMessage(sender: .ai, content: content)
    }
    
    /// 创建一个加载中的AI消息
    /// - Returns: 加载中的AI消息
    static func loading() -> ChatMessage {
        return ChatMessage(sender: .ai, content: "", isLoading: true)
    }
}

/// 消息的发送者类型
enum MessageSender {
    /// 用户
    case user
    
    /// AI助手
    case ai
} 
