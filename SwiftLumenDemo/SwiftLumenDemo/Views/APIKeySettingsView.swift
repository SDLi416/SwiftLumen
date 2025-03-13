import SwiftUI

/// API密钥设置视图
struct APIKeySettingsView: View {
    /// 视图模型
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("OpenAI API密钥")) {
                    SecureField("输入您的API密钥", text: $viewModel.tempAPIKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                Section(header: Text("高级设置（可选）")) {
                    TextField("API基础URL", text: $viewModel.tempBaseURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    
                    TextField("组织ID", text: $viewModel.tempOrganization)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                Section {
                    Button("保存") {
                        viewModel.saveAPISettings()
                    }
                    .disabled(viewModel.tempAPIKey.isEmpty)
                }
                
                Section(header: Text("说明"), footer: Text("您的API密钥仅存储在设备上，不会发送到其他地方。")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("要使用此应用，您需要一个OpenAI API密钥。")
                        
                        Text("获取API密钥的步骤：")
                            .fontWeight(.bold)
                        
                        Text("1. 访问 platform.openai.com")
                        Text("2. 创建一个账户或登录")
                        Text("3. 导航到API密钥部分")
                        Text("4. 创建一个新的密钥")
                        Text("5. 复制并粘贴到上面的字段中")
                        
                        Divider()
                        
                        Text("高级设置说明：")
                            .fontWeight(.bold)
                        
                        Text("API基础URL：如果您使用的是OpenAI兼容的API（如Azure OpenAI或其他兼容服务），可以在此处指定基础URL。留空则使用OpenAI官方API。")
                            .font(.caption)
                        
                        Text("组织ID：如果您的OpenAI账户属于某个组织，可以在此处指定组织ID。大多数用户可以留空此项。")
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("API设置")
        }
    }
}

#Preview {
    APIKeySettingsView(viewModel: ChatViewModel())
} 