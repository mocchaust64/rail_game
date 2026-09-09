extends Node
# The static check proves the UI asks for translation keys. This proves the keys
# actually resolve at runtime, which is what a player would notice.


func _ready() -> void:
	var failures: Array[String] = []
	var expected := {
		"en": {"UI_NEXT": "NEXT", "UI_PAUSED": "PAUSED"},
		"vi": {"UI_NEXT": "TIẾP", "UI_PAUSED": "TẠM DỪNG"},
	}
	var original := TranslationServer.get_locale()

	for locale in expected:
		TranslationServer.set_locale(locale)
		for key in expected[locale]:
			var got := tr(key)
			var want: String = expected[locale][key]
			if got != want:
				failures.append("locale %s: %s resolved to '%s', expected '%s'" % [locale, key, got, want])

	TranslationServer.set_locale(original)

	if failures.is_empty():
		print("localisation: PASS (en and vi resolve)")
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("localisation: FAIL (%d)" % failures.size())
	get_tree().quit(1)
