---
title: 求最小数
categories: 
  - 算法
tags:
  - 最小数
sidebar: none 
date: 2024-02-01
---
```
func findMin(nums []int) int {
    if len(nums) == 0 {
        // 列表为空时返回一个合适的默认值，或者根据实际情况决定如何处理
        return 0
    }

    // 初始化最小值为列表的第一个元素
    min := nums[0]

    // 遍历列表，更新最小值
    for _, num := range nums {
        if num < min {
            min = num
        }
    }

    return min
}
```