extends Node
# A save must never be lost because the previous write was interrupted or the
# file was corrupted. The old implementation deleted the live save before
# renaming the temp file into its place, so a crash between those two steps left
# the player with no save at all, and there was no backup to fall back on.


func _ready() -> void:
	var failures: Array[String] = []
	var save_path: String = SaveService.SAVE_PATH
	# Literal, not a constant on SaveService: the test must fail on behaviour
	# rather than fail to compile while the backup does not exist yet.
	var backup_path := "user://flow_factory_save_v2.bak"

	# Start from a known state.
	SaveService.highest_unlocked_level = 7
	SaveService.tutorial_seen = true
	SaveService.save()

	if not FileAccess.file_exists(save_path):
		failures.append("save() did not produce a save file")
	if not FileAccess.file_exists(backup_path):
		failures.append("save() left no backup to recover from")

	# A second save must keep a usable backup rather than a half-written one.
	SaveService.highest_unlocked_level = 9
	SaveService.save()
	if not FileAccess.file_exists(backup_path):
		failures.append("second save() destroyed the backup")

	# Corrupt the live save the way an interrupted write would.
	var broken := FileAccess.open(save_path, FileAccess.WRITE)
	broken.store_string("{ this is not json")
	broken.close()

	SaveService.highest_unlocked_level = 1
	SaveService.tutorial_seen = false
	SaveService.load_save()

	if SaveService.highest_unlocked_level < 7:
		failures.append(
			"progress lost after a corrupt save: expected recovery to at least level 7, got %d"
			% SaveService.highest_unlocked_level
		)
	if not SaveService.tutorial_seen:
		failures.append("tutorial flag lost after a corrupt save")

	# Recovery must also repair the live file, not leave it broken for next time.
	var reread: Variant = JSON.parse_string(FileAccess.open(save_path, FileAccess.READ).get_as_text())
	if typeof(reread) != TYPE_DICTIONARY:
		failures.append("recovery left the live save file unreadable")

	if failures.is_empty():
		print("save recovery: PASS")
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("save recovery: FAIL (%d)" % failures.size())
	get_tree().quit(1)
