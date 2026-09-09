extends Node
# The analytics log must survive across sessions and must not rewrite everything
# it has ever recorded on each flush. The old implementation opened the file with
# WRITE, which truncates, and stored the whole in-memory array, so each session
# destroyed the previous session's events and the write cost grew with the
# session length.

const PREVIOUS_SESSION_LINE := '{"event":"from_a_previous_session","params":{}}'


func _ready() -> void:
	var failures: Array[String] = []
	var log_path: String = AnalyticsService.LOG_PATH

	# Wipe, then plant a line as if an earlier session had written it.
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))
	var seed_file := FileAccess.open(log_path, FileAccess.WRITE)
	seed_file.store_line(PREVIOUS_SESSION_LINE)
	seed_file.close()

	for i in range(40):
		AnalyticsService.track("probe_event", {"index": i})
	AnalyticsService.flush()

	var text := FileAccess.open(log_path, FileAccess.READ).get_as_text()
	if not text.contains("from_a_previous_session"):
		failures.append("the previous session's events were destroyed by this session")

	var probe_lines := 0
	for line in text.split("\n", false):
		if line.contains("probe_event"):
			probe_lines += 1
	if probe_lines != 40:
		failures.append("expected 40 recorded events, found %d" % probe_lines)

	# Memory must not grow without bound over a long session.
	if not AnalyticsService.has_method("buffered_count"):
		failures.append("no bound on the in-memory event buffer")
	elif AnalyticsService.buffered_count() > AnalyticsService.MAX_BUFFERED:
		failures.append(
			"in-memory buffer holds %d events, cap is %d"
			% [AnalyticsService.buffered_count(), AnalyticsService.MAX_BUFFERED]
		)

	if failures.is_empty():
		print("analytics: PASS (%d events appended, previous session intact)" % probe_lines)
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("analytics: FAIL (%d)" % failures.size())
	get_tree().quit(1)
