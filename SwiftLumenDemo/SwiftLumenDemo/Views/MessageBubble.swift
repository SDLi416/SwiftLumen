import SwiftUI

/// 消息气泡视图
struct MessageBubble: View {
    /// 消息
    let message: ChatMessage
    
    /// 消息气泡的颜色
    private var backgroundColor: Color {
        message.sender == .user ? Color.blue : Color.gray.opacity(0.2)
    }
    
    /// 消息文本的颜色
    private var textColor: Color {
        message.sender == .user ? Color.white : Color.primary
    }
    
    /// 气泡的对齐方式
    private var alignment: Alignment {
        message.sender == .user ? .trailing : .leading
    }
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
            }
            
            if message.isLoading {
                LoadingView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(backgroundColor)
                    .cornerRadius(12)
            } else {
                Text(message.content)
                    .padding()
                    .foregroundColor(textColor)
                    .background(backgroundColor)
                    .cornerRadius(12)
                    .textSelection(.enabled)
            }
            
            if message.sender == .ai {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

/// 加载中视图
struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    VStack {
        MessageBubble(message: ChatMessage.user("你好，这是一条用户消息"))
        MessageBubble(message: ChatMessage.ai("你好！我是AI助手，有什么可以帮助你的吗？"))
        MessageBubble(message: ChatMessage.loading())
    }
} 