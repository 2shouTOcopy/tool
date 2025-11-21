# GDB Macro Script for C++ STL Containers (Modern GCC/libstdc++)
# Author: Embedded Linux Expert (Refined based on stl-views-1.03 concepts)
# Usage: source stl_views.gdb
#
# 特性:
# 1. 修复 std::deque 遍历缺失中间块的问题
# 2. 支持 std::vector, std::list 的范围/索引打印
# 3. 兼容现代 GCC std::string (SSO)
# 4. 支持 queue, stack, multimap, set, multiset

set print pretty on
set print object on
set print static-members on
set print vtbl on
set print demangle on
set demangle-style gnu-v3

# =========================================================================
# 1. std::vector
# Usage: 
#   pvector <var> <type>            : 打印所有
#   pvector <var> <type> <idx>      : 打印指定下标
#   pvector <var> <type> <start> <end> : 打印范围
# =========================================================================
define pvector
    if $argc == 0
        help pvector
    else
        set $vec = $arg0
        set $start = $vec._M_impl._M_start
        set $finish = $vec._M_impl._M_finish
        set $capacity = $vec._M_impl._M_end_of_storage
        
        set $size = ($finish - $start)
        set $cap = ($capacity - $start)
        
        printf "Vector Info (Size: %d, Cap: %d)\n", $size, $cap
        
        if $argc == 2
            # 打印所有
            set $i = 0
            set $p = $start
            while $p != $finish
                printf "[%d] = ", $i
                p *($arg1*)$p
                set $p++
                set $i++
            end
        end
        
        if $argc == 3
            # 打印指定索引
            set $idx = $arg2
            if $idx >= 0 && $idx < $size
                set $p = $start + $idx
                printf "[%d] = ", $idx
                p *($arg1*)$p
            else
                printf "Index %d out of range [0..%d]\n", $idx, $size-1
            end
        end
        
        if $argc == 4
            # 打印范围
            set $idx_start = $arg2
            set $idx_end = $arg3
            if $idx_start > $idx_end
               printf "Invalid range.\n"
            else
               if $idx_end >= $size
                   set $idx_end = $size - 1
               end
               set $i = $idx_start
               set $p = $start + $idx_start
               set $p_end = $start + $idx_end
               
               while $i <= $idx_end
                   printf "[%d] = ", $i
                   p *($arg1*)$p
                   set $p++
                   set $i++
               end
            end
        end
    end
end
document pvector
  Prints std::vector<T>.
  Syntax: 
    pvector <vec> <type>
    pvector <vec> <type> <idx>
    pvector <vec> <type> <start_idx> <end_idx>
end

# =========================================================================
# 2. std::list
# Usage: plist <list> <type> [index]
# =========================================================================
define plist
    if $argc < 2
        help plist
    else
        set $list = $arg0
        set $head = &$list._M_impl._M_node
        set $node = $list._M_impl._M_node._M_next
        set $i = 0
        set $target_idx = -1
        
        if $argc == 3
            set $target_idx = $arg2
        end
        
        printf "List Info:\n"
        if $node == $head
            printf "  (Empty)\n"
        else
            while $node != $head
                if $target_idx == -1 || $target_idx == $i
                    set $data_ptr = (void*)($node + 1)
                    printf "[%d] = ", $i
                    p *($arg1*)$data_ptr
                end
                
                if $target_idx == $i
                    loop_break
                end
                
                set $node = $node._M_next
                set $i++
            end
        end
        if $target_idx == -1
            printf "Total Size: %d\n", $i
        end
    end
end
document plist
  Prints std::list<T>.
  Syntax: plist <list> <type> [opt: index]
end

