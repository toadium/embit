// gazebo_stub.c — Embit Gazebo FFI 桥接（条件编译 wrapper）
//
// 架构：条件编译切换真实 Ignition Transport API 与占位回退实现。
//   - EMBIT_HAS_IGNITION 定义时：调用 gazebo_ignition.h 声明的 C 接口
//     （由 gazebo_ignition_wrapper.cpp 实现，通过 link.native 链接）
//   - 未定义时：占位回退（仅记录操作计数与状态），用于无库环境编译与单元测试
//
// 真实 API 启用方式：
//   1. 安装 Ignition Transport（Gazebo Fortress+）
//   2. 运行 python scripts/prepare.py --with-ignition
//   3. prepare.py 编译 gazebo_ignition_wrapper.cpp 为静态库
//   4. prepare.py 更新 moon.pkg 添加 link(native(...)) 配置
//
// 编译：由 MoonBit native-stub 机制自动编译并链接。

#include <moonbit.h>
#include <stdint.h>
#include <string.h>

#ifdef EMBIT_HAS_IGNITION
#include "gazebo_ignition.h"
#endif

// 通信节点结构体
typedef struct {
  int32_t connected;             // 连接状态（1=已连接, 0=已断开）
  int32_t topic_count;           // 已发布话题计数
  int32_t subscription_count;    // 已订阅话题计数
  int32_t service_call_count;    // 服务调用计数
  int32_t paused;                // 仿真暂停状态（1=暂停, 0=运行）
  int32_t world_control_count;   // 世界控制操作计数
  int32_t model_count;           // 场景中模型数量
  double  gravity_x;             // 重力 X 分量
  double  gravity_y;             // 重力 Y 分量
  double  gravity_z;             // 重力 Z 分量
#ifdef EMBIT_HAS_IGNITION
  void *ign_node;                // 真实 Ignition Transport 节点句柄
#endif
} embit_gazebo_node_t;

// finalizer：释放真实节点资源（占位模式为 no-op）
static void embit_gazebo_node_finalize(void *ptr) {
  if (ptr == NULL) return;
#ifdef EMBIT_HAS_IGNITION
  embit_gazebo_node_t *node = (embit_gazebo_node_t *)ptr;
  if (node->ign_node != NULL) {
    embit_ign_node_destroy(node->ign_node);
    node->ign_node = NULL;
  }
#endif
}

// ===== 连接管理 =====

