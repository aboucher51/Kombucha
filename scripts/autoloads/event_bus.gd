extends Node
## Global signal relay for decoupled cross-system communication.
##
## Declare every cross-system signal here, typed. Systems emit to the bus,
## listeners connect to the bus — neither needs a reference to the other:
##
##     EventBus.score_changed.connect(_on_score_changed)
##     EventBus.score_changed.emit(new_score)
##
## Keep signals here only when the emitter and listener genuinely should not
## know each other. A parent listening to its own child should connect
## directly.

@warning_ignore("unused_signal")
signal score_changed(new_score: int)

## A machine setting was written (SaveManager.set_setting). Live systems
## re-apply on it; listeners connect a METHOD, never a lambda (an autoload
## signal outlives the scene that connected the lambda).
@warning_ignore("unused_signal")
signal settings_changed(section: String, key: String)
