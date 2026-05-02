# Stub — 移至 wiki

正文: `wiki/domains/godot/tips/pathfollow2d-progress-ratio.md`
(`E:\workspace\knowledge-wiki\wiki\domains\godot\tips\pathfollow2d-progress-ratio.md`)

主题: 动态创建 `PathFollow2D` 时, `progress_ratio` 必须在 `add_child()` 之后赋值, 否则 setter 拿不到父 `Path2D` 的 `curve`, 节点堆在原点.
