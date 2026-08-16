// gazebo_ignition.h — Ignition Transport C 接口声明
//
// 这些 C 接口由 gazebo_ignition_wrapper.cpp 实现，用 extern "C" 暴露。
// gazebo_stub.c 在 EMBIT_HAS_IGNITION 定义时调用这些接口。
//
// 真实实现依赖 Ignition Transport C++ 库（Gazebo Fortress+），
// 由 scripts/prepare.py 编译成静态库后通过 link.native 链接。

#ifndef EMBIT_GAZEBO_IGNITION_H
#define EMBIT_GAZEBO_IGNITION_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ===== 连接管理 =====
// 创建 Ignition Transport 节点并连接到指定地址。
// address: UTF-8 编码的连接地址（如 "localhost:9000"），NULL 表示默认分区。
// 返回：节点句柄（void*），NULL 表示连接失败。
void *embit_ign_node_create(const char *address);

// 销毁节点并释放资源。
void embit_ign_node_destroy(void *node);

// 查询连接状态。返回：1=已连接, 0=未连接。
int32_t embit_ign_is_connected(void *node);

// ===== 话题通信 =====
// 发布消息到指定话题。
// topic: UTF-8 话题名（NULL 结尾）。
// data/len: 原始消息字节流（序列化 protobuf 或 Ignition 消息）。
// 返回：0=成功, -1=失败。
int32_t embit_ign_publish(void *node, const char *topic, const void *data, int32_t len);

// 订阅话题。返回：0=成功, -1=失败。
int32_t embit_ign_subscribe(void *node, const char *topic);

// 取消订阅。返回：0=成功, -1=失败。
int32_t embit_ign_unsubscribe(void *node, const char *topic);

// 调用仿真服务（同步 RPC）。
// service: UTF-8 服务名。request/req_len: 请求消息字节流。
// 返回：0=成功, -1=失败。
int32_t embit_ign_service_call(void *node, const char *service, const void *request, int32_t req_len);

// ===== 世界控制 =====
int32_t embit_ign_reset_world(void *node);
int32_t embit_ign_pause(void *node);
int32_t embit_ign_unpause(void *node);
int32_t embit_ign_is_paused(void *node);  // 返回：1=暂停, 0=运行, -1=失败
int32_t embit_ign_step(void *node, int32_t steps);
int32_t embit_ign_set_gravity(void *node, double gx, double gy, double gz);

// ===== 场景管理 =====
int32_t embit_ign_spawn_model(void *node, const char *model_name);
int32_t embit_ign_remove_model(void *node, const char *model_name);
int32_t embit_ign_model_count(void *node);  // 返回：模型数量, -1=失败

#ifdef __cplusplus
}
#endif

#endif // EMBIT_GAZEBO_IGNITION_H