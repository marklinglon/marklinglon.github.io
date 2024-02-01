---
title: wechat gpt
categories:
  - 工具
tags:
  - gpt
sidebar: none 
date: 2023-05-21
---

# 下载

git clone https://github.com/869413421/wechatbot.git

# 进入项目目录
cd wechatbot

# 创建配置文件
```
cat >>  config.json <<EOF
{
          "api_key": "your gpt api key",
          "auto_pass": true
}
EOF
```

# 启动项目
go run main.go

# 换账号登陆
rm -f storage.json
go run main.go
