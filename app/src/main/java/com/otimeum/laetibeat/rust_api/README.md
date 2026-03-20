# Rust API 集成指南

## 概述

本目录用于未来集成 Rust 编写的 HTTP 流媒体服务，类似 Subsonic / Navidrome。

## 集成计划

1. **API 客户端**：实现 `ApiService` 接口，使用 HTTP 客户端与 Rust 后端通信
2. **WebSocket 集成**：实现 WebSocket 连接，用于实时状态同步
3. **认证机制**：实现与 Rust 后端的认证流程
4. **错误处理**：处理网络错误和后端响应错误

## 目录结构

```
rust_api/
  ├── client/          # API 客户端实现
  ├── websocket/       # WebSocket 实现
  ├── auth/            # 认证相关代码
  └── models/          # 数据模型
```

## 注意事项

- 确保 Rust 后端提供符合 RESTful 规范的 API
- 实现适当的缓存机制，减少网络请求
- 处理网络状态变化，确保离线时的用户体验
- 遵循 Android 网络安全最佳实践
