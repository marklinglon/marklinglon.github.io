---
title: 不含AAA或BBB的字符串
categories: 
  - 算法
tags:
  - 不含AAA或BBB的字符串
sidebar: none 
date: 2024-02-01
---
```
package main

import "fmt"

func generateString() string {
	result := ""
	countA, countB := 0, 0

	for countA+countB < 7 { // 控制字符串长度，这里选择了 7，你可以根据实际情况调整
		if countA < 2 || (countA >= 2 && countB < 1) {
			result += "A"
			countA++
		} else {
			result += "B"
			countB++
		}
	}

	return result
}

func main() {
	str := generateString()
	fmt.Println("生成的字符串:", str)
}

```