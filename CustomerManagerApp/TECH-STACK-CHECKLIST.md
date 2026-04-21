# 技术栈检查清单

当前已具备：
- SwiftUI（iOS 17+）
- 原生网络请求封装（URLSession）
- 基础 MVVM 结构
- 单元测试入口（XCTest）

建议补充（按优先级）：
1. 身份与安全
- Token 刷新机制（401 自动续期）
- Keychain 安全存储
- HTTPS Pinning（高安全需求场景）

2. 稳定性
- 统一日志与埋点（OSLog + 事件跟踪）
- 全局错误恢复策略（重试/降级/空态）
- Crash 收集（如 Sentry / Firebase Crashlytics）

3. 数据层
- 本地缓存（SwiftData/CoreData/SQLite）
- 离线回放与增量同步策略
- 分页协议与游标方案

4. 工程化
- CI/CD（xcodebuild + fastlane + TestFlight）
- 代码规范（SwiftLint/SwiftFormat）
- 多环境配置（dev/staging/prod）

5. 质量保障
- 网络层 Mock（URLProtocol）
- 业务 UI 测试（XCUITest）
- 快照测试（Snapshot Testing）

6. 性能
- 列表与图片加载优化
- Instruments 监控（内存/卡顿/启动时长）
- API 聚合与压缩策略

