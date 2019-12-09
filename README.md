## 什么是 Task Pipeline ?

在这里，每一个可拆分的执行块都可以看做是 `Task`. 将很多个 `Task` 集中统一执行的过程抽象为管线，命名为 `TaskPipeline`.

使用 `TaskPipeline`，你可以很简单地写出高复杂度的任务流程，大大增加程序的可读性.

## 开始使用

当前最新版本为: 0.0.3

在 "pubspec.yaml" 文件中加入
```yaml
dependencies:
  taskpipeline: ^0.0.3
```

github
```text
https://github.com/CimZzz/taskpipeline
```

--- 

首先，我们需要创建一个名为 `TaskPipeline` 对象:

```dart
/// 本库中核心类，所有的用例都是围绕其展开的
TaskPipeline pipeline = TaskPipeline();
```

然后通过 `pipeline` 对象，我们可以执行一个 Task:

```dart
/// 很简单的一个 Task
/// 其作用是返回了一个整数 10
pipeline.execInnerTask(leafExec: () async {
  return 10;
})
```

这样，我们就完成了一次简单的 Task 任务.

另外，我们可以给想要执行的 Task 提供一个 `key`，这样我们就可以通过 `key` 来主动将其终结（终结过程是瞬间同步的）

```dart
/// 还是之前的任务，只是添加了 2 秒延时
pipeline.execInnerTask(key: "task", leafExec: () async {
  await Future.delayed(const Duration(seconds: 2));
  return 10;
})

pipeline.finishTask("task");
```

是的，只需要调用 `finishTask` + Task 的 `key`，就能直接将其终结，就是那么简单.

更多示例可以参考:

[代码示例](example/README.md)
