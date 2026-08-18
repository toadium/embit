///|
/// ViewPanel FFI playback 查询方法。
test "ViewPanel - ffi playback methods" {
  let panel = ViewPanel::new()
  let _ = panel.ffi_playback_next()
  let _ = panel.ffi_playback_total()
  let _ = panel.ffi_playback_current()
  assert_true(true)
}

///|
/// ViewPanel FFI get_parameter 查询方法。
test "ViewPanel - ffi_get_parameter" {
  let panel = ViewPanel::new()
  let value = panel.ffi_get_parameter("kp", 1.0)
  let _ = value
  assert_true(true)
}
