
# GDB STL Views (Modernized) - 嵌入式 Core Dump 深度调试指南

## 1\. 项目概述

**`stl_views.gdb`** 是一套专为嵌入式 Linux 开发设计的 GDB 宏脚本（GDB Command Script）。它旨在解决在 **没有 Python 支持**、**GDB 版本受限** 或 **交叉编译环境符号不全** 的严苛条件下，无法直观查看 C++ STL 容器内容的痛点。

本脚本基于经典的 `stl-views` 理念进行现代化重构，针对 **GCC (libstdc++ v3)** 的内存布局（ABI）进行了深度优化。

### 核心特性

  * **零依赖**：纯 GDB 宏编写，无需 GDB Python 支持，适用于任何嵌入式 GDB 版本。
  * **Deque 修复**：修正了老版本脚本无法遍历 `std::deque` 中间 Buffer 块的严重 Bug。
  * **范围打印**：`std::vector` 支持指定索引范围打印，防止在大数据量下刷屏。
  * **多态支持**：自动开启 RTTI 和 Pretty Print，准确识别对象真实类型。
  * **容器全覆盖**：支持 `vector`, `list`, `deque`, `map`, `multimap`, `set`, `multiset`, `stack`, `queue`, `string`。

-----

## 2\. 快速开始

### 2.1 加载脚本

在 GDB 会话中（或写入 `~/.gdbinit`）加载脚本：

```bash
(gdb) source path/to/stl_views.gdb
```

脚本加载时会自动执行以下初始化配置，以确保最佳显示效果：

  * `set print pretty on` (美化结构体输出)
  * `set print object on` (开启 RTTI，显示子类真实类型)
  * `set print static-members on` (显示静态成员)
  * `set print demangle on` (C++ 符号解码)

-----

## 3\. 命令参考手册

**注意**：所有命令均需显式传入 **元素类型** (`<type>`)，因为在 Release 模式或 `void*` 转换时，GDB 无法自动推导类型。

### 3.1 std::vector

基于 `_M_start` 和 `_M_finish` 指针运算。

  * **语法**：

      * `pvector <vec_var> <type>`：打印所有元素。
      * `pvector <vec_var> <type> <idx>`：打印指定下标的元素。
      * `pvector <vec_var> <type> <start_idx> <end_idx>`：**[推荐]** 打印指定范围。

  * **示例**：

    ```gdb
    # 打印 my_vec 中第 10 到第 20 个元素
    pvector my_vec int 10 20

    # 打印对象指针 vector 的第 5 个元素
    pvector ptr_vec MyClass* 5
    ```

### 3.2 std::list

基于 `_List_node` 双向链表。脚本会自动跳过节点头 (`prev/next`) 定位数据区。

  * **语法**：

      * `plist <list_var> <type>`：打印所有元素。
      * `plist <list_var> <type> <idx>`：线性扫描并打印第 `idx` 个元素。

  * **示例**：

    ```gdb
    plist active_sessions Session 0
    ```

### 3.3 std::deque (及 stack, queue)

**关键改进**：实现了跨 `Block` (`_M_node`) 的完整遍历逻辑，解决了跨块数据丢失问题。

  * **语法**：

      * `pdeque <deq_var> <type>`：打印 `std::deque`。
      * `pqueue <queue_var> <type>`：打印 `std::queue` (默认解包内部 `c` 成员)。
      * `pstack <stack_var> <type>`：打印 `std::stack`。

  * **示例**：

    ```gdb
    # 查看消息队列
    pqueue msg_q MessageT
    ```

### 3.4 std::map / std::multimap

基于红黑树（Red-Black Tree）的非递归中序遍历。

  * **语法**：

      * `pmap <map_var> <key_type> <val_type>`

  * **输出说明**：
    GDB 宏难以完美处理 `std::pair` 的打印。脚本会分别打印 `Key` 和指向 `Pair` 的指针。

      * **Key**: 直接打印。
      * **Val**: 打印为 `(std::pair<const Key, Val>*) 0x...`。
      * **查看 Value**：如果 GDB 没有自动展开 Pair，请复制该地址手动查看：`p *(ValType*)((char*)addr + offset)`。

### 3.5 std::set / std::multiset

红黑树遍历，节点仅包含 Key。

  * **语法**：
      * `pset <set_var> <type>`

### 3.6 std::string

兼容现代 GCC 的 SSO (Short String Optimization) 机制，直接访问 `_M_dataplus._M_p`。

  * **语法**：
      * `pstring <str_var>`

-----

## 4\. 专家故障排查 (Expert Troubleshooting)

作为资深工程师，在分析 Core Dump 时可能会遇到以下异常，请参考处理：

### 4.1 报错：`Structure has no component named _M_impl`

  * **原因**：
    1.  目标程序不是使用 GCC (`libstdc++`) 编译的（例如使用了 Clang `libc++`）。
    2.  STL 版本极老（GCC 2.95 时代）或极新（未来架构变更）。
  * **对策**：本脚本仅适用于标准的 GCC `libstdc++` 内存布局。

### 4.2 报错：`Cannot access memory at address 0x...`

  * **原因**：**内存踩踏 (Memory Stomp/Corruption)**。
      * 容器内部指针（如 `_M_start`, `_M_next`, `_M_parent`）被越界写破坏，指向了无效地址。
  * **对策**：
      * **Vector**：手动检查 `p vec._M_impl._M_start`，如果地址极小（如 `0x5`）或极大，说明对象头已损坏。
      * **List/Map**：如果在遍历中途报错，说明链表/树结构断裂。脚本无能为力，需转为十六进制内存 (`x/100x`) 分析。

### 4.3 陷入死循环 (GDB 无响应)

  * **原因**：**链表/树成环**。
      * 通常发生在使用 `plist` 或 `pmap` 时，由于内存破坏导致节点 `next` 指针指向了之前的节点。
  * **对策**：按下 `Ctrl+C` 强制中断脚本执行。

### 4.4 类型解析错误

  * **现象**：输出 `Attempt to dereference a generic pointer` 或乱码。
  * **原因**：传入的 `<type>` 在当前上下文不可见，或必须是指针类型。
  * **对策**：
    1.  使用 `ptype <var>` 确认 GDB 识别的类型名称。
    2.  尝试加上命名空间：`pvector v Namespace::MyClass`。
    3.  如果符号表丢失，尝试用 `void*` 打印地址：`pvector v void*`。

-----

## 5\. 维护信息

  * **适用架构**：x86\_64, ARM, AArch64, MIPS 等所有支持 GDB 的架构。
  * **依赖 ABI**：Itanium C++ ABI (GCC 默认)。
  * **作者**：Embedded Linux Expert
  * **版本**：2.0 (Modernized)
