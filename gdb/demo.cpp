#include <iostream>
#include <vector>
#include <list>
#include <map>
#include <set>
#include <deque>
#include <queue>
#include <stack>
#include <string>
#include <algorithm>

// 一个典型的嵌入式传感器数据结构
struct SensorData {
    int id;
    double value;
    
    // 显式构造函数方便赋值
    SensorData(int i, double v) : id(i), value(v) {}
};

void debug_break() {
    std::cout << "Breakpoint here. Inspect containers now." << std::endl;
}

int main() {
    // ==========================================
    // 1. std::vector 测试
    // ==========================================
    std::vector<int> vec_int;
    for(int i = 0; i < 50; ++i) {
        vec_int.push_back(i * 10);
    }

    std::vector<SensorData> vec_obj;
    vec_obj.emplace_back(1, 25.5);
    vec_obj.emplace_back(2, 26.0);
    vec_obj.emplace_back(3, 24.8);

    // ==========================================
    // 2. std::list 测试 (双向链表)
    // ==========================================
    std::list<std::string> list_str;
    list_str.push_back("Embedded");
    list_str.push_back("Linux");
    list_str.push_back("Expert");

    // ==========================================
    // 3. std::deque 测试 (关键测试点：跨 Block)
    // ==========================================
    // GCC deque 默认块大小通常是 512 字节。
    // int (4 bytes) -> 每个块约 128 个元素。
    // 插入 2000 个元素将跨越约 15 个内存块。
    std::deque<int> deq_long;
    for(int i = 0; i < 2000; ++i) {
        deq_long.push_back(i);
    }

    // ==========================================
    // 4. Container Adapters (Stack/Queue)
    // ==========================================
    std::queue<int> my_queue;
    my_queue.push(100);
    my_queue.push(200);
    my_queue.push(300);

    std::stack<float> my_stack;
    my_stack.push(3.14f);
    my_stack.push(1.414f);

    // ==========================================
    // 5. Map & Multimap (红黑树)
    // ==========================================
    std::map<int, std::string> my_map;
    my_map[101] = "Error";
    my_map[200] = "OK";
    my_map[404] = "Not Found";

    std::multimap<std::string, int> my_mmap;
    my_mmap.insert({"KeyA", 1});
    my_mmap.insert({"KeyA", 2}); // 重复 Key
    my_mmap.insert({"KeyB", 3});

    // ==========================================
    // 6. Set (红黑树)
    // ==========================================
    std::set<int> my_set;
    my_set.insert(5);
    my_set.insert(1);
    my_set.insert(9);

    // ==========================================
    // 7. String (SSO vs Heap)
    // ==========================================
    std::string str_short = "Hello"; // SSO (Short String Optimization)
    // 长字符串，强制堆分配
    std::string str_long = "This is a very long string that will definitely be allocated on the heap to test the pointer logic.";

    // ==========================================
    // 这里的 debug_break 是为了让你打断点
    // ==========================================
    debug_break();

    return 0;
}
