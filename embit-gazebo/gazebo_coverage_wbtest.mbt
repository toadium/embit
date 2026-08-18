///|
/// GazeboClient::pause 未连接时触发错误。
test "GazeboClient - pause not connected" {
  let client = GazeboClient::connect("localhost:9000")
  client.disconnect()
  try client.pause() catch {
    ActionExecuteError(msg) => assert_true(msg.contains("pause"))
    _ => fail("expected ActionExecuteError")
  } noraise {
    _ => fail("expected ActionExecuteError")
  }
}

///|
/// GazeboClient::unpause 未连接时触发错误。
test "GazeboClient - unpause not connected" {
  let client = GazeboClient::connect("localhost:9000")
  client.disconnect()
  try client.unpause() catch {
    ActionExecuteError(msg) => assert_true(msg.contains("unpause"))
    _ => fail("expected ActionExecuteError")
  } noraise {
    _ => fail("expected ActionExecuteError")
  }
}

///|
/// GazeboClient::set_gravity 未连接时触发错误。
test "GazeboClient - set_gravity not connected" {
  let client = GazeboClient::connect("localhost:9000")
  client.disconnect()
  try client.set_gravity(0.0, 0.0, -9.81) catch {
    ActionExecuteError(msg) => assert_true(msg.contains("set_gravity"))
    _ => fail("expected ActionExecuteError")
  } noraise {
    _ => fail("expected ActionExecuteError")
  }
}
