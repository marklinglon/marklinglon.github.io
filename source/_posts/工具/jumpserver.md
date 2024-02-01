---
title: jumpserver问题处理
categories:
  - 工具
tags:
  - jumpserer
sidebar: none 
date: 2023-05-21 
---
# 登陆提示密码过期
WARNING: Your password has expired.
You must change your password now and login again!
Changing password for user .
Current password: 
# 处理
> 1. 管理员登陆jumpserver
> 2. 修改用户密码
> 3. 用securecrt登陆该用户，发现问题依旧
> 4. chage -l 用户名 // 查看用户密码过期时间
> 5. 修改宿主机的密码策略 vim /etc/login.def PASS_MAX_DAYS   99999
> 6. ansible TestCvm -m shell -a "chage -M -1 username" // 设置某个用户的密码过期时间永不过期