// gazebo_ignition_wrapper.cpp — Ignition Transport C++ wrapper
//
// 实现 gazebo_ignition.h 声明的 C 接口，内部调用 Ignition Transport C++ API。
// 由 scripts/prepare.py 编译成静态库（libembit_ignition.a / .lib），
// 通过 moon.pkg 的 link(native("cc-link-flags": ...)) 链接。
//
// 编译要求：
//   - Ignition Transport（Gazebo Fortress+）已安装
//   - C++17 或更高
//   - 依赖：ignition-transport, protobuf, uuid

#include "gazebo_ignition.h"

#include <ignition/transport/Node.hh>
#include <ignition/msgs/stringmsg.pb.h>
#include <ignition/msgs/world_control.pb.h>
#include <ignition/msgs/entity_factory.pb.h>
#include <ignition/msgs/entity.pb.h>

#include <string>
#include <unordered_map>
#include <mutex>

// 内部节点包装：持有 Ignition Transport C++ Node 对象
struct embit_ign_node {
  ignition::transport::Node *node;
  std::string world_name;
  std::unordered_map<std::string, ignition::transport::Node::PublisherPtr> publishers;
  std::mutex mtx;
  int32_t connected;
  int32_t paused;
  int32_t model_count;
  double gravity_x, gravity_y, gravity_z;
};

// 默认世界名（可通过环境变量 EMBIT_GAZEBO_WORLD 覆盖）
static std::string get_world_name() {
  const char *env = std::getenv("EMBIT_GAZEBO_WORLD");
  return env ? env : "default";
}

