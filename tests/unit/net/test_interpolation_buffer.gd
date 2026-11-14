extends GutTest

var buf: InterpolationBuffer


func before_each() -> void:
	buf = InterpolationBuffer.new()


func test_midpoint_interpolates() -> void:
	buf.push(10, Vector3(0, 0, 0), Vector3(0, 0, 0), 0.0)
	buf.push(12, Vector3(2, 0, 4), Vector3(4, 0, 0), 1.0)
	var s := buf.sample(11.0)
	assert_eq(s.position, Vector3(1, 0, 2))
	assert_eq(s.aim, Vector3(2, 0, 0))
	assert_almost_eq(float(s.facing), 0.5, 0.0001)


func test_before_first_clamps() -> void:
	buf.push(10, Vector3(1, 0, 1), Vector3.ZERO, 0.0)
	buf.push(11, Vector3(2, 0, 2), Vector3.ZERO, 0.0)
	assert_eq(buf.sample(5.0).position, Vector3(1, 0, 1))


func test_after_last_holds() -> void:
	buf.push(10, Vector3(1, 0, 1), Vector3.ZERO, 0.0)
	buf.push(11, Vector3(2, 0, 2), Vector3.ZERO, 0.0)
	assert_eq(buf.sample(20.0).position, Vector3(2, 0, 2))


func test_ignores_old_ticks() -> void:
	buf.push(10, Vector3(1, 0, 0), Vector3.ZERO, 0.0)
	buf.push(9, Vector3(9, 0, 0), Vector3.ZERO, 0.0)
	buf.push(10, Vector3(8, 0, 0), Vector3.ZERO, 0.0)
	assert_eq(buf.sample(10.0).position, Vector3(1, 0, 0))
	assert_eq(buf.latest_tick(), 10)


func test_facing_wraps_shortest_way() -> void:
	buf.push(0, Vector3.ZERO, Vector3.ZERO, 3.0)
	buf.push(2, Vector3.ZERO, Vector3.ZERO, -3.0)
	var f := float(buf.sample(1.0).facing)
	assert_almost_eq(absf(wrapf(f, -PI, PI)), PI, 0.01)


func test_empty_returns_empty() -> void:
	assert_eq(buf.sample(3.0), {})
	assert_eq(buf.latest_tick(), -1)


func test_capacity_is_bounded() -> void:
	for i in 100:
		buf.push(i, Vector3(i, 0, 0), Vector3.ZERO, 0.0)
	assert_eq(buf.size(), InterpolationBuffer.CAPACITY)
	assert_eq(buf.sample(0.0).position, Vector3(100 - InterpolationBuffer.CAPACITY, 0, 0))
