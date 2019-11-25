import 'package:taskpipeline/taskpipeline.dart';

/// 该示例所示范的内容:
/// 执行内部 Task, 在等待执行结束过程中将其终结, 观察后续状态
/// 在 Task 被终结的瞬间，将会直接将 `null` 作为执行结果返回，但
/// 执行回调仍在执行，所以这就需要在执行回调中尽量使用内部变量而不是外部变量，
/// 否则可能会引起比较隐晦不易发现的问题.
void main() async {
	// 实例化 TaskPipeline 对象，它控制全部 Task 执行与结束
	TaskPipeline taskPipeline = TaskPipeline();

	// 执行一个内部 Task，获取其结果
	// * 这里因为添加了 `await`，所以获取的不是 `Future` 而是最终结果
	final result1 = await taskPipeline.execInnerTask(leafExec: callbackMethod);

	// 打印结果
	print("result1: $result1");


	// 执行一个内部 Task，因为在将来需要主动终结它，所以为其指定一个 `Key`.
	// 使用的执行回调与上一个 Task 使用的相同，如果正常执行的话，返回结果应该一致
	// * 这里没有添加 `await`，所以获得是一个 `Future`.
	final resultFuture2 = taskPipeline.execInnerTask(key: "task", leafExec: callbackMethod);

	// 启动一个延迟 Future，在 2 秒后终结名为 "task" 的 Task
	print("2 秒后终结 \"task\"");
	Future.delayed(const Duration(seconds: 2), () {
		print("延迟时间已到，终结 \"task\"");
		taskPipeline.finishTask("task");
	});

	// 打印被终结 Task 最终返回结果
	print("result2: ${await resultFuture2}");
}


Future<int> callbackMethod() async {
	// 模拟耗时操作，等待 3 秒
	await Future.delayed(const Duration(seconds: 3));
	print("模拟耗时操作完成");
	return 1;
}