# =========================================================================
# 3. std::deque (修复版 - 支持完整遍历)
# Usage: pdeque <deque> <type>
# =========================================================================
define pdeque
    if $argc != 2
        help pdeque
    else
        set $deq = $arg0
        set $type_size = sizeof($arg1)
        
        # Calculate Buffer Size (GCC Logic)
        if $type_size < 512
            set $buf_size = 512 / $type_size
        else
            set $buf_size = 1
        end
        
        set $start_node = $deq._M_impl._M_start._M_node
        set $start_cur = $deq._M_impl._M_start._M_cur
        
        set $finish_node = $deq._M_impl._M_finish._M_node
        set $finish_cur = $deq._M_impl._M_finish._M_cur
        
        printf "Deque Info (BufSize: %d):\n", $buf_size
        
        set $curr_node = $start_node
        set $curr_ptr = $start_cur
        set $idx = 0
        
        # 跨 Block 遍历核心逻辑
        while $curr_node <= $finish_node
            # 计算当前 Block 的边界
            if $curr_node == $finish_node
                set $limit = $finish_cur
            else
                set $limit = *$curr_node + $buf_size
            end
            
            while $curr_ptr < $limit
                printf "[%d] = ", $idx
                p *($arg1*)$curr_ptr
                set $curr_ptr++
                set $idx++
            end
            
            set $curr_node++
            # 防止越界访问
            if $curr_node <= $finish_node
                set $curr_ptr = *$curr_node
            end
        end
        printf "Total Size: %d\n", $idx
    end
end
document pdeque
  Prints std::deque<T> correctly handling multiple memory blocks.
  Syntax: pdeque <deque> <type>
end

# Alias for compatibility
define pdequeue
    pdeque $arg0 $arg1
end

# =========================================================================
# 4. std::map / std::multimap
# Usage: pmap <map> <key_type> <val_type>
# =========================================================================
define pmap
    if $argc != 3
        help pmap
    else
        set $map = $arg0
        set $header = $map._M_t._M_impl._M_header
        set $node_count = $map._M_t._M_impl._M_node_count
        
        printf "Map Info (Nodes: %d):\n", $node_count
        
        if $node_count > 0
            set $node = $header._M_left
            set $i = 0
            
            # In-order Traversal
            while $node != &$header
                set $val_ptr = (void*)($node + 1)
                
                printf "[%d] Key = ", $i
                p *($arg1*)$val_ptr
                printf "     Val = "
                # Print value (second element of pair)
                # Hack: Print as Pair pointer to let GDB handle layout
                p *(std::pair<const $arg1, $arg2>*)$val_ptr
                
                # Successor Logic
                if $node._M_right != 0
                    set $node = $node._M_right
                    while $node._M_left != 0
                        set $node = $node._M_left
                    end
                else
                    set $parent = $node._M_parent
                    while $node == $parent._M_right
                        set $node = $parent
                        set $parent = $parent._M_parent
                    end
                    if $node._M_right != $parent
                        set $node = $parent
                    end
                end
                set $i++
            end
        end
    end
end

# =========================================================================
# 5. std::set / std::multiset
# Usage: pset <set> <type>
# =========================================================================
define pset
    if $argc != 2
        help pset
    else
        set $set = $arg0
        set $header = $set._M_t._M_impl._M_header
        set $node_count = $set._M_t._M_impl._M_node_count
        
        printf "Set Info (Nodes: %d):\n", $node_count
        
        if $node_count > 0
            set $node = $header._M_left
            set $i = 0
            
            while $node != &$header
                set $val_ptr = (void*)($node + 1)
                printf "[%d] = ", $i
                p *($arg1*)$val_ptr
                
                if $node._M_right != 0
                    set $node = $node._M_right
                    while $node._M_left != 0
                        set $node = $node._M_left
                    end
                else
                    set $parent = $node._M_parent
                    while $node == $parent._M_right
                        set $node = $parent
                        set $parent = $parent._M_parent
                    end
                    if $node._M_right != $parent
                        set $node = $parent
                    end
                end
                set $i++
            end
        end
    end
end

# =========================================================================
# 6. Adapters: Queue, Stack
# =========================================================================
define pqueue
    if $argc != 2
        help pqueue
    else
        printf "Queue (wrapping Deque):\n"
        pdeque $arg0.c $arg1
    end
end

define pstack
    if $argc != 2
        help pstack
    else
        printf "Stack (wrapping Deque):\n"
        pdeque $arg0.c $arg1
    end
end

# =========================================================================
# 7. std::string (Modern & Legacy Compat)
# =========================================================================
define pstring
    if $argc != 1
        help pstring
    else
        # Modern GCC std::string uses _M_dataplus._M_p
        p $arg0._M_dataplus._M_p
    end
end
