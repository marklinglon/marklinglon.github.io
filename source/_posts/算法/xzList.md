---
title: 搜索旋转排序数组
categories: 
  - 算法
tags:
  - 旋转排序数组
sidebar: none 
date: 2024-02-01
---
```
package main

import "fmt"

type MyQueue struct {
    inStack  \[\]int
    outStack \[\]int
}

func Constructor() MyQueue {
    return MyQueue{}
}

func (q *MyQueue) Enqueue(x int) {
    q.inStack = append(q.inStack, x)
}

func (q *MyQueue) Dequeue() int {
    if len(q.outStack) == 0 {
        q.transfer()
    }

    if len(q.outStack) == 0 {
        // 队列为空，返回一个合适的默认值，或者根据实际情况决定如何处理
        return 0
    }

    val := q.outStack\[len(q.outStack)-1\]
    q.outStack = q.outStack\[:len(q.outStack)-1\]
    return val
}

func (q *MyQueue) transfer() {
    for len(q.inStack) > 0 {
        q.outStack = append(q.outStack, q.inStack\[len(q.inStack)-1\])
        q.inStack = q.inStack\[:len(q.inStack)-1\]
    }
}

func main() {
    queue := Constructor()

    queue.Enqueue(1)
    queue.Enqueue(2)
    queue.Enqueue(3)

    fmt.Println(queue.Dequeue()) // 输出：1
    fmt.Println(queue.Dequeue()) // 输出：2

    queue.Enqueue(4)

    fmt.Println(queue.Dequeue()) // 输出：3
    fmt.Println(queue.Dequeue()) // 输出：4
}
```