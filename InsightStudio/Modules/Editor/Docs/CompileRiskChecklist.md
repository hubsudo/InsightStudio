# Editor Demo Compile / Runtime Risk Checklist

## 1. 本地 demo 素材
- 当前 Demo 的 `追加本地Mock` 依赖主 App Bundle 中存在 `sample1.mp4 / sample2.mp4 / sample3.mp4 / demo1.mp4 / demo2.mp4` 之一。
- 如果不存在，远端 Mock 片段会在预览阶段 fallback 失败并弹错误。

## 2. iOS 版本
- `AVAsset.loadTracks(withMediaType:)` / `load(_:)` 依赖较新的异步 API。
- 建议目标版本 iOS 16+，否则需要同步 API 兼容层。

## 3. AVMutableComposition 实时预览稳定性
- 当前每次结构性变更都会重建 composition，并在 playhead 更新时 seek。
- 这是 Demo 可行路径，但高频拖动下需要进一步做节流、签名比较和后台构建合并。

## 4. Transform 仍是基础版
- 已经处理了 `preferredTransform` 基本路径，但复杂情况下仍需进一步校正 renderSize、镜像中心点和裁剪逻辑。

## 5. 拖拽重排
- 当前用 `UICollectionViewDragDelegate / DropDelegate` 提供基本重排回调。
- 若要更接近剪映体验，后续需要补滚动联动、拖拽占位动画和 playhead 吸附逻辑。

## 6. 选中 / playhead 未入历史
- 当前保留“编辑命令入历史、UI 临时状态不入历史”的边界。
- 这是有意设计，不是遗漏。
