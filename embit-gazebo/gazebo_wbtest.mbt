///|
/// embit-gazebo 白盒测试：验证 FFI 通道与安全封装行为。
///
/// 白盒测试位于包内，可直接使用 GazeboClient 等类型名，
/// 跨包错误类型仍用 @core.RobotError 限定。

///|
/// 连接后应处于已连接状态，话题计数初值为 0。
test "GazeboClient - connect and is_connected" {
  let client = GazeboClient::connect("localhost:9000")
  assert_true(client.is_connected())
  assert_eq(client.topic_count(), 0)
  client.disconnect()
}

///|
/// 发布消息应使话题计数递增。
test "GazeboClient - publish increments topic_count" {
  let client = GazeboClient::connect("localhost:9000")
  client.publish("/cmd_vel", b"linear=0.5;angular=0.0")
  client.publish("/joint_states", b"[0,0,0,0,0,0]")
  assert_eq(client.topic_count(), 2)
  client.disconnect()
}

///|
/// 断开后 is_connected 应返回 false。
test "GazeboClient - disconnect sets is_connected false" {
  let client = GazeboClient::connect("localhost:9000")
  assert_true(client.is_connected())
  client.disconnect()
  assert_false(client.is_connected())
}

///|
/// 断开后再发布应抛出 RobotError::ActionExecuteError。
test "GazeboClient - publish after disconnect raises error" {
  let client = GazeboClient::connect("localhost:9000")
  client.disconnect()
  try client.publish("/cmd_vel", b"data") catch {
    ActionExecuteError(msg) => assert_true(msg.contains("publish failed"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected ActionExecuteError after disconnect")
  }
}

///|
/// 多次连接互不影响，各客户端独立维护话题计数。
test "GazeboClient - multiple clients are independent" {
  let c1 = GazeboClient::connect("localhost:9000")
  let c2 = GazeboClient::connect("localhost:9001")
  c1.publish("/topic_a", b"a")
  c1.publish("/topic_a", b"a")
  c2.publish("/topic_b", b"b")
  assert_eq(c1.topic_count(), 2)
  assert_eq(c2.topic_count(), 1)
  c1.disconnect()
  c2.disconnect()
  assert_false(c1.is_connected())
  assert_false(c2.is_connected())
}

///|
/// 订阅话题应递增订阅计数。
test "GazeboClient - subscribe increments count" {
  let client = GazeboClient::connect("localhost:9000")
  assert_eq(client.subscription_count(), 0)
  client.subscribe("/sensor/imu")
  client.subscribe("/sensor/camera")
  assert_eq(client.subscription_count(), 2)
  client.disconnect()
}

///|
/// 取消订阅应递减订阅计数。
test "GazeboClient - unsubscribe decrements count" {
  let client = GazeboClient::connect("localhost:9000")
  client.subscribe("/topic1")
  client.subscribe("/topic2")
  assert_eq(client.subscription_count(), 2)
  client.unsubscribe("/topic1")
  assert_eq(client.subscription_count(), 1)
  client.disconnect()
}

///|
/// 断开后订阅应抛出错误。
test "GazeboClient - subscribe after disconnect raises error" {
  let client = GazeboClient::connect("localhost:9000")
  client.disconnect()
  try client.subscribe("/topic") catch {
    ConnectError(msg) => assert_true(msg.contains("subscribe failed"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected ConnectError")
  }
}

///|
/// 无订阅时取消应抛出错误。
test "GazeboClient - unsubscribe with no subscription raises error" {
  let client = GazeboClient::connect("localhost:9000")
  try client.unsubscribe("/nonexistent") catch {
    ConnectError(msg) => assert_true(msg.contains("unsubscribe failed"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected ConnectError")
  }
  client.disconnect()
}

// ===== 服务调用测试 =====

///|
/// 服务调用应递增 service_call_count。
test "GazeboClient - service_call increments count" {
  let client = GazeboClient::connect("localhost:9000")
  assert_eq(client.service_call_count(), 0)
  client.service_call("/get_model_state", b"robot1")
  client.service_call("/set_physics", b"paused=true")
  assert_eq(client.service_call_count(), 2)
  client.disconnect()
}

///|
/// 断开后服务调用应抛出错误。
test "GazeboClient - service_call after disconnect raises error" {
  let client = GazeboClient::connect("localhost:9000")
  client.disconnect()
  try client.service_call("/get_model_state", b"robot1") catch {
    ActionExecuteError(msg) => assert_true(msg.contains("service_call failed"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected ActionExecuteError")
  }
}

///|
/// 多客户端的服务调用计数应独立维护。
test "GazeboClient - service_call_count is independent across clients" {
  let c1 = GazeboClient::connect("localhost:9000")
  let c2 = GazeboClient::connect("localhost:9001")
  c1.service_call("/svc_a", b"req1")
  c1.service_call("/svc_a", b"req2")
  c1.service_call("/svc_b", b"req3")
  c2.service_call("/svc_c", b"req4")
  assert_eq(c1.service_call_count(), 3)
  assert_eq(c2.service_call_count(), 1)
  c1.disconnect()
  c2.disconnect()
}

// ===== 仿真世界控制测试 =====

///|
/// 初始状态应未暂停，默认重力 Z = -9.81。
test "GazeboClient - initial world state" {
  let client = GazeboClient::connect("localhost:9000")
  assert_false(client.is_paused())
  let gz = client.get_gravity_z()
  assert_true((gz - -9.81).abs() < 0.001)
  assert_eq(client.world_control_count(), 0)
  client.disconnect()
}

///|
/// 暂停后 is_paused 应返回 true。
test "GazeboClient - pause and unpause" {
  let client = GazeboClient::connect("localhost:9000")
  client.pause()
  assert_true(client.is_paused())
  client.unpause()
  assert_false(client.is_paused())
  assert_eq(client.world_control_count(), 2)
  client.disconnect()
}

///|
/// reset_world 应清除暂停状态。
test "GazeboClient - reset_world clears pause" {
  let client = GazeboClient::connect("localhost:9000")
  client.pause()
  assert_true(client.is_paused())
  client.reset_world()
  assert_false(client.is_paused())
  client.disconnect()
}

///|
/// step 应递增世界控制计数。
test "GazeboClient - step increments count" {
  let client = GazeboClient::connect("localhost:9000")
  client.pause()
  client.step(10)
  assert_eq(client.world_control_count(), 2) // pause + step
  client.disconnect()
}

///|
/// step 零步应抛出错误。
test "GazeboClient - step zero raises error" {
  let client = GazeboClient::connect("localhost:9000")
  try client.step(0) catch {
    ActionExecuteError(msg) => assert_true(msg.contains("step"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected ActionExecuteError")
  }
  client.disconnect()
}

///|
/// set_gravity 应更新重力分量。
test "GazeboClient - set_gravity updates z component" {
  let client = GazeboClient::connect("localhost:9000")
  client.set_gravity(0.0, 0.0, -1.62) // 月球重力
  let gz = client.get_gravity_z()
  assert_true((gz - -1.62).abs() < 0.001)
  client.disconnect()
}

///|
/// 断开后世界控制应抛出错误。
test "GazeboClient - world control after disconnect raises error" {
  let client = GazeboClient::connect("localhost:9000")
  client.disconnect()
  try client.reset_world() catch {
    ActionExecuteError(msg) => assert_true(msg.contains("reset_world"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected ActionExecuteError")
  }
}

// ===== 场景管理测试 =====

///|
/// 初始场景模型数应为 0。
test "GazeboClient - initial model_count is zero" {
  let client = GazeboClient::connect("localhost:9000")
  assert_eq(client.model_count(), 0)
  client.disconnect()
}

///|
/// spawn_model 应递增模型计数。
test "GazeboClient - spawn_model increments count" {
  let client = GazeboClient::connect("localhost:9000")
  client.spawn_model("humanoid")
  client.spawn_model("quadruped")
  client.spawn_model("arm_6dof")
  assert_eq(client.model_count(), 3)
  client.disconnect()
}

///|
/// remove_model 应递减模型计数。
test "GazeboClient - remove_model decrements count" {
  let client = GazeboClient::connect("localhost:9000")
  client.spawn_model("robot1")
  client.spawn_model("robot2")
  assert_eq(client.model_count(), 2)
  client.remove_model("robot1")
  assert_eq(client.model_count(), 1)
  client.disconnect()
}

///|
/// 无模型时 remove_model 应抛出错误。
test "GazeboClient - remove_model with no models raises error" {
  let client = GazeboClient::connect("localhost:9000")
  try client.remove_model("nonexistent") catch {
    ActionExecuteError(msg) => assert_true(msg.contains("remove_model"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected ActionExecuteError")
  }
  client.disconnect()
}

///|
/// 断开后 spawn_model 应抛出错误。
test "GazeboClient - spawn_model after disconnect raises error" {
  let client = GazeboClient::connect("localhost:9000")
  client.disconnect()
  try client.spawn_model("robot") catch {
    ActionExecuteError(msg) => assert_true(msg.contains("spawn_model"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected ActionExecuteError")
  }
}

///|
/// 多客户端的模型计数应独立维护。
test "GazeboClient - model_count independent across clients" {
  let c1 = GazeboClient::connect("localhost:9000")
  let c2 = GazeboClient::connect("localhost:9001")
  c1.spawn_model("robot_a")
  c1.spawn_model("robot_b")
  c2.spawn_model("robot_c")
  assert_eq(c1.model_count(), 2)
  assert_eq(c2.model_count(), 1)
  c1.remove_model("robot_a")
  assert_eq(c1.model_count(), 1)
  assert_eq(c2.model_count(), 1)
  c1.disconnect()
  c2.disconnect()
}

///|
/// spawn/remove 循环应正确维护计数。
test "GazeboClient - spawn remove cycle" {
  let client = GazeboClient::connect("localhost:9000")
  for i in 0..<5 {
    client.spawn_model("robot_\{i}")
  }
  assert_eq(client.model_count(), 5)
  for i in 0..<3 {
    client.remove_model("robot_\{i}")
  }
  assert_eq(client.model_count(), 2)
  client.disconnect()
}
