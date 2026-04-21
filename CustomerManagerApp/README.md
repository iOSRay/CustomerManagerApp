# CustomerManagerApp (iOS 17+)

SwiftUI 客户管理 App 工程，包含：
- 统计首页 -> 扫描记录列表（push）-> 详情页
- 原生网络层封装（`URLSession` + `APIEndpoint` + `APIClient`）
- 筛选弹窗（sheet）
- iOS 17+，横屏业务场景

## 打开方式
1. 在 Xcode 中打开 `CustomerManagerApp/CustomerManagerApp.xcodeproj`
2. 选择 `CustomerManagerApp` scheme
3. 运行到 iOS 17+ 设备或模拟器

## 目录
- `CustomerManagerApp/App`: App 入口与容器
- `CustomerManagerApp/Core`: 配置与网络层
- `CustomerManagerApp/Features`: 业务页面与 ViewModel
- `CustomerManagerApp/Shared`: 通用模型与支持代码
- `CustomerManagerAppTests`: 单元测试

## 网络层说明
- `APIEndpoint`: 定义 path/method/query/body/headers
- `APIClient`: 统一请求、错误映射、JSON decode
- `NetworkError`: 统一错误类型

## 生成工程脚本
- `generate_project.rb`: 使用 Ruby `xcodeproj` 生成 `.xcodeproj`

