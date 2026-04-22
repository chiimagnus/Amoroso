# 项目开发规范与指南

## 项目结构与模块组织

本仓库是一个 macOS 桌面应用（SwiftUI + CoreMIDI + SwiftData）。

- 主工程：`LonelyPianist.xcodeproj`
- App 代码：`LonelyPianist/`（按 MVVM + Services 分层：`Models/`、`Services/`、`ViewModels/`、`Views/`、`Utilities/`）
- 单元测试：`LonelyPianistTests/`（Swift Testing）
- visionOS 相关：`LonelyPianistAVP/`、`LonelyPianistAVPTests/`（scheme：`LonelyPianistAVP`）
- AI 后端工作区：`piano_dialogue_server/`（本机 Python 环境）

## 代码风格与命名规范

- 命名：类型 `PascalCase`；变量/函数 `camelCase`；协议以 `Protocol` 结尾；实现以 `Service` 结尾。
- View 只负责展示；状态编排与业务流程放 `ViewModels/`；跨模块能力下沉到 `Services/`，依赖通过注入传递。
- SwiftUI 事件：不需要旧/新值时优先 `.onChange(of:) { ... }` 无参数重载，避免 `(_, _)` 形式的冗余闭包签名。

## 测试指南

- 测试框架：Swift Testing（`import Testing` + `@Test` + `#expect`），新增文件放 `LonelyPianistTests/`，命名 `*Tests.swift`。
- visionOS 测试同样使用 Swift Testing；测试文件放 `LonelyPianistAVPTests/`，并用 `xcodebuild test -scheme LonelyPianistAVP -destination "platform=visionOS Simulator,name=Apple Vision Pro"` 跑（不要写 XCTest）。
- 新增 Service Protocol 时提供最少 1 个测试替身（成功/失败各覆盖）；涉及时间窗口/节流时把时间源做成可注入依赖，避免真实等待。
- 提交前手测：权限请求与状态刷新、Start Listening 后 Sources/MIDI Events 更新、Single/Chord/Melody 映射各验证一次、Profile 持久化（重启仍保留）。

## Apple/Swift 基线规范（全文）

### 核心技术栈

- 架构模式：MVVM (Model-View-ViewModel)
- 编程范式：Protocol-Oriented Programming（面向协议）
- UI：SwiftUI、RealityKit（按需）
- 状态管理：Observation（`@Observable` / `@Bindable`）；必要时使用 Swift Concurrency；仅在需要 Publisher 管道时引入 Combine
- 持久化：SwiftData（按需）
- Swift：Swift 6.0+

平台支持（按项目选择）：
- iOS 17.0+、iPadOS 17.0+、macOS 14.0+、visionOS 2.0+

## 设计原则

- 组合优于继承：优先依赖注入
- 接口优于单例：利于测试与替换
- 显式优于隐式：数据流与依赖清晰可追踪
- 协议驱动：优先“新增实现”而不是“改 switch”

工程简洁性：
- KISS：能简单就别复杂
- YAGNI：不为不确定未来预埋
- DRY + WET：避免重复，但别过早抽象（通常重复 2–3 次后再抽）

### MVVM 架构规范

职责划分：
- **Model**：纯数据结构；不放 UI 逻辑（避免引用 SwiftUI/Observation/Combine）
- **ViewModel**：业务流程编排、状态管理、数据转换；不直接做 UI 操作；避免隐藏单例依赖
- **View**：渲染与交互绑定；不写业务逻辑；不直接访问数据库/网络
- **Service/Repository**：网络、持久化、文件 IO 等副作用；优先协议抽象 + 注入

#### ViewModel 规范（Observation 优先）

- iOS 17+ / macOS 14+：优先 `@Observable` / `@Bindable`
- 避免单例：不要用 `static let shared`
- 依赖注入优先：初始化参数或 `.environment(...)`
- 不使用 `ObservableObject` / `@Published` / `@StateObject` / `@ObservedObject` / `@EnvironmentObject`（统一用 Observation 体系）。

