---
title: Java 内存
categories:
  - 语言
tags:
  - java
sidebar: none 
date: 2021-01-21 
---
### 一、引言

为什么 Java 进程的实际物理内存使用量比 -Xmx 指定的 Max Heap size 大？

为什么 Java NMT 显示的 committed 内存值比RSS值小(或者大)？

是否有办法能限制一个 Java 进程的内存使用么？

怎么排查 Java 进程内存问题？

....

### 二、Linux 内存管理


2.1 Linux 内存概念解析


RSS(RES): Resident Set Size. 进程实际物理内存使用大小。

VIRT:Virtual memory used by the task, it includes all code, data and shared libraries plus pages that have been swapped out and pages that have been mapped but not used. 进程的虚拟内存使用，包括该进程的代码，数据段，共享lib 以及 swap 出磁盘的内存。一般情况下，不用特别关注该指标，VIRT并不意味着物理内存。（64-bit的操作系统，虚拟地址空间大小为128T，可近似认为"无限"；32-bit的操作系统，虚拟空间大小为2G）

Buffer: 对磁盘数据的缓存，既可以用在写，也可以用在读。

Cache:  对文件数据的缓存，既可以用在写，也可以用在读。



2.2 Linux 内存分配


一般 Unix 系统中，用户态的程序通过malloc()调用申请内存。如果返回值是 NULL， 说明此时操作系统没有空闲内存。这种情况下，用户程序可以选择直接退出并打印异常信息或尝试进行 GC 回收内存。然而 Linux 系统总会先满足用户程序malloc请求，并分配一片虚拟内存地址。只有在程序第一次touch到这片内存时，操作系统才会分配物理内存给进程。具体我们可以看下如下demo:



1.调用 malloc，但不touch：
```
#include <stdio.h>
#include <stdlib.h>
int main (void) {
      int n = 0;

      while (1) {
              if (malloc(1<<20) == NULL) {
                      printf("malloc failure after %d MiB\n", n);
                      return 0;
              }
              printf ("got %d MiB\n", ++n);
      }
}
```
2. 调用 malloc，并touch：
```
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int main (void) {
        int n = 0;
        char *p;

        while (1) {
                if ((p = malloc(1<<20)) == NULL) {
                        printf("malloc failure after %d MiB\n", n);
                        return 0;
                }
                memset (p, 0, (1<<20));
                printf ("got %d MiB\n", ++n);
        }
}
```
其中 demo1 在malloc返回NULL前，将申请到很大的内存；demo2 在malloc返回NULL前，将申请到很小的内存。在一个内存8MiB的系统中，demo1 将申请到 274 MiB内存， demo2将申请到仅4MiB内存。


2.3 查看内存使用


free: 查看操作系统内存使用，包含目前的 Buffer，Cache 和 Swap 使用量

top: 查看进程内存，cpu使用等

/proc/[pid]/status: 该文件提供了进程的内存使用信息。VmPeak指，从进程启动到现在使用的虚拟内存最大值；VmSize指，当前该进程的虚拟内存使用量；VmHWM指，从进程启动到当前使用的物理内存最大值，对估计进程实际内存使用有很大帮助；VmRSS指，当前进程的物理内存使用量。例子如下：
![图片](/images/java/1.png)



/proc/[pid]/mem: 通过该文件，可以像操作文件一样，操作进程的虚拟内存内容，如：读，写操作。可以直接修改这个文件的内容，来直接修改某个进程中的某个变量的内容。用一个简单的 Python 程序，我们就可以实现修改进程内存内容的”魔法“，具体可参考：https://blog.holbertonschool.com/hack-the-virtual-memory-c-strings-proc/ 。

/proc/[pid]/maps: 进程的虚拟内存地址分布
![图片](/images/java/2.png)

### 三、Java 进程内存分布
Native Memory Tracking 是Java7U40引入的HotSpot新特性，可以用于追踪 Java 进程内存使用，并可以通过jcmd命令来访问。NMT功能默认关闭，可以通过设置JVM参数 -XX:NativeMemoryTracking=[summary | detail]来打开。值得注意的是，NMT 只能Track JVM自身的内存分配，第三方的Native库内存使用无法Track；NMT 有5%-10%的性能开销。

![图片](/images/java/3.png)



上图是 NMT 的输出例子，可以看到NMT不仅能 Track 堆内存的内存使用，还能Track其他部分的内存使用，如：Class，Code，Compiler，Internal，Symbol等部分的内存使用。其中committed可以认为是物理内存使用，即RSS。下面将对各部分进行分析。



3.1 Heap


Heap 是 Java 进程中使用量最大的一部分内存，是最常遇到内存问题的部分，Java 也提供了很多相关工具来排查堆内存泄露问题，这里不详细展开。Heap 与 RSS 相关的几个重要JVM 参数如下：

Xms：Java Heap 初始内存大小。【不是最小的Heap size】

Xmx：Java Heap 的最大大小。

XX:+AlwaysPretouch:在JVM初始化时，是否直接对Heap部分内存进行”填零“。正如上文所说，进程启动的时候,虽然我们可以为JVM指定合适的内存大小,但是这些内存操作系统并没有真正的分配给JVM,而是等JVM访问这些内存的时候,才真正分配。通过配置这个参数JVM就会先访问所有分配给它的内存,让操作系统把内存真正的分配给JVM.从而提高运行时的性能，后续JVM就可以更好的访问内存了。

