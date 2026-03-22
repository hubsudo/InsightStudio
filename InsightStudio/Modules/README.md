# InsightStudio Editor Module

UIKit + MVVM editor module with:
- single source of truth (`EditorStore`)
- command/history undo-redo
- timeline background layout precomputation
- dirty flag + local invalidate entry points
- ruler
- magnetic snapping for append / playhead seeking
- pinch anchored zoom that keeps playhead visually stable
- append remote clip workflow

## Suggested file paths in app

- `Features/Editor/Core/*`
- `Features/Editor/Models/*`
- `Features/Editor/History/*`
- `Features/Editor/Timeline/*`
- `Features/Editor/ViewModels/*`
- `Features/Editor/Views/*`
- `Features/Editor/Controllers/*`

## Not implemented on purpose

Per request, this package does **not** implement move / trim / split / waveform rendering. Snap service and dirty hooks are left ready for those commands.

## Integration notes

1. Replace the demo `ImportedClipRepository` with your project repository.
2. Replace the demo `ImagePipeline` with your thumbnail loader.
3. Wire `EditorViewController` into your coordinator on the main actor.
4. Keep all UIKit in `@MainActor` view/view-model/controller layers. Layout cache/engine stay pure-data and run off the main actor.
