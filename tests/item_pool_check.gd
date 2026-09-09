extends Node
# Cargo is spawned and destroyed constantly during play. Allocating a fresh
# ItemActor per spawn and freeing it on delivery churns nodes for the whole
# session; the pool reuses a small fixed set instead.


func _ready() -> void:
	var failures: Array[String] = []
	var world := Node3D.new()
	add_child(world)

	var pool := ItemPool.new(world, 8)

	var first_round: Array[int] = []
	for i in range(3):
		var item := pool.acquire()
		first_round.append(item.get_instance_id())
	if pool.created_count() != 3:
		failures.append("expected 3 items created, got %d" % pool.created_count())

	for id in first_round:
		pool.release(instance_from_id(id) as ItemActor)
	if pool.free_count() != 3:
		failures.append("expected 3 free items after release, got %d" % pool.free_count())

	var reused := 0
	for i in range(3):
		var item := pool.acquire()
		if first_round.has(item.get_instance_id()):
			reused += 1
	if reused != 3:
		failures.append("only %d of 3 items were reused; the pool is not recycling" % reused)
	if pool.created_count() != 3:
		failures.append(
			"pool allocated new items instead of reusing: created %d" % pool.created_count()
		)

	# A released item must not stay visible or keep taking part in the round.
	var parked := pool.acquire()
	pool.release(parked)
	if parked.visible:
		failures.append("a released item is still visible")
	if parked.state != ItemActor.ItemState.DEAD:
		failures.append("a released item is not marked dead")

	# The pool must not grow without bound when demand spikes.
	var held: Array[ItemActor] = []
	for i in range(40):
		held.append(pool.acquire())
	if pool.created_count() > pool.max_size:
		failures.append(
			"pool grew to %d items, cap is %d" % [pool.created_count(), pool.max_size]
		)

	if failures.is_empty():
		print("item pool: PASS (%d created for 46 acquires)" % pool.created_count())
		get_tree().quit(0)
		return
	for line in failures:
		printerr(line)
	printerr("item pool: FAIL (%d)" % failures.size())
	get_tree().quit(1)
