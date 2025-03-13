import SwiftUI

/// 功能演示视图
struct FeaturesView: View {
    /// 视图模型
    @ObservedObject var viewModel: ChatViewModel
    
    /// 是否显示提示模板演示
    @State private var showingTemplateDemo = false
    
    /// 是否显示函数调用演示
    @State private var showingFunctionDemo = false
    
    /// 模板文本
    @State private var templateText = "将以下文本翻译成{{language}}：{{text}}"
    
    /// 语言
    @State private var language = "法语"
    
    /// 要翻译的文本
    @State private var textToTranslate = "你好，世界！"
    
    /// 天气查询位置
    @State private var weatherLocation = "北京"
    
    var body: some View {
        List {
            Section(header: Text("流式响应")) {
                Toggle("启用流式响应", isOn: $viewModel.useStreaming)
                
                Text("流式响应可以让AI的回复实时显示，就像打字一样。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("提示模板")) {
                Button("演示提示模板") {
                    showingTemplateDemo = true
                }
                
                Text("提示模板允许您创建带有变量的模板，然后用实际值填充这些变量。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .sheet(isPresented: $showingTemplateDemo) {
                TemplateDemoView(viewModel: viewModel, templateText: $templateText, language: $language, textToTranslate: $textToTranslate)
            }
            
            Section(header: Text("函数调用")) {
                Button("演示函数调用") {
                    showingFunctionDemo = true
                }
                
                Text("函数调用允许AI调用您定义的函数，例如获取天气信息。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .sheet(isPresented: $showingFunctionDemo) {
                FunctionDemoView(viewModel: viewModel, location: $weatherLocation)
            }
            
            Section(header: Text("API设置")) {
                Button("更改API设置") {
                    viewModel.showingAPIKeySettings = true
                }
                
                Text("您可以更改API密钥、基础URL和组织ID等设置。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("SwiftLumen功能")
    }
}

/// 提示模板演示视图
struct TemplateDemoView: View {
    /// 视图模型
    @ObservedObject var viewModel: ChatViewModel
    
    /// 是否显示此视图
    @Environment(\.dismiss) private var dismiss
    
    /// 模板文本
    @Binding var templateText: String
    
    /// 语言
    @Binding var language: String
    
    /// 要翻译的文本
    @Binding var textToTranslate: String
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("模板")) {
                    TextField("模板", text: $templateText)
                }
                
                Section(header: Text("变量")) {
                    TextField("语言", text: $language)
                    TextField("文本", text: $textToTranslate)
                }
                
                Section {
                    Button("发送") {
                        viewModel.sendTemplatedMessage(
                            template: templateText,
                            variables: [
                                "language": language,
                                "text": textToTranslate
                            ]
                        )
                        dismiss()
                    }
                }
            }
            .navigationTitle("提示模板演示")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 函数调用演示视图
struct FunctionDemoView: View {
    /// 视图模型
    @ObservedObject var viewModel: ChatViewModel
    
    /// 是否显示此视图
    @Environment(\.dismiss) private var dismiss
    
    /// 位置
    @Binding var location: String
    
    /// 温度单位
    @State private var unit = "celsius"
    
    /// 可用的温度单位
    private let units = ["celsius", "fahrenheit"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("天气查询")) {
                    TextField("位置", text: $location)
                    
                    Picker("温度单位", selection: $unit) {
                        ForEach(units, id: \.self) { unit in
                            Text(unit == "celsius" ? "摄氏度" : "华氏度")
                        }
                    }
                }
                
                Section {
                    Button("查询天气") {
                        // 创建函数参数
                        let parameters: [String: Any] = [
                            "type": "object",
                            "properties": [
                                "location": [
                                    "type": "string",
                                    "description": "位置，例如：北京"
                                ],
                                "unit": [
                                    "type": "string",
                                    "enum": ["celsius", "fahrenheit"],
                                    "description": "温度单位"
                                ]
                            ],
                            "required": ["location"]
                        ]
                        
                        // 发送带有函数调用的消息
                        viewModel.sendMessageWithFunctionCall(
                            "请告诉我\(location)的天气如何？",
                            functionName: "get_weather",
                            functionDescription: "获取指定位置的天气信息",
                            parameters: parameters,
                            handler: { name, arguments in
                                // 解析参数
                                do {
                                    if let data = arguments.data(using: .utf8),
                                       let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                       let location = json["location"] as? String {
                                        let unit = (json["unit"] as? String) ?? "celsius"
                                        return viewModel.getWeather(location: location, unit: unit)
                                    }
                                } catch {
                                    print("解析参数错误：\(error)")
                                }
                                
                                return viewModel.getWeather(location: location, unit: unit)
                            }
                        )
                        
                        dismiss()
                    }
                }
            }
            .navigationTitle("函数调用演示")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FeaturesView(viewModel: ChatViewModel())
} 