#### SwiftUI 事件处理

- 优先使用 `.onChange(of:) {}` 的无参数重载。
- 只有确实需要 `oldValue` / `newValue` 时，才使用带两个参数的重载；不要默认写 `.onChange(of:) { _, _ in }`。

### 协议驱动开发

原则：
1. 先定义协议，再实现类型
2. 用协议消除类型分支（减少 `switch` 的维护成本）
3. 新增能力优先“增加实现”而不是“修改中心分发器”

### 测试与调试

工具约束（本机 Apple/Swift 技能默认）：
- 本目录下涉及 build/test/run 的操作，统一使用原生 `xcodebuild`。
- 涉及 Simulator/Device 与日志相关的操作，按需使用原生 `xcrun simctl` / `log stream` 等系统工具。

单元测试优先级建议：
- **逻辑层 / ViewModel / UI 层**：统一用 XCTest（通过 `xcodebuild test` 跑）

调试与日志：
- 日志用 `os.Logger`，明确 `subsystem` 与 `category`，便于过滤与定位

## visionOS 开发补充规范

本文件是 `/Users/chii_magnus/.codex/skills/init/references/apple-app-dev-standards.md` 的 visionOS / RealityKit / spatial computing 补充规范。

优先级：
- 项目内 `AGENTS.md` / `CONTRIBUTING.md` / README 中的约束优先。
- Apple/Swift 基线规范优先于本文的通用建议。
- 本文只补充 visionOS 平台细则；不要用它覆盖项目既有架构、测试框架、最低系统版本或多平台策略。

#### PROJECT KNOWLEDGE

##### Tech Stack
- **OS:** Follow the project's deployment target. Use newer visionOS APIs only when the project target supports them.
- **Languages:** Follow the project's Swift version and concurrency settings.
- **UI Framework:** SwiftUI (primary), UIKit (only when asked by the user)
- **3D Engine:** RealityKit (Entity Component System)

#### CODING STANDARDS

##### 1. SwiftUI & Window Management
- **WindowGroups:** Always define distinct `id`s for WindowGroups in `App` struct.
- **Ornaments:** Use `.ornament()` for toolbars and controls attached to windows. Never place standard floating buttons inside the window content area if they belong in the chrome.
- **Glass Background:** Rely on the default glass background. `.glassBackgroundEffect()` modifier is to be used.
- **Hover Effects:** ALWAYS add `.hoverEffect()` to custom interactive elements to support eye-tracking highlight feedback.
- **Button Styling:** ALWAYS set `.buttonBorderShape()` on buttons for proper visionOS appearance (e.g., `.roundedRectangle`, `.capsule`, `.circle`).

##### 2. RealityKit & ECS (Entity Component System)
- **RealityView:** Use `RealityView` for all 3D content integration.
  ```swift
  RealityView { content in
      // Load and add entities here
      if let model = try? await Entity(named: "Scene") {
          content.add(model)
      }
  } update: { content in
      // Update logic based on SwiftUI state changes
  }
  ```
- **Attachments:** Use `Attachment` in RealityView to embed SwiftUI views into 3D space.
- **Async Loading:** ALWAYS load assets asynchronously (`_ = try! await Entity(named: "MyEntity")`, `async let textureA = try? TextureResource(named:"textureA.jpg")`) to prevent blocking the main thread.
- **Components:** Prefer composition over inheritance. Create custom components implementing `Component` and `Codable`.
- **Draggable Entities:** MUST have both `CollisionComponent` and `InputTargetComponent`.
  ```swift
  entity.components.set(CollisionComponent(shapes: [.generateBox(size: [0.1, 0.1, 0.1])]))
  entity.components.set(InputTargetComponent())
  ```
- **Mesh Resources:** Valid generations are only: `box`, `sphere`, `plane`, `cylinder`, `cone`.

##### 3. Interaction & Input
- **Gestures:**
  - **2D:** Standard SwiftUI gestures work on Windows.
  - **3D:** Use `.gesture(...)` targeted to entities.