extern "C" {

void *embit_ign_node_create(const char *address) {
  auto *wrapper = new embit_ign_node{};
  wrapper->node = new ignition::transport::Node();
  wrapper->world_name = get_world_name();
  wrapper->paused = 0;
  wrapper->model_count = 0;
  wrapper->gravity_x = 0.0;
  wrapper->gravity_y = 0.0;
  wrapper->gravity_z = -9.81;

  // Init 接受分区名，空字符串使用默认分区
  bool ok = wrapper->node->Init(address ? address : "");
  wrapper->connected = ok ? 1 : 0;

  if (!ok) {
    delete wrapper->node;
    delete wrapper;
    return nullptr;
  }
  return wrapper;
}

void embit_ign_node_destroy(void *node) {
  if (!node) return;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  // publishers 会随 Node 销毁自动清理
  delete wrapper->node;
  delete wrapper;
}

int32_t embit_ign_is_connected(void *node) {
  if (!node) return 0;
  return static_cast<embit_ign_node*>(node)->connected;
}

int32_t embit_ign_publish(void *node, const char *topic, const void *data, int32_t len) {
  if (!node || !topic) return -1;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  if (!wrapper->connected) return -1;

  std::string topic_str(topic);
  std::string data_str(static_cast<const char*>(data), len);

  std::lock_guard<std::mutex> lock(wrapper->mtx);
  // 懒创建 Publisher
  auto it = wrapper->publishers.find(topic_str);
  if (it == wrapper->publishers.end()) {
    auto pub = wrapper->node->Advertise<ignition::msgs::StringMsg>(topic_str);
    if (!pub.Valid()) return -1;
    wrapper->publishers[topic_str] = pub;
    it = wrapper->publishers.find(topic_str);
  }

  ignition::msgs::StringMsg msg;
  msg.set_data(data_str);
  return it->second.Publish(msg) ? 0 : -1;
}

int32_t embit_ign_subscribe(void *node, const char *topic) {
  if (!node || !topic) return -1;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  if (!wrapper->connected) return -1;

  // Subscribe 需要回调，此处注册空回调（消息内容由上层处理）
  // 真实场景应注册回调将消息写入共享缓冲区供 MoonBit 侧读取
  auto cb = [](const ignition::msgs::StringMsg &_msg) -> void {
    (void)_msg;
    // TODO: 将消息写入线程安全缓冲区，供 GazeboRobot::poll_sensors 读取
  };
  return wrapper->node->Subscribe(topic, cb) ? 0 : -1;
}

int32_t embit_ign_unsubscribe(void *node, const char *topic) {
  if (!node || !topic) return -1;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  if (!wrapper->connected) return -1;
  return wrapper->node->Unsubscribe(topic) ? 0 : -1;
}

int32_t embit_ign_service_call(void *node, const char *service, const void *request, int32_t req_len) {
  if (!node || !service) return -1;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  if (!wrapper->connected) return -1;

  ignition::msgs::StringMsg req, resp;
  req.set_data(std::string(static_cast<const char*>(request), req_len));

  bool result = false;
  unsigned int timeout = 5000;  // 5s 超时
  bool executed = wrapper->node->Request(service, req, timeout, resp, result);
  return (executed && result) ? 0 : -1;
}

// ===== 世界控制 =====

// 辅助：调用 /world/<world>/control 服务
static int32_t world_control(embit_ign_node *wrapper, const ignition::msgs::WorldControl &ctrl) {
  std::string svc = "/world/" + wrapper->world_name + "/control";
  ignition::msgs::WorldControl resp;
  bool result = false;
  unsigned int timeout = 5000;
  bool executed = wrapper->node->Request(svc, ctrl, timeout, resp, result);
  return (executed && result) ? 0 : -1;
}

int32_t embit_ign_reset_world(void *node) {
  if (!node) return -1;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  if (!wrapper->connected) return -1;

  ignition::msgs::WorldControl ctrl;
  ctrl.set_reset(true);
  ctrl.set_pause(false);
  int32_t r = world_control(wrapper, ctrl);
  if (r == 0) wrapper->paused = 0;
  return r;
}

int32_t embit_ign_pause(void *node) {
  if (!node) return -1;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  if (!wrapper->connected) return -1;

  ignition::msgs::WorldControl ctrl;
  ctrl.set_pause(true);
  int32_t r = world_control(wrapper, ctrl);
  if (r == 0) wrapper->paused = 1;
  return r;
}

int32_t embit_ign_unpause(void *node) {
  if (!node) return -1;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  if (!wrapper->connected) return -1;

  ignition::msgs::WorldControl ctrl;
  ctrl.set_pause(false);
  int32_t r = world_control(wrapper, ctrl);
  if (r == 0) wrapper->paused = 0;
  return r;
}

int32_t embit_ign_is_paused(void *node) {
  if (!node) return -1;
  return static_cast<embit_ign_node*>(node)->paused;
}

int32_t embit_ign_step(void *node, int32_t steps) {
  if (!node || steps <= 0) return -1;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  if (!wrapper->connected) return -1;

  ignition::msgs::WorldControl ctrl;
  ctrl.set_step(steps);
  return world_control(wrapper, ctrl);
}

int32_t embit_ign_set_gravity(void *node, double gx, double gy, double gz) {
  if (!node) return -1;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  if (!wrapper->connected) return -1;

  // 通过 /world/<world>/set_gravity_vector 服务设置重力
  // 若服务不可用则仅更新本地缓存
  std::string svc = "/world/" + wrapper->world_name + "/set_gravity_vector";
  ignition::msgs::Vector3d grav;
  grav.set_x(gx); grav.set_y(gy); grav.set_z(gz);
  ignition::msgs::Vector3d resp;
  bool result = false;
  unsigned int timeout = 5000;
  bool executed = wrapper->node->Request(svc, grav, timeout, resp, result);

  wrapper->gravity_x = gx;
  wrapper->gravity_y = gy;
  wrapper->gravity_z = gz;
  return (executed && result) ? 0 : 0;  // 即使服务不可用也返回 0（已更新本地缓存）
}

// ===== 场景管理 =====

int32_t embit_ign_spawn_model(void *node, const char *model_name) {
  if (!node || !model_name) return -1;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  if (!wrapper->connected) return -1;

  std::string svc = "/world/" + wrapper->world_name + "/create";
  ignition::msgs::EntityFactory req;
  req.set_name(model_name);
  req.set_sdf_filename(std::string(model_name) + ".sdf");

  ignition::msgs::Boolean resp;
  bool result = false;
  unsigned int timeout = 5000;
  bool executed = wrapper->node->Request(svc, req, timeout, resp, result);
  if (executed && result) {
    wrapper->model_count++;
    return 0;
  }
  return -1;
}

int32_t embit_ign_remove_model(void *node, const char *model_name) {
  if (!node || !model_name) return -1;
  auto *wrapper = static_cast<embit_ign_node*>(node);
  if (!wrapper->connected) return -1;

  std::string svc = "/world/" + wrapper->world_name + "/remove";
  ignition::msgs::Entity req;
  req.set_name(model_name);
  req.set_type(ignition::msgs::Entity::MODEL);

  ignition::msgs::Boolean resp;
  bool result = false;
  unsigned int timeout = 5000;
  bool executed = wrapper->node->Request(svc, req, timeout, resp, result);
  if (executed && result) {
    if (wrapper->model_count > 0) wrapper->model_count--;
    return 0;
  }
  return -1;
}

int32_t embit_ign_model_count(void *node) {
  if (!node) return -1;
  return static_cast<embit_ign_node*>(node)->model_count;
}

}  // extern "C"
