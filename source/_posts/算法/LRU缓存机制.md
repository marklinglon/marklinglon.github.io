---
title: LRU缓存机制
categories: 
  - 算法
tags:
  - LRU缓存机制
sidebar: none 
date: 2024-02-01
---
```
package main

import "fmt"

type LRUCache struct {
	capacity int
	cache    map[int]*Node
	head     *Node
	tail     *Node
}

type Node struct {
	key   int
	value int
	prev  *Node
	next  *Node
}

func Constructor(capacity int) LRUCache {
	return LRUCache{
		capacity: capacity,
		cache:    make(map[int]*Node),
		head:     nil,
		tail:     nil,
	}
}

func (lru *LRUCache) get(key int) int {
	if node, ok := lru.cache[key]; ok {
		// 移动被访问的节点到头部
		lru.moveToHead(node)
		return node.value
	}
	return -1
}

func (lru *LRUCache) put(key, value int) {
	if node, ok := lru.cache[key]; ok {
		// 更新节点值
		node.value = value
		// 移动被访问的节点到头部
		lru.moveToHead(node)
	} else {
		// 创建新节点
		node := &Node{key: key, value: value}
		lru.cache[key] = node

		// 缓存已满，淘汰最久未使用的节点
		if len(lru.cache) > lru.capacity {
			lru.removeTail()
		}

		// 将新节点添加到头部
		lru.addToHead(node)
	}
}

func (lru *LRUCache) moveToHead(node *Node) {
	if node != lru.head {
		lru.removeNode(node)
		lru.addToHead(node)
	}
}

func (lru *LRUCache) removeNode(node *Node) {
	if node.prev != nil {
		node.prev.next = node.next
	} else {
		lru.head = node.next
	}

	if node.next != nil {
		node.next.prev = node.prev
	} else {
		lru.tail = node.prev
	}
}

func (lru *LRUCache) addToHead(node *Node) {
	node.prev = nil
	node.next = lru.head

	if lru.head != nil {
		lru.head.prev = node
	}

	lru.head = node

	if lru.tail == nil {
		lru.tail = node
	}
}

func (lru *LRUCache) removeTail() {
	if lru.tail != nil {
		delete(lru.cache, lru.tail.key)
		lru.removeNode(lru.tail)
	}
}

func main() {
	// 创建容量为 2 的 LRU 缓存
	lru := Constructor(2)

	// 插入键值对
	lru.put(1, 1)
	lru.put(2, 2)

	// 查询键 1
	fmt.Println("查询键 1 的结果:", lru.get(1)) // 输出 1

	// 插入新的键值对
	lru.put(3, 3)

	// 键 2 已经超出缓存容量，因此被淘汰
	fmt.Println("查询键 2 的结果:", lru.get(2)) // 输出 -1

	// 插入新的键值对
	lru.put(4, 4)

	// 键 1 已经超出缓存容量，因此被淘汰
	fmt.Println("查询键 1 的结果:", lru.get(1)) // 输出 -1

	// 查询键 3
	fmt.Println("查询键 3 的结果:", lru.get(3)) // 输出 3

	// 查询键 4
	fmt.Println("查询键 4 的结果:", lru.get(4)) // 输出 4
}
```