##### 4. Concurrency & Threading
- **Strict Concurrency:** Swift 6.2 defaults to `@MainActor` isolation for Views and UI logic. Assume strict isolation checks are active. Everything is `@MainActor` by default.
- **Main Actor:** UI updates and RealityKit mutations are on `@MainActor` by default. Only explicitly mark with `@MainActor` if needed for clarity or when overriding defaults.
- **Background Tasks:** Explicitly move heavy physics/data work *off* the main actor using detached Tasks or non-isolated actors.
- **Task Management:** Do **not** use `Task.detached` indiscriminately. Cancel long-running tasks on teardown.

##### 5. Advanced Spatial Architecture
- **System-Based Logic:** For complex, continuous behaviors (AI, physics, swarming), DO NOT use the SwiftUI update closure. Implement a custom System class and register it.

##### 6. ARKit & World Sensing
- **Full Space Only:** ARKit data is ONLY available when the app is in a `Full Space`. It will not work in Shared Space (Windows/Volumes).
- **Session Management:** Use `ARKitSession` to manage data providers. Keep a strong reference to the session.
- **Authorization:** 
  - Add `NSWorldSensingUsageDescription` and `NSHandsTrackingUsageDescription` to `Info.plist`.
  - Handle authorization gracefully (check `await session.requestAuthorization(for:)`).
- **Data Providers:**
  - `WorldTrackingProvider`: For device pose and world anchors.
  - `PlaneDetectionProvider`: For detecting tables, floors, and walls.
  - `SceneReconstructionProvider`: For environmental meshing and occlusion.
  - `HandTrackingProvider`: For custom hand gestures (requires specific entitlements).
- **Anchors:** Use `UUID` from ARKit anchors to correlate with RealityKit entities.

