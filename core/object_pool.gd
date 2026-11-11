class_name ObjectPool
extends RefCounted

## ObjectPool: Allokationsfreier 2D-Objekt-Pool
## Garantiert O(0) Allokationen zur Laufzeit in _physics_process.
## Verwaltet Instanzen in getrennten Listen (aktiv vs. verfügbar).

var _available: Array = []
var _active: Array = []
var _capacity: int = 0

func initialize(capacity: int, factory_callable: Callable, parent_node: Node = null) -> void:
	clear()
	_capacity = capacity

	for i in range(capacity):
		var item = factory_callable.call()
		if item is Node:
			item.process_mode = Node.PROCESS_MODE_DISABLED
			if item is CanvasItem:
				item.visible = false
			if parent_node != null:
				parent_node.add_child(item)
		_available.append(item)

func acquire():
	if _available.is_empty():
		return null

	var item = _available.pop_back()
	_active.append(item)

	if item is Node:
		item.process_mode = Node.PROCESS_MODE_INHERIT
		if item is CanvasItem:
			item.visible = true

	if item.has_method("on_pool_acquire"):
		item.on_pool_acquire()

	return item

func release(item) -> void:
	var idx = _active.find(item)
	if idx != -1:
		_active.remove_at(idx)
		_available.append(item)

		if item is Node:
			item.process_mode = Node.PROCESS_MODE_DISABLED
			if item is CanvasItem:
				item.visible = false

		if item.has_method("on_pool_release"):
			item.on_pool_release()

func reset_all() -> void:
	while not _active.is_empty():
		var item = _active.pop_back()
		_available.append(item)
		if item is Node:
			item.process_mode = Node.PROCESS_MODE_DISABLED
			if item is CanvasItem:
				item.visible = false
		if item.has_method("on_pool_release"):
			item.on_pool_release()

func clear() -> void:
	_available.clear()
	_active.clear()
	_capacity = 0

func get_active_count() -> int:
	return _active.size()

func get_available_count() -> int:
	return _available.size()

func get_capacity() -> int:
	return _capacity

func get_active_items() -> Array:
	return _active

