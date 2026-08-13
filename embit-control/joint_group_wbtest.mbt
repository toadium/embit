///|
/// embit-control 关节组管理白盒测试。

///|
/// 创建关节组应正确初始化。
test "JointGroup - new initializes positions to zero" {
  let g = JointGroup::new("left_leg", ["hip", "knee", "ankle"])
  assert_eq(g.get_name(), "left_leg")
  assert_eq(g.size(), 3)
  let positions = g.get_positions()
  assert_eq(positions[0], ("hip", 0.0))
  assert_eq(positions[1], ("knee", 0.0))
  assert_eq(positions[2], ("ankle", 0.0))
}

///|
/// set_position / get_position 应正确读写。
test "JointGroup - set and get position" {
  let g = JointGroup::new("arm", ["shoulder", "elbow"])
  g.set_position("shoulder", 0.5)
  g.set_position("elbow", -0.3)
  assert_eq(g.get_position("shoulder"), 0.5)
  assert_eq(g.get_position("elbow"), -0.3)
}

///|
/// 设置不在组内的关节应抛出错误。
test "JointGroup - set_position unknown joint raises error" {
  let g = JointGroup::new("arm", ["shoulder"])
  try g.set_position("wrist", 0.1) catch {
    InvalidConfig(msg) => assert_true(msg.contains("wrist"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// 获取不在组内的关节应抛出错误。
test "JointGroup - get_position unknown joint raises error" {
  let g = JointGroup::new("arm", ["shoulder"])
  try g.get_position("wrist") catch {
    InvalidConfig(msg) => assert_true(msg.contains("wrist"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// set_positions 批量设置。
test "JointGroup - set_positions batch" {
  let g = JointGroup::new("leg", ["hip", "knee"])
  g.set_positions([("hip", 0.5), ("knee", 1.0)])
  assert_eq(g.get_position("hip"), 0.5)
  assert_eq(g.get_position("knee"), 1.0)
}

///|
/// reset 应清零所有位置。
test "JointGroup - reset zeros all" {
  let g = JointGroup::new("leg", ["hip", "knee"])
  g.set_position("hip", 0.5)
  g.set_position("knee", 1.0)
  g.reset()
  assert_eq(g.get_position("hip"), 0.0)
  assert_eq(g.get_position("knee"), 0.0)
}

///|
/// contains 查询关节是否在组内。
test "JointGroup - contains" {
  let g = JointGroup::new("leg", ["hip", "knee"])
  assert_true(g.contains("hip"))
  assert_false(g.contains("wrist"))
}

// ===== JointGroupManager 测试 =====

///|
/// 添加与获取关节组。
test "JointGroupManager - add and get" {
  let mgr = JointGroupManager::new()
  let g = JointGroup::new("left_leg", ["hip", "knee"])
  mgr.add(g)
  assert_eq(mgr.size(), 1)
  let g2 = mgr.get("left_leg")
  assert_eq(g2.get_name(), "left_leg")
}

///|
/// 获取不存在的组应抛出错误。
test "JointGroupManager - get nonexistent raises error" {
  let mgr = JointGroupManager::new()
  try mgr.get("nonexistent") catch {
    InvalidConfig(msg) => assert_true(msg.contains("nonexistent"))
    _ => fail("unexpected RobotError variant")
  } noraise {
    _ => fail("expected InvalidConfig")
  }
}

///|
/// contains 查询组是否存在。
test "JointGroupManager - contains" {
  let mgr = JointGroupManager::new()
  mgr.add(JointGroup::new("arm", ["shoulder"]))
  assert_true(mgr.contains("arm"))
  assert_false(mgr.contains("leg"))
}

///|
/// group_names 列出所有组名。
test "JointGroupManager - group_names" {
  let mgr = JointGroupManager::new()
  mgr.add(JointGroup::new("left_leg", []))
  mgr.add(JointGroup::new("right_leg", []))
  mgr.add(JointGroup::new("torso", []))
  let names = mgr.group_names()
  assert_eq(names.length(), 3)
}