##### 7. Swift Language Standards
- **Observable Classes:** `@Observable` classes are `@MainActor` by default, so explicit `@MainActor` annotation is not needed.
- **Strict Concurrency:** Assume strict Swift concurrency rules are being applied. Everything is `@MainActor` by default.
- **Swift-Native APIs:** Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` with strings rather than `replacingOccurrences(of: "hello", with: "world")`.
- **Modern Foundation API:** Prefer modern Foundation API, for example `URL.documentsDirectory` to find the app's documents directory, and `appending(path:)` to append strings to a URL.
- **Number Formatting:** Never use C-style number formatting such as `Text(String(format: "%.2f", abs(myNumber)))`; always use `Text(abs(change), format: .number.precision(.fractionLength(2)))` instead.
- **Static Member Lookup:** Prefer static member lookup to struct instances where possible, such as `.circle` rather than `Circle()`, and `.borderedProminent` rather than `BorderedProminentButtonStyle()`.
- **Modern Concurrency:** Never use old-style Grand Central Dispatch concurrency such as `DispatchQueue.main.async()`. If behavior like this is needed, always use modern Swift concurrency.
- **Text Filtering:** Filtering text based on user-input must be done using `localizedStandardContains()` as opposed to `contains()`.
- **Force Unwraps:** Avoid force unwraps and force `try` unless it is unrecoverable.

##### 8. SwiftUI Standards
- **Foreground Style:** Always use `foregroundStyle()` instead of `foregroundColor()`.
- **Clip Shape:** Always use `clipShape(.rect(cornerRadius:))` instead of `cornerRadius()`.
- **Tab API:** Always use the `Tab` API instead of `tabItem()`.
- **Observable:** Never use `ObservableObject`; always prefer `@Observable` classes instead.
- **onChange Modifier:** Never use the `onChange()` modifier in its 1-parameter variant; either use the variant that accepts two parameters or accepts none.
- **onTapGesture:** Never use `onTapGesture()` unless you specifically need to know a tap's location or the number of taps. All other usages should use `Button`.
- **Task.sleep:** Never use `Task.sleep(nanoseconds:)`; always use `Task.sleep(for:)` instead.
- **UIScreen:** Never use `UIScreen.main.bounds` to read the size of the available space.
- **View Composition:** Do not break views up using computed properties; place them into new `View` structs instead.
- **Dynamic Type:** Do not force specific font sizes; prefer using Dynamic Type instead.
- **Navigation:** Use the `navigationDestination(for:)` modifier to specify navigation, and always use `NavigationStack` instead of the old `NavigationView`.
- **Button Labels:** If using an image for a button label, always specify text alongside like this: `Button("Tap me", systemImage: "plus", action: myButtonAction)`.
- **Image Rendering:** When rendering SwiftUI views, always prefer using `ImageRenderer` to `UIGraphicsImageRenderer`.
- **Font Weight:** Don't apply the `fontWeight()` modifier unless there is good reason. If you want to make some text bold, always use `bold()` instead of `fontWeight(.bold)`.
- **GeometryReader:** Do not use `GeometryReader` if a newer alternative would work as well, such as `containerRelativeFrame()` or `visualEffect()`.
- **ForEach with Enumerated:** When making a `ForEach` out of an `enumerated` sequence, do not convert it to an array first. So, prefer `ForEach(x.enumerated(), id: \.element.id)` instead of `ForEach(Array(x.enumerated()), id: \.element.id)`.
- **Scroll Indicators:** When hiding scroll view indicators, use the `.scrollIndicators(.hidden)` modifier rather than using `showsIndicators: false` in the scroll view initializer.
- **View Logic:** Place view logic into view models or similar, so it can be tested.
- **AnyView:** Avoid `AnyView` unless it is absolutely required.
- **Hard-coded Values:** Avoid specifying hard-coded values for padding and stack spacing unless requested.
- **UIKit Colors:** Avoid using UIKit colors in SwiftUI code.

##### 9. Swift 6+ Migration Guide

###### ⚠️ Breaking Changes (Swift 6)
| Issue | Swift 5 | Swift 6 |
|-------|---------|---------|
| Data races | Warnings | **Compile errors** |
| Missing `await` | Warning | **Error** |
| Non-Sendable across actors | Allowed | **Error** |
| Global mutable state | Allowed | **Must be isolated or Sendable** |

###### 🚨 Common Pitfalls
- **Sendable:** Classes crossing actors need `@unchecked Sendable` or must be converted to structs/actors.
- **Closures:** Escaping closures capture isolation context—watch for `@Sendable` requirements.
- **Actor Reentrancy:** Code after `await` may see mutated state—never assume continuity.
- **Global State:** Use `nonisolated(unsafe)` only as last resort for legacy globals.

###### Swift 6.2 Improvements
- **`defaultIsolation(MainActor.self)`** — Eliminates `@MainActor` boilerplate for UI targets.
- **`NonisolatedNonsendingByDefault`** — Nonisolated async inherits caller's actor. Use `@concurrent` for background.
- **Typed Throws** — `throws(MyError)` for exhaustive error handling.

###### Recommended Package.swift
```swift
swiftSettings: [
    .defaultIsolation(MainActor.self),
    .enableExperimentalFeature("NonisolatedNonsendingByDefault")
]
```

###### Quick Patterns
```swift
// Swift 6.2: Inherits caller's isolation
nonisolated func fetchData() async throws -> Data { ... }

// Explicit background execution
@concurrent nonisolated func heavyWork() async -> Result { ... }

