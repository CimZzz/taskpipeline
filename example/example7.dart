import 'package:taskpipeline/src/task_pipeline.dart';

/// 该示例所示范的内容:
/// 执行共享 Task. 在等待执行结束过程中将其终结，然后再次执行
/// 观察执行结果.
///
/// TaskPipeline 的终结并不会使共享 Task 真正被终结，只是不再监控
/// 其后续执行结果（共享 Task 只有在其执行结束后才会从全局共享 Task 池中移除）
void main() async {
	// 实例化 TaskPipeline 对象，它控制全部 Task 执行与结束
	TaskPipeline taskPipeline = TaskPipeline();

	// 执行一个共享 Task，执行过程大概需要 5 秒，我们在启动后 2 秒将其终结
	// 然后再过 1 秒重新执行
	var resultFuture1 = taskPipeline.execShareTask(key: "task", shareTask: RequestTask(const RequestData(5)));

	// 延迟 2 秒后终结
	print("延迟 2 秒后终结");
	await Future.delayed(const Duration(seconds: 2));
	taskPipeline.finishTask("task");


	// 延迟 1 秒后重新执行
	print("延迟 1 秒后重新开始执行");
	await Future.delayed(const Duration(seconds: 1));
	resultFuture1 = taskPipeline.execShareTask(key: "task", shareTask: RequestTask(const RequestData(5)));

	// 打印结果
	print("result 1: ${await resultFuture1}");
}

const UniqueKey = 1;

/// 请求数据
/// 需要提供 const 修饰的构造方法
class RequestData {
	const RequestData(this.number);
	final int number;
}

/// 声明一个共享 Task 类（需要继承 ShareTask）
/// 该共享 Task 的作用是将请求数据中的整数乘以 10 倍返回
/// 期间延迟 5 秒模拟耗时操作
class RequestTask extends ShareTask<RequestData, int> {
	RequestTask(this._data);

	final RequestData _data;

	@override
	RequestData get data => this._data;

	@override
	get uniqueKey => UniqueKey;

	@override
	Future<int> execute() async {
		await Future.delayed(const Duration(seconds: 5));
		return data.number * 10;
	}
}