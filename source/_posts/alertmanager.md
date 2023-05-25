---
title: Alertmanager
---
```
global:
  smtp_smarthost: ""
  smtp_from: ""
  smtp_auth_username: ""
  smtp_auth_password: ""
route:
  group_by: ["alertname","severity"]
  group_wait: 60s # 接收到告警后，多久开始发送,
  group_interval: 120s # 同一个周期内，多个分组发送报警的间隔时间
  repeat_interval: 60s # 不同周期内，每个分组重复告警的时间间隔
  receiver: devops # 默认使用这个接收器
  routes:
  - receiver: test-dev
    group_wait: 10s
    match_re:
       POD_IP: '^10\.100.*'
       alertname: ^(BlackboxProbeFailed|PodMemoryUsageAlmostFull|JvmMemoryUsageAlmostFull|ElasticsearchNoNewDocuments|etcdMembersDown|etcdInsufficientMembers|etcdNoLeader|JvmFullGcOccured|JvmThreadsUsageOverload|PodNotReady|KubePodNotReady)$
  - receiver: prod-dev
    group_wait: 10s
    match_re:
       POD_IP: '^10\.102.*'
       alertname: ^(BlackboxProbeFailed|PodMemoryUsageAlmostFull|JvmMemoryUsageAlmostFull|ElasticsearchNoNewDocuments|etcdMembersDown|etcdInsufficientMembers|etcdNoLeader|JvmFullGcOccured|JvmThreadsUsageOverload|PodNotReady|KubePodNotReady)$
  - receiver: test-ops-crit
    group_wait: 10s
    match_re:
      severity: critical
      POD_IP: '^10\.100.*'
  - receiver: prod-ops-crit
    group_wait: 10s
    match_re:
      severity: critical
      POD_IP: '^10\.102.*'
  - receiver: test-ops-warn
    group_wait: 10s
    match_re:
      severity: warning
      POD_IP: '^10\.100.*'
  - receiver: prod-ops-warn
    group_wait: 10s
    match_re:
      severity: warning
      POD_IP: '^10\.102.*'

receivers:
- name: 'devops'
  webhook_configs:
  - url: http://alertmanager-wechat:8001
    send_resolved: false

- name: 'test-ops-crit'
  webhook_configs:
  - url: ""
    send_resolved: false

- name: 'test-ops-warn'
  webhook_configs:
  - url: ""
    send_resolved: false

- name: 'test-dev'
  webhook_configs:
  - url: ""
    send_resolved: false

- name: 'prod-ops-crit'
  webhook_configs:
  - url: ""
    send_resolved: false

- name: 'prod-ops-warn'
  webhook_configs:
  - url: ""
    send_resolved: false

- name: 'prod-dev'
  webhook_configs:
  - url: ""
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