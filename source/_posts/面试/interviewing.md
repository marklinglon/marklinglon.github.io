---
title: interviewing
categories:
  - 面试
tags:
  - interviewing 面试
sidebar: none 
date: 2024-04-19
---

# redis的数据类型
字符串：value是一个字符串
列表：value是一个列表
hash：value是一个key-value集合
set：value是一个没有重复数据的字符串集合
zset（sorted set）：value包含score和member，member不可以重复，score可以

# redis中穿透、击穿、雪崩的区别
穿透：缓存中不存在
击穿：某个缓存过期
雪崩：大量缓存过期
解决：布隆过滤器、简单的缓存校验、缓存永不过期、异步更新缓存时间、使用不同的缓存过期时间等

# mq的模式
简单模式（点对点）：P->queue->C，单一的消费者
work queues：P->queue->(c1,c2,c3...),不止一个消费者
public/subscribe发布订阅：P-X-queue1，queue2->(c1,c2,c3...),
  在workqueue的基础上多了一个转换器，而且队列也变成了多种
  X：exchange交换机，一方面接收消息，一方面知道如何处理这些消息
  exchange也有多种：
    广播：将消息交给所有绑定到交换机的队列
    定向（路由模式）：把消息交给制定routing key的队列
    topic（通配符）：把消息交给符合routing pattern路由模式的队列
routing路由模式：与发布订阅模式相似，不同的是队列与交换机的绑定不能是任意的了，而是要制定一个
  routing key，只有队列的routing key和消息的routing key一致，队列才能接收到消息
topics主题模式：与路由模式类似，区别在于，绑定的key支持统配
rpc模式：rabbitmq的工作模式，属于点对点的同步模式

# k8s service的类型
包括 ClusterIP、NodePort、LoadBalancer 等。其中，LoadBalancer 类型的 Service 可以使用云服务提供商的负载均衡器（如AWS ELB、GCP Load Balancer）来实现负载均衡。

# k8s 的屋头服务
它与普通服务（具有 ClusterIP）不同。无头服务在定义时通过将 .spec.clusterIP 设置为空来声明，这使得它没有集群内部的虚拟 IP 地址。无头服务的作用是为了让客户端直接访问服务的后端 Pod 的网络地址，而不是通过 Service 的虚拟 IP 地址。

# k8s的健康检查的探针类型
存活探针（Liveness Probe）：
存活探针用于检测容器是否处于运行状态。如果存活探针失败（返回失败状态），Kubernetes 将杀死容器并重新启动它。这有助于处理容器内部发生的假死或死锁等情况。
就绪探针（Readiness Probe）：
就绪探针用于检测容器是否已准备好接受流量。如果就绪探针失败（返回失败状态），Kubernetes 将从服务负载均衡中删除该容器，直到就绪探针再次成功为止。这有助于避免将流量发送到尚未完全启动或初始化的容器。
启动探针（Startup Probe）：
启动探针是 Kubernetes 1.16 版本中引入的一种探针类型。它类似于存活探针，但它只在容器启动时执行一次，而不是在整个容器生命周期内定期执行。启动探针用于检测容器是否已经准备好接受流量，并且它的超时时间比存活探针的超时时间更长。

# Kubernetes 中有几种健康检查方式，用于确保容器的健康状态：
HTTP 健康检查：
使用 HTTP 健康检查时，Kubernetes 会周期性地向容器发送 HTTP 请求，并检查响应的状态码。如果响应状态码指示成功，则容器被视为健康；否则，容器被标记为不健康，可能会被重新启动。
TCP 健康检查：
TCP 健康检查通过向容器发送 TCP 连接请求，并检查连接是否成功建立来确定容器的健康状态。如果连接成功建立，则容器被视为健康；否则，容器被标记为不健康，可能会被重新启动。
命令执行健康检查：
命令执行健康检查会周期性地执行指定的命令或脚本，并检查其返回状态码来确定容器的健康状态。如果命令或脚本返回成功状态码，则容器被视为健康；否则，容器被标记为不健康，可能会被重新启动。

# linux误删的日志文件如何恢复
lsof|grep -i delete
根据pid和文件描述符找到文件位置/proc/pid/fd/number
备份，然后重启进程
