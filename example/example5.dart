import 'package:taskpipeline/taskpipeline.dart';

/// 该示例所示范的内容:
/// 执行内部 Task，这里我们使用的是 `exec` 作为 Task 的执行回调，
/// 通过回调中的子 `TaskPipeline` 再次执行 Task. 在执行过程中，终结
/// 根 `TaskPipeline` 的 Task，观察子 `TaskPipeline` 中的 Task 状态
void main() async {
	// 实例化 TaskPipeline 对象，它控制全部 Task 执行与结束
	TaskPipeline taskPipeline = TaskPipeline();

	// 执行一个内部 Task，因为在将来需要主动终结它，所以为其指定一个 `Key`.
	taskPipeline.runInnerTask(
		key: "task",
		exec: (childPipeline) async {
			// 使用子 `TaskPipeline` 执行多个耗时操作，并打印其返回结果
			final result1 = await childPipeline.execInnerTask(data: 1, leafMsgExec: callbackMethod);
			print("第 1 个 Task 执行完成，结果为: $result1");

			final result2 = await childPipeline.execInnerTask(data: 3, leafMsgExec: callbackMethod);
			print("第 2 个 Task 执行完成，结果为: $result2");

			final result3 = await childPipeline.execInnerTask(data: 2, leafMsgExec: callbackMethod);
			print("第 3 个 Task 执行完成，结果为: $result3");

			final result4 = await childPipeline.execInnerTask(data: 5, leafMsgExec: callbackMethod);
			print("第 4 个 Task 执行完成，结果为: $result4");

			final result5 = await childPipeline.execInnerTask(data: 1, leafMsgExec: callbackMethod);
			print("第 5 个 Task 执行完成，结果为: $result5");
		}
	);

	// 启动一个延迟 Future，在 2 秒后终结名为 "task" 的 Task
	print("2 秒后终结 \"task\"");
	Future.delayed(const Duration(seconds: 2), () {
		print("延迟时间已到，终结 \"task\"");
		taskPipeline.finishTask("task");
	});
}


Future<int> callbackMethod(int seconds) async {
	await Future.delayed(Duration(seconds: seconds));
	return seconds;
}