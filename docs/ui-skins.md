# UI Skins / 设计语言架构

> 状态：Phase 1 骨架已完成。默认皮肤为当前 Material 3 Expressive；Spotify 皮肤准备在功能稳定后再做。

## 1. 目标

支持真正不同的设计语言，而不只是换颜色：

- Spotify 风格：深色底、自己的导航、列表/卡片/播放器结构
- Apple Music 风格：另一套导航、排版、转场和组件
- 默认 M3 Expressive：保留现有 UI

切换皮肤时：

- 不重启本地/在线音源 sidecar
- 不重建播放队列
- 播放状态、音乐库、账号状态继续复用
- 只替换 UI 树

## 2. 分层

```text
lib/
  app/
    bootstrap.dart
    app.dart                    # 只选择 skin
    skin/
      app_skin.dart             # Skin 接口 + AppSkinId
      app_skin_provider.dart    # ui.skin 持久化
      app_skin_registry.dart    # id -> 实现
  skins/
    expressive/                 # 当前默认皮肤
      expressive_skin.dart      # MaterialApp + Shell + 全局宿主
    spotify/                    # 后续
    apple_music/                # 后续
  features/                     # 后续抽出的 headless controllers
  pages/                        # 当前 Expressive 页面
  design/                       # 当前 Expressive 设计系统
  widgets/                      # 当前共享 widget（逐步收缩）
```

原则：

- **数据层/Provider 共享**：音乐库、播放、搜索、在线 host、设置等保持唯一实现。
- **视觉实现独立**：每个皮肤可以拥有自己的根 App、导航呈现、页面和视觉组件。
- **导航语义共享**：移动端目的地、页面路由栈、路由参数和返回行为由应用级导航层定义；皮肤不得另建 Navigator 栈。
- **模式与皮肤正交**：`AppMode` 决定数据源与可用目的地；`AppSkin` 决定这些目的地如何呈现。
- **不共享跨皮肤页面**：Spotify 不复用 `MobileShell` / `M3E*` 页面。
- **谨慎抽通用组件**：只抽视觉无关的 controller、格式化、业务状态；按钮、卡片、导航不强行共用。

## 3. Skin 契约

```dart
enum AppSkinId { expressive }

abstract interface class AppSkin {
  AppSkinId get id;

  Widget buildRoot(BuildContext context, WidgetRef ref);
}
```

根 App：

```dart
final skinId = ref.watch(appSkinProvider);
final skin = ref.watch(appSkinRegistryProvider).skinFor(skinId);

return KeyedSubtree(
  key: ValueKey(skinId),
  child: skin.buildRoot(context, ref),
);
```

持久化键：

```text
ui.skin = expressive
```

未知值自动回退到 `expressive`。

## 4. 当前阶段

已完成：

- `AppSkinId` / `AppSkin`
- `ui.skin` 持久化
- `AppSkinRegistry`
- 把原 `LaetibeatApp` 的 MaterialApp/主题宿主/移动桌面 Shell 原样迁入 `ExpressiveSkin`
- 默认只有 Expressive，视觉与行为不变

未完成：

- 跨皮肤 typed route / navigation contract 的类型化与深链扩展
- Home / Search / Player 的 headless controller
- 皮肤切换设置入口（等第二个皮肤时加）
- Spotify / Apple Music 皮肤

## 5. 下一阶段

### Phase 2：导航契约

- 已确立共享移动端 root 路由栈：Shell 目的地是状态，详情 / 设置 / 搜索 / 播放器是页面路由。
- 后续把路由名与参数逐步收敛为带类型的 `AppRoute`，并按需支持深链和状态恢复。
- 每个皮肤实现自己的导航视觉，但消费同一目的地状态和路由栈；不得再创建独立的 `SkinNavigator`。
- 页面导航通过共享路由入口执行，不依赖某个皮肤私有的 Navigator key。

### Phase 3：核心 controller

优先抽：

- HomeController
- SearchController
- PlayerController

皮肤只消费状态、调用 controller。

### Phase 4：Spotify 皮肤

建议先只做核心页面：

- Shell
- Home
- Search
- Player
- Settings

未实现的目的地可以先隐藏，或临时共享 Expressive 页面，但不在正式版本长期混用两套设计。

### Phase 5：Apple Music 皮肤

等 Spotify 皮肤验证共享层足够稳定后再开始。

## 6. 约束

- 不在皮肤层直接发 HTTP / 操作 host
- 不在皮肤层复制在线登录、搜索分页、播放队列逻辑
- 不为差异极大的设计语言强行做统一 `AppButton` / `AppCard` 参数开关
- 切换皮肤不重启 `ModeHostController`
- 新增皮肤必须保持可访问性、状态、空/错/加载态完整