XX:+UseAdaptiveSizePolicy：是否开启自适应大小策略。开启后，JVM将动态判断是否调整Heap size，来降低系统负载。



3.2 Metaspace


Metaspace 主要包含方法的字节码，Class对象，常量池。一般来说，记载的类越多，Metaspace 使用的内存越多。与Metaspace相关的JVM参数有:

XX:MaxMetaspaceSize: 最大的Metaspace大小限制【默认无限制】

XX:MetaspaceSize=64M: 初始的Metaspace大小。如果Metaspace空间不足，将会触发Full gc，例子如下图：



![图片](/images/java/4.png)


3.3 Thread


NMT 中显示的Thread 部分内存与线程数与-Xss参数成正比，一般来说committed内存等于Xss*线程数。下图中显示有38个线程，committed内存大约为38M，从这可以推断出该Java 进程的Xss参数值为1M。


![图片](/images/java/5.png)

然而比较幸运的是，NMT 中Thread 的committed内存，并不等于 Java 线程的实际内存使用，具体可以参考：

https://stackoverflow.com/questions/31173374/why-does-a-jvm-report-more-committed-memory-than-the-linux-process-resident-set

https://github.com/apangin/jstackmem/blob/master/jstackmem.py

NMT 中Thread部分实际物理内存使用，大致可以用下图描述：

![图片](/images/java/6.png)

3.4 Code
JIT 动态编译产生的Code占用的内存。这部分内存主要由-XX:ReservedCodeCacheSize参数进行控制，默认是：240M。可以通过关闭分层编译-XX:-TieredCompilation来减低Code Cache部分的内存使用。另外，-XX:+PrintCodeCache参数，可以打印出Code Cache相关的详细信息，帮助我们定位内存泄露问题，打印信息如下：



![图片](/images/java/7.png)



3.5 Internal
Internal 部分内存主要是java.nio.DirectByteBuffer对象占用。java.nio.DirectByteBuffer是’冰山对象‘，Heap中有堆外内存的引用,heap内的引用对象内存占用很小，实际的内存使用不在heap上，而是通过Unsafe.allocate进行分配的。查看java.nio.DirectByteBuffer的内存使用，有两个方法：

通过NMT输出日志，查看Internal部分的committed内存 和 Unsafe调用分配内存：

![图片](/images/java/8.png)

MAT分析Heap中java.nio.Bits类中totalCapcity：

![图片](/images/java/9.png)

具体原理，可以参考之前的一个回答：https://www.zhihu.com/question/58943470/answer/1130876729


3.6 Symbol
Symbol 部分主要有两部分：

SymbolTable: names signatures

StringTable: interned strings可以通过-XX:+PrintStringTableStatistics打印具体的信息，输入大致如下：

![图片](/images/java/10.png)


3.7 小结
1、为什么 Java 进程的实际物理内存使用量比 -Xmx 指定的 Max Heap size 大？

答：有堆外内存，如：Code，Metaspace，Class，Thread，Internal等其他的内存消耗部分。

2、为什么 Java NMT 显示的 committed 内存值比RSS值小(或者大)？

答：一般情况下NMT Track出来的 committed 内存值既可能比RSS值大，也可能比RSS小，主要原因是：

比真实RSS小：NMT 只能Track JVM自身的内存分配情况，比如：Heap内存分配，direct byte buffer等；不能 Track jni里直接调用malloc时的内存分配，这里最典型的就是ZipInputStream的场景。

比真实RSS大：NMT 中关于Thread的部分的 committed 部分内存，基本等于-Xss值 * Thread数量，并没有反映Java Thread Stack真实对应到RSS的内存值。（可能是JVM的bug？）考虑到操作系统内存的懒加载机制，单个Thread Stack实际RSS使用基本在100k左右。详细信息可参考：https://stackoverflow.com/questions/31173374/why-does-a-jvm-report-more-committed-memory-than-the-linux-process-resident-set。简单的说，就是从NMT上看到的Thread committed内存是大于Thread的实际Rss值的。

3、是否有办法能限制一个 Java 进程的内存使用么？

答：没有。Java 有很多无法限制的部分，如：Metaspace，Thread，第三方Native调用等。


### 四、怎么排查


4.1 大致流程
![图片](/images/java/11.png)


4.2 Java
jmap: dump heap dump；分析heap

jcmd: NMT 分析

jinfo：查看进程启动命令，确定各JVM参数的配置值

MAT: 分析Heap

NMT: 分析具体Java 进程的各部分内存分布，包含堆外内存

....


4.3 系统级别


pmap：追踪“可疑”内存

strace：追踪系统调用

gdb: dump “可疑”内存内容，帮助分析内存泄露问题



五、Example
https://zhuanlan.zhihu.com/p/54048271

https://zhuanlan.zhihu.com/p/60976273

六、参考
Difference with Linux VmRSS and the total commited memory of Java NativeMemoryTraking (NMT)：https://stackoverflow.com/questions/58430156/difference-with-linux-vmrss-and-the-total-commited-memory-of-java-nativememorytr

如何用async-profiler profile 堆外内存：https://stackoverflow.com/questions/53576163/interpreting-jemaloc-data-possible-off-heap-leak/53598622#53598622

Memory Footprint of A Java Process: https://vimeo.com/364039638

Why does a JVM report more committed memory than the linux process resident set size?: https://stackoverflow.com/questions/31173374/why-does-a-jvm-report-more-committed-memory-than-the-linux-process-resident-set