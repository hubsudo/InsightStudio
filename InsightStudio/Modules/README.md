# InsightStudio Editor Composition Preview Module

This package contains a UIKit-based Editor module scaffold focused on **timeline editing + AVMutableComposition real-time preview**.

## What is included
- Single source of truth: `TimelineDraft`
- Command-based editing: insert / delete / split
- Undo / Redo: `HistoryManager`
- Horizontal timeline MVP: `TimelineView`
- Real-time composition preview service: `DefaultEditorPreviewService`
- AVPlayer-backed preview container: `PreviewContainerView`
- ViewModel aggregation: `EditorViewModel`
- Basic module assembly: `EditorModuleAssembler`

## Preview strategy
Instead of only previewing the currently selected clip, this module rebuilds an `AVMutableComposition` from the full `TimelineDraft`, creates an `AVPlayerItem`, and seeks the player to the current `playheadSeconds`.

For MVP simplicity, the composition is rebuilt whenever the draft changes. In production you would likely add:
- debounce/coalescing for drag-heavy interactions
- caching of partial compositions
- operation cancellation
- audio mix / video composition instructions
- timeline dirty flags and granular rebuilds

## Integration notes
- This package is intentionally self-contained and avoids dependencies on your existing app context.
- Replace `MockClipFactory` / local URLs with your actual clip repository or imported assets.
- `DefaultClipAssetResolver` assumes local files for successful composition preview.
- `ClipAsset.remoteVideo` is preserved in the model for future YouTube Data API v3 integration, but composition preview currently requires a resolvable local media URL.

## Suggested next steps
1. Hook your imported assets repository into `ClipAssetResolver`
2. Replace mock insert actions with material picker flow
3. Add move / playback-rate / transform / animation commands
4. Introduce timeline layout cache + dirty flags
5. Add export path reusing the same `CompositionBuilder`
