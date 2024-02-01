---
title: hexo部署使用
categories:
  - 工具
tags:
  - hexo
sidebar: none 
date: 2021-01-21 
---
Welcome to [Hexo](https://hexo.io/)! This is your very first post. Check [documentation](https://hexo.io/docs/) for more info. If you get any problems when using Hexo, you can find the answer in [troubleshooting](https://hexo.io/docs/troubleshooting.html) or you can ask me on [GitHub](https://github.com/hexojs/hexo/issues).

## 部署过程参考链接
```
https://blog.cofess.com/2017/11/01/hexo-blog-theme-pure-usage-description.html // 部署文档
http://blog.iwwee.com/posts/hexo-optimize.html // 优化
https://hexo.io/zh-cn/docs/syntax-highlight.html // 代码高亮
```

## create article in dir source/_posts

``` bash
$ hexo new "My New Post"
```

More info: [Writing](https://hexo.io/docs/writing.html)

### Run server

``` bash
$ hexo server
```

### Deploy to remote sites

``` bash 
$ hexo clean ;hexo generate;hexo deploy
```