MOONBIT_FFI_EXPORT
embit_gazebo_node_t *embit_gazebo_connect(moonbit_bytes_t address) {
  embit_gazebo_node_t *node = (embit_gazebo_node_t *)moonbit_make_external_object(
    embit_gazebo_node_finalize,
    sizeof(embit_gazebo_node_t)
  );
  node->topic_count = 0;
  node->subscription_count = 0;
  node->service_call_count = 0;
  node->paused = 0;
  node->world_control_count = 0;
  node->model_count = 0;
  node->gravity_x = 0.0;
  node->gravity_y = 0.0;
  node->gravity_z = -9.81;

#ifdef EMBIT_HAS_IGNITION
  // 真实 Ignition Transport 连接
  const char *addr = (const char *)address;
  node->ign_node = embit_ign_node_create(addr);
  node->connected = (node->ign_node != NULL) ? embit_ign_is_connected(node->ign_node) : 0;
#else
  // 占位回退：始终连接成功
  (void)address;
  node->connected = 1;
#endif
  return node;
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_publish(
  embit_gazebo_node_t *node,
  moonbit_bytes_t topic,
  moonbit_bytes_t data
) {
  if (node == NULL || !node->connected) {
    return -1;
  }
#ifdef EMBIT_HAS_IGNITION
  int32_t len = Moonbit_array_length(data);
  return embit_ign_publish(node->ign_node, (const char *)topic, (const void *)data, len);
#else
  (void)topic; (void)data;
  node->topic_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_is_connected(embit_gazebo_node_t *node) {
  if (node == NULL) return 0;
  return node->connected;
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_topic_count(embit_gazebo_node_t *node) {
  if (node == NULL) return 0;
  return node->topic_count;
}

MOONBIT_FFI_EXPORT
void embit_gazebo_disconnect(embit_gazebo_node_t *node) {
  if (node == NULL) return;
#ifdef EMBIT_HAS_IGNITION
  if (node->ign_node != NULL) {
    embit_ign_node_destroy(node->ign_node);
    node->ign_node = NULL;
  }
#endif
  node->connected = 0;
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_subscribe(
  embit_gazebo_node_t *node,
  moonbit_bytes_t topic
) {
  if (node == NULL || !node->connected) {
    return -1;
  }
#ifdef EMBIT_HAS_IGNITION
  return embit_ign_subscribe(node->ign_node, (const char *)topic);
#else
  (void)topic;
  node->subscription_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_unsubscribe(
  embit_gazebo_node_t *node,
  moonbit_bytes_t topic
) {
  if (node == NULL || !node->connected) {
    return -1;
  }
#ifdef EMBIT_HAS_IGNITION
  return embit_ign_unsubscribe(node->ign_node, (const char *)topic);
#else
  (void)topic;
  if (node->subscription_count <= 0) return -1;
  node->subscription_count--;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_subscription_count(embit_gazebo_node_t *node) {
  if (node == NULL) return 0;
  return node->subscription_count;
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_service_call(
  embit_gazebo_node_t *node,
  moonbit_bytes_t service,
  moonbit_bytes_t request
) {
  if (node == NULL || !node->connected) {
    return -1;
  }
#ifdef EMBIT_HAS_IGNITION
  int32_t len = Moonbit_array_length(request);
  return embit_ign_service_call(node->ign_node, (const char *)service, (const void *)request, len);
#else
  (void)service; (void)request;
  node->service_call_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_service_call_count(embit_gazebo_node_t *node) {
  if (node == NULL) return 0;
  return node->service_call_count;
}

// ===== 仿真世界控制 =====

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_reset_world(embit_gazebo_node_t *node) {
  if (node == NULL || !node->connected) return -1;
#ifdef EMBIT_HAS_IGNITION
  return embit_ign_reset_world(node->ign_node);
#else
  node->world_control_count++;
  node->paused = 0;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_pause(embit_gazebo_node_t *node) {
  if (node == NULL || !node->connected) return -1;
#ifdef EMBIT_HAS_IGNITION
  int32_t r = embit_ign_pause(node->ign_node);
  if (r == 0) node->paused = 1;
  return r;
#else
  node->paused = 1;
  node->world_control_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_unpause(embit_gazebo_node_t *node) {
  if (node == NULL || !node->connected) return -1;
#ifdef EMBIT_HAS_IGNITION
  int32_t r = embit_ign_unpause(node->ign_node);
  if (r == 0) node->paused = 0;
  return r;
#else
  node->paused = 0;
  node->world_control_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_is_paused(embit_gazebo_node_t *node) {
  if (node == NULL) return -1;
#ifdef EMBIT_HAS_IGNITION
  return embit_ign_is_paused(node->ign_node);
#else
  return node->paused;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_step(embit_gazebo_node_t *node, int32_t steps) {
  if (node == NULL || !node->connected || steps <= 0) return -1;
#ifdef EMBIT_HAS_IGNITION
  return embit_ign_step(node->ign_node, steps);
#else
  node->world_control_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_set_gravity(
  embit_gazebo_node_t *node,
  double gx, double gy, double gz
) {
  if (node == NULL || !node->connected) return -1;
#ifdef EMBIT_HAS_IGNITION
  return embit_ign_set_gravity(node->ign_node, gx, gy, gz);
#else
  node->gravity_x = gx;
  node->gravity_y = gy;
  node->gravity_z = gz;
  node->world_control_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
double embit_gazebo_get_gravity_z(embit_gazebo_node_t *node) {
  if (node == NULL) return 0.0;
  return node->gravity_z;
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_world_control_count(embit_gazebo_node_t *node) {
  if (node == NULL) return 0;
  return node->world_control_count;
}

// ===== 场景管理 =====

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_spawn_model(
  embit_gazebo_node_t *node,
  moonbit_bytes_t model_name
) {
  if (node == NULL || !node->connected) return -1;
#ifdef EMBIT_HAS_IGNITION
  return embit_ign_spawn_model(node->ign_node, (const char *)model_name);
#else
  (void)model_name;
  node->model_count++;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_remove_model(
  embit_gazebo_node_t *node,
  moonbit_bytes_t model_name
) {
  if (node == NULL || !node->connected) return -1;
#ifdef EMBIT_HAS_IGNITION
  return embit_ign_remove_model(node->ign_node, (const char *)model_name);
#else
  (void)model_name;
  if (node->model_count <= 0) return -1;
  node->model_count--;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t embit_gazebo_model_count(embit_gazebo_node_t *node) {
  if (node == NULL) return -1;
#ifdef EMBIT_HAS_IGNITION
  return embit_ign_model_count(node->ign_node);
#else
  return node->model_count;
#endif
}
