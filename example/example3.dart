import 'package:taskpipeline/taskpipeline.dart';

/// 该示例所示范的内容:
/// 执行内部 Task, 这里我们使用的是 `leafMsgExec` 作为 Task 的执行回调
/// 我们可以将方法作为回调参数交给 TaskPipeline 执行
void main() async {
	// 实例化 TaskPipeline 对象，它控制全部 Task 执行与结束
	TaskPipeline taskPipeline = TaskPipeline();

	// 执行第一个 Message Task，使用闭包执行 Task
	taskPipeline.runInnerTask(data: "first: hello world", leafMsgExec: (data) async {
		print(data);
	});

	// 执行第二个 Message Task，使用方法执行 Task
	taskPipeline.runInnerTask(data: "second: hello world", leafMsgExec: callbackMethod);

	// 执行第三个 Message Task，与第一个不同的是，这次我们将获取 Task 执行完成后的返回结果
	// 闭包逻辑很简单，将传递整数乘以 10
	// * 如果不加 `await` 关键字，那么返回的是一个 `Future` 而不是我们想要的结果
	// * 比如下列 `resultFuture3` 和 `resultFuture4` 就是一个 `Future`
	final resultFuture3 = taskPipeline.execInnerTask(data: 1, leafMsgExec: (data) async {
		return data * 10;
	});

	// 执行第四个 Message Task，使用方法执行 Task
	final resultFuture4 = taskPipeline.execInnerTask(data: 2, leafMsgExec: callbackMethod2);

	// 打印执行结果
	print("result 3: ${await resultFuture3}");
	print("result 4: ${await resultFuture4}");

}

Future<void> callbackMethod(String data) async {
	print(data);
}

Future<int> callbackMethod2(int data) async {
	return data * 10;
}