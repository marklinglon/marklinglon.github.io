---
title: 四数组相加II
categories: 
  - 算法
tags:
  - 四数组相加II
sidebar: none 
date: 2024-02-01
---
```
package main

import "fmt"

func fourSumCount(A []int, B []int, C []int, D []int) int {
    sumCount := make(map[int]int)

    // 统计A和B数组中元素的和的组合
    for _, a := range A {
        for _, b := range B {
            sumCount[a+b]++
        }
    }

    result := 0

    // 遍历C和D数组，查找和的相反数在sumCount中的数量
    for _, c := range C {
        for _, d := range D {
            result += sumCount[-(c + d)]
        }
    }

    return result
}

func main() {
    A := []int{1, 2}
    B := []int{-2, -1}
    C := []int{-1, 2}
    D := []int{0, 2}

    count := fourSumCount(A, B, C, D)

    fmt.Printf("满足条件的组合数量是：%d\n", count)
}

```