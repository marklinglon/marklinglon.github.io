---
title: K个一组反转列表
categories: 
  - 算法
tags:
  - K个一组反转列表
sidebar: none 
date: 2024-02-01
---
```
package main

import "fmt"

type ListNode struct {
    Val  int
    Next *ListNode
}

func reverseKGroup(head *ListNode, k int) *ListNode {
    // 检查链表长度是否满足反转条件
    count := 0
    current := head
    for count < k {
        if current == nil {
            return head
        }
        current = current.Next
        count++
    }

    // 反转当前 K 个节点
    prev := reverseList(head, current)

    // 递归处理下一组 K 个节点
    head.Next = reverseKGroup(current, k)

    return prev
}

func reverseList(head, tail *ListNode) *ListNode {
    var prev, next *ListNode
    current := head

    for current != tail {
        next = current.Next
        current.Next = prev
        prev = current
        current = next
    }

    return prev
}

func printList(head *ListNode) {
    current := head
    for current != nil {
        fmt.Printf("%d ", current.Val)
        current = current.Next
    }
    fmt.Println()
}

func main() {
    // 创建一个链表
    head := &ListNode{Val: 1}
    head.Next = &ListNode{Val: 2}
    head.Next.Next = &ListNode{Val: 3}
    head.Next.Next.Next = &ListNode{Val: 4}
    head.Next.Next.Next.Next = &ListNode{Val: 5}

    // 设定 K 的值
    k := 2

    // 反转链表每 K 个节点
    result := reverseKGroup(head, k)

    // 输出结果
    fmt.Print("反转后的链表: ")
    printList(result)
}

```