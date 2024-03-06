---
title: Prometheus Metrics中一些常用的方法
categories: 
  - Prometheus
tags:
  - k8s
sidebar: none 
date: 2020-06-21
---
Prometheus 查询语言（PromQL）中一些常用的方法包括：

sum()：用于计算时间序列的总和。

rate()：计算时间序列数据的速率或增长率。

irate()：计算时间序列数据的瞬时速率或增长率。

count()：计算时间序列数据样本的数量。

avg()：计算时间序列数据的平均值。

min() 和 max()：分别计算时间序列数据的最小值和最大值。

absent()：用于检查是否缺少特定标签的时间序列数据。

label_replace()：用于替换标签的值。

topk() 和 bottomk()：分别返回时间序列数据中最高或最低值的样本。

histogram_quantile()：用于计算直方图的分位数。