// Typed throws
func load() throws(LoadError) { ... }
```

#### REALITYKIT COMPONENTS REFERENCE

##### Rendering & Appearance
| Component | Description |
|-----------|-------------|
| `ModelComponent` | Contains mesh and materials for the visual appearance of an entity |
| `ModelSortGroupComponent` | Configures the rendering order for an entity's model |
| `OpacityComponent` | Controls the opacity of an entity and its descendants |
| `AdaptiveResolutionComponent` | Adjusts resolution based on viewing distance |
| `ModelDebugOptionsComponent` | Enables visual debugging options for models |
| `MeshInstancesComponent` | Efficient rendering of multiple unique variations of an asset |
| `BlendShapeWeightsComponent` | Controls blend shape (morph target) weights for meshes |

##### User Interaction
| Component | Description |
|-----------|-------------|
| `InputTargetComponent` | Enables an entity to receive input events (required for gestures) |
| `ManipulationComponent` | Adds fluid and immersive interactive behaviors and effects |
| `GestureComponent` | Handles gesture recognition on entities |
| `HoverEffectComponent` | Applies highlight effect when user focuses on an entity |
| `AccessibilityComponent` | Configures accessibility features for an entity |
| `BillboardComponent` | Makes an entity always face the camera/user |

##### Presentation & UI
| Component | Description |
|-----------|-------------|
| `ViewAttachmentComponent` | Embeds SwiftUI views into 3D space |
| `PresentationComponent` | Presents SwiftUI modal presentations from an entity |
| `TextComponent` | Renders 3D text in the scene |
| `ImagePresentationComponent` | Displays images in 3D space |
| `VideoPlayerComponent` | Plays video content on an entity |

##### Portals & Environments
| Component | Description |
|-----------|-------------|
| `PortalComponent` | Creates a portal to render a separate world |
| `WorldComponent` | Designates an entity as a separate renderable world |
| `PortalCrossingComponent` | Controls behavior when entities cross portal boundaries |
| `EnvironmentBlendingComponent` | Blends virtual content with real environment |

##### Anchoring & Spatial
| Component | Description |
|-----------|-------------|
| `AnchoringComponent` | Anchors an entity to a real-world position |
| `ARKitAnchorComponent` | Links entity to an ARKit anchor |
| `SceneUnderstandingComponent` | Access scene understanding data (planes, meshes) |
| `DockingRegionComponent` | Defines regions for docking content |
| `ReferenceComponent` | References external entity files for lazy loading |
| `AttachedTransformComponent` | Attaches entity transform to another entity |

##### Cameras
| Component | Description |
|-----------|-------------|
| `PerspectiveCameraComponent` | Configures perspective camera properties |
| `OrthographicCameraComponent` | Configures orthographic camera properties |
| `ProjectiveTransformCameraComponent` | Custom projective transform for cameras |

##### Lighting & Shadows
| Component | Description |
|-----------|-------------|
| `PointLightComponent` | Omnidirectional point light source |
| `DirectionalLightComponent` | Parallel rays light source (sun-like) |
| `SpotLightComponent` | Cone-shaped spotlight |
| `ImageBasedLightComponent` | Environment lighting from HDR images |
| `ImageBasedLightReceiverComponent` | Enables entity to receive IBL |
| `GroundingShadowComponent` | Casts/receives grounding shadows for realism |
| `DynamicLightShadowComponent` | Dynamic shadows from light sources |
| `EnvironmentLightingConfigurationComponent` | Configures environment lighting behavior |
| `VirtualEnvironmentProbeComponent` | Virtual environment reflection probes |

##### Audio
| Component | Description |
|-----------|-------------|
| `SpatialAudioComponent` | 3D positioned audio source |
| `AmbientAudioComponent` | Non-directional ambient audio |
| `ChannelAudioComponent` | Channel-based audio playback |
| `AudioLibraryComponent` | Stores multiple audio resources |
| `ReverbComponent` | Applies reverb effects |
| `AudioMixGroupsComponent` | Groups audio for mixing control |

##### Animation & Character
| Component | Description |
|-----------|-------------|
| `AnimationLibraryComponent` | Stores multiple animation resources |
| `CharacterControllerComponent` | Character movement and physics |
| `CharacterControllerStateComponent` | Runtime state of character controller |
| `SkeletalPosesComponent` | Skeletal animation poses |
| `IKComponent` | Inverse kinematics for procedural animation |
| `BodyTrackingComponent` | Full body tracking integration |

##### Physics & Collision
| Component | Description |
|-----------|-------------|
| `CollisionComponent` | Defines collision shapes (required for interaction) |
| `PhysicsBodyComponent` | Adds physics simulation (mass, friction, etc.) |
| `PhysicsMotionComponent` | Controls velocity and angular velocity |
| `PhysicsSimulationComponent` | Configures physics simulation parameters |
| `ParticleEmitterComponent` | Emits particle effects |
| `ForceEffectComponent` | Applies force fields to physics bodies |
| `PhysicsJointsComponent` | Creates joints between physics bodies |
| `GeometricPinsComponent` | Defines geometric attachment points |

##### Networking & Sync
| Component | Description |
|-----------|-------------|
| `SynchronizationComponent` | Synchronizes entity state across network |
| `TransientComponent` | Marks entity as non-persistent |

#### BOUNDARIES & COMMON PITFALLS

##### 🚫 NEVER DO
- **Legacy ARKit:** Never use `ARView` (from iOS ARKit). It is deprecated/unavailable on visionOS. You MUST use `RealityView`.
- **The "Screen" Fallacy:** Do not use `UIScreen.main.bounds`. There is no "screen". Use `GeometryReader` or `GeometryReader3D`.
- **Blocking Main Thread:** Zero tolerance for blocking operations on the main thread. Dropping frames causes motion sickness.
- **Raw Eye Data:** Do not attempt to access gaze coordinates directly.
- **Scene Usage:** Do not rely on `Scene` outside of the main App target.
- **Cross-Platform Checks:** In a visionOS-only target, avoid unnecessary platform conditionals. In a shared Apple target, use narrow `#if os(...)` guards only to isolate APIs that are unavailable on visionOS, and follow the repo's platform layout.

