import 'package:taskpipeline/taskpipeline.dart';

/// 该示例所示范的内容:
/// 执行内部 Task, 这里我们使用的是 `leafExec` 作为 Task 的执行回调.
/// `exec` 和 `run` 的区别:
/// exec ... 开头的方法会返回返回结果的 Future
/// run ... 开头的方法会直接返回 void
void main() async {
	// 实例化 TaskPipeline 对象，它控制全部 Task 执行与结束
	TaskPipeline taskPipeline = TaskPipeline();

	// 下面分别使用两种不同的执行方式，执行两个内部 Task
	// 内部 Task 只作用于该 TaskPipeline 对象
	final result1 = await taskPipeline.execInnerTask(leafExec: () async {
		await Future.delayed(const Duration(seconds: 2));
		return 10;
	});

	final result2 = await taskPipeline.runInnerTask(leafExec: () async {
		await Future.delayed(const Duration(seconds: 2));
		return 10;
	});

	print("result1: $result1");
	// result2 的类型为 void 不能使用
	//print("result2: $result2");
}