---
title: Alertmanager
categories: 
  - 监控
tags:
  - k8s
sidebar: none 
date: 2018-05-21
---
```
global:
  smtp_smarthost: ""
  smtp_from: ""
  smtp_auth_username: ""
  smtp_auth_password: ""
route:
  route:
  group_by: ["alertname","severity"，"pod","nodename"]
  group_wait: 15s # 接收到告警后，多久开始发送
  group_interval: 120s # 120s触发一次分组，如果有告警只告警一次，如果有新的告警，必须是120s之后才会触发告警，不会立即告警
  repeat_interval: 21600s # 每个分组重复告警的时间间隔
  receiver: devops
  routes:
  - receiver: devops
    group_wait: 10s
    match:
      severity: critical
  - receiver: devops
    group_wait: 10s
    match:
      severity: error
  - receiver: devops
    group_wait: 10s
    match:
      severity: warning

receivers:
- name: 'devops'
  webhook_configs:
  - url: http://alertmanager-wechat:8001
    send_resolved: false

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'critical'
    equal: ['alertname']
  - source_match:
      severity: 'error'
    target_match:
      severity: 'error'
    equal: ['alertname']
  - source_match:
      severity: 'warning'
    target_match:
      severity: 'warning'
    equal: ['alertname']
```