## 0.0.1

- 通过 `TaskPipeline`，控制全部 `Task` 的执行与结束.
- `TaskPipeline` 可以执行内部 Task，并提供 `4` 种执行回调方法:
```dart
/// 内部 Task 回调，需要消息数据
typedef MessageTaskExecutor<T, Q> = Future<Q> Function(T data, TaskPipeline childPipeline);

/// 内部 Task 回调，需要消息数据，但是不需要子 Pipeline
typedef LeafMessageTaskExecutor<T, Q> = Future<Q> Function(T data);

/// 内部 Task 回调，不需要消息数据
typedef TaskExecutor<Q> = Future<Q> Function(TaskPipeline childPipeline);

/// 内部 Task 回调，不需要消息数据，也不需要子 Pipeline
typedef LeafTaskExecutor<Q> = Future<Q> Function();

MessageTaskExecutor<T, Q> msgExec;
LeafMessageTaskExecutor<T, Q> leafMsgExec;
TaskExecutor<Q> exec;
LeafTaskExecutor<Q> leafExec;
```

以上四种执行回调同一时间只有一种可以生效.

- `TaskPipeline` 可以执行共享 Task
- `TaskPipeline` 可以终结 Task

## 0.0.2

- 执行内部 Task 时可以执行同步方法