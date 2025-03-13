import SwiftUI

/// 聊天视图
struct ChatView: View {
    /// 视图模型
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // 消息列表
                ScrollView {
                    LazyVStack {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                }
                .padding(.top)
                
                // 输入区域
                HStack {
                    TextField("输入消息...", text: $viewModel.inputMessage)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(20)
                        .disabled(viewModel.isLoading)
                    
                    Button(action: {
                        viewModel.sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                    }
                    .disabled(viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle("SwiftLumen聊天")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: FeaturesView(viewModel: viewModel)) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAPIKeySettings) {
                APIKeySettingsView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    ChatView()
} 