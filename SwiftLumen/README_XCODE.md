# SwiftLumen Xcode项目设置指南

为了将新创建的源文件添加到Xcode项目中，请按照以下步骤操作：

1. 打开Xcode项目：
   ```
   open SwiftLumen/SwiftLumen.xcodeproj
   ```

2. 在Xcode的项目导航器中，右键点击`SwiftLumen`目标下的`SwiftLumen`文件夹，选择"Add Files to 'SwiftLumen'..."

3. 在弹出的文件选择器中，导航到以下文件并添加它们：
   - `SwiftLumen/SwiftLumen/Lumen.swift`
   - `SwiftLumen/SwiftLumen/Models/Message.swift`
   - `SwiftLumen/SwiftLumen/Providers/LLMProvider.swift`
   - `SwiftLumen/SwiftLumen/Providers/OpenAIProvider.swift`
   - `SwiftLumen/SwiftLumen/Middleware/CacheMiddleware.swift`
   - `SwiftLumen/SwiftLumen/Templates/PromptTemplate.swift`
   - `SwiftLumen/SwiftLumen/Errors/LumenError.swift`

4. 确保在添加文件时选择"Copy items if needed"和"Create groups"选项。

5. 对于测试文件，右键点击`SwiftLumenTests`目标下的`SwiftLumenTests`文件夹，选择"Add Files to 'SwiftLumenTests'..."，然后添加：
   - `SwiftLumen/SwiftLumenTests/LumenTests.swift`

6. 对于示例文件，您可以创建一个新的目标（如命令行工具）来运行示例，或者将其保留在项目中作为参考：
   - `SwiftLumen/Examples/SimpleExample.swift`

7. 构建项目（Command+B）以确保所有文件都已正确添加并且没有编译错误。

## 项目结构

完成上述步骤后，您的项目结构应该如下所示：

```
SwiftLumen/
├── SwiftLumen.xcodeproj/
├── SwiftLumen/
│   ├── SwiftLumen.h
│   ├── Lumen.swift
│   ├── Models/
│   │   └── Message.swift
│   ├── Providers/
│   │   ├── LLMProvider.swift
│   │   └── OpenAIProvider.swift
│   ├── Middleware/
│   │   └── CacheMiddleware.swift
│   ├── Templates/
│   │   └── PromptTemplate.swift
│   └── Errors/
│       └── LumenError.swift
├── SwiftLumenTests/
│   └── LumenTests.swift
└── Examples/
    └── SimpleExample.swift
```

## 注意事项

- 确保在SwiftLumen.h文件中公开必要的头文件。
- 如果您计划将此框架分发给其他开发者，请确保所有公共API都有适当的文档注释。
- 考虑添加一个示例应用程序目标，以展示如何使用您的框架。

## 创建示例应用程序

如果您想创建一个示例应用程序来展示如何使用SwiftLumen框架，可以按照以下步骤操作：

1. 在Xcode中，选择File > New > Project...
2. 选择macOS > Command Line Tool，点击Next
3. 输入产品名称（如"SwiftLumenExample"），选择语言为Swift，点击Next
4. 选择保存位置，确保"Add to:"选择了SwiftLumen工作空间，点击Create
5. 在新创建的目标中，添加对SwiftLumen框架的依赖：
   - 选择项目导航器中的示例应用程序目标
   - 选择"General"选项卡
   - 在"Frameworks, Libraries, and Embedded Content"部分，点击"+"按钮
   - 选择SwiftLumen.framework，点击Add
6. 在示例应用程序的main.swift文件中，使用SwiftLumen框架的功能，例如：

```swift
import Foundation
import SwiftLumen

// 创建OpenAI提供商
let openAI = OpenAIProvider(apiKey: "your-api-key")

// 创建Lumen实例
let lumen = Lumen(provider: openAI)

// 发送请求
Task {
    do {
        let response = try await lumen.complete("Hello, world!")
        print(response.text)
        exit(0)
    } catch {
        print("Error: \(error)")
        exit(1)
    }
}

// 保持主线程运行，直到异步任务完成
RunLoop.main.run() 