##### ✅ ALWAYS DO
- **Hover Effects:** Ensure interactive elements have hover states.
- **Validation:** Validate functions against the latest Apple docs.
- **Error Handling:** Implement proper error handling for model loading.
- **Documentation:** Use clear names and doc comments for public APIs.
- **Deliverables:** Follow the specific output format requested below.

#### PREFERRED CODE PATTERNS

##### Loading a Model with Error Handling
```swift
@State private var entity: Entity?

var body: some View {
    RealityView { content in
        do {
            let model = try await Entity(named: "MyModel", in: realityKitContentBundle)
            content.add(model)
        } catch {
            print("Failed to load model: \(error)")
        }
    }
}
```

##### Volumetric Window Definition
```swift
WindowGroup(id: "VolumetricWindow") {
    ContentView()
}
.windowStyle(.volumetric)
.defaultSize(width: 1.0, height: 1.0, depth: 1.0, in: .meters)
```

##### RealityView Attachment Usage
```swift
RealityView { content in
    let entity = Entity()
    let attachment = ViewAttachmentComponent(rootView: AttachmentView())
    entity.components.set(attachment)
    entity.position = [0, 1.5, -1]
    content.add(entity)
}
```

##### Observable App State with Environment Injection
Use this pattern for app-wide state management with SwiftUI Environment integration:
```swift
@Observable
final class AppState {
    var count = 0
}

@main
struct VisionApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

struct MyView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Text("Count: \(appState.count)")
    }
}
```

##### Styled Button for visionOS
Always use `.buttonBorderShape()` for proper spatial styling:
```swift
Button(action: {
    // Button action here
}, label: {
    Label("Play First Episode", systemImage: "play.fill")
        .padding(.horizontal)
})
.foregroundStyle(.black)
.tint(.white)
.buttonBorderShape(.roundedRectangle)
```
Available shapes: `.roundedRectangle`, `.roundedRectangle(radius:)`, `.capsule`, `.circle`.

#### DELIVERABLES
- A concise plan (≤ 8 bullets) mapping directly to implementation steps.
- **Assumptions:** If anything is ambiguous, make the most reasonable assumption and list it at the end.
- **Implementation:** Write complete, compiling Swift/RealityKit code that follows all rules.
- **Output Format:**
  - File tree
  - Full file contents with fenced code blocks labeled as: `// FILE: <path>`
  - Build & run notes for Xcode (targets, capabilities/entitlements if any).
  - Validation summary (RealityView usage, proper components, etc.).
  - List of reasonable assumptions made.
