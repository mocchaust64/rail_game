class_name ItemPool
extends RefCounted
# Reuses a small fixed set of ItemActor nodes instead of allocating one per
# spawn and freeing it on delivery. Cargo turns over constantly during play, so
# that churn ran for the whole session.

var max_size: int = 24

var _parent: Node3D
var _free: Array[ItemActor] = []
var _created: int = 0


func _init(parent: Node3D, size: int = 24) -> void:
    _parent = parent
    max_size = size


# Returns a ready item. Reuses a parked one when available, and only allocates
# while the pool is below its cap.
func acquire() -> ItemActor:
    var item: ItemActor = null
    if not _free.is_empty():
        item = _free.pop_back()
    elif _created < max_size:
        item = ItemActor.new()
        _parent.add_child(item)
        _created += 1
    else:
        # Demand beyond the cap reuses the least recently parked item rather
        # than growing without bound.
        item = _parent.get_child(0) as ItemActor
        if item == null:
            return null
    item.visible = true
    item.state = ItemActor.ItemState.SPAWNING
    return item


# Parks an item: hidden, inert, and available for the next spawn.
func release(item: ItemActor) -> void:
    if item == null or _free.has(item):
        return
    item.prepare_for_reuse()
    item.visible = false
    item.state = ItemActor.ItemState.DEAD
    _free.append(item)


func created_count() -> int:
    return _created


func free_count() -> int:
    return _free.size()
