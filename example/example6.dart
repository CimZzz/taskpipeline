import 'package:taskpipeline/src/task_pipeline.dart';

/// 该示例所示范的内容:
/// 执行共享 Task.
/// 每个共享 Task 都会有一个 `unique key`，作为唯一标识.
/// 如果当前存在请求执行的共享 Task（比较 unique key），
/// 并且请求的执行的数据也相同（由执行数据判断，所以执行数据需要支持 `const` 构造方法），
/// 则会使用正在执行的共享 Task 而不是重新执行一个新的 Task.
void main() async {
	// 实例化 TaskPipeline 对象，它控制全部 Task 执行与结束
	TaskPipeline taskPipeline = TaskPipeline();

	// 执行 2 个共享 Task，分别使用不同的请求数据
	final resultFuture1 = taskPipeline.execShareTask(shareTask: RequestTask(const RequestData(5)));
	final resultFuture2 = taskPipeline.execShareTask(shareTask: RequestTask(const RequestData(7)));

	// 延迟 2 秒后，再次执行 2 个共享 Task
	// 一个与第一个参数完全相同
	// 另外一个与第二个参数相同，但是不使用 const 构造方法
	await Future.delayed(const Duration(seconds: 2));

	final resultFuture3 = taskPipeline.execShareTask(shareTask: RequestTask(const RequestData(5)));
	final resultFuture4 = taskPipeline.execShareTask(shareTask: RequestTask(RequestData(7)));

	// 为了同时展示，使用 then 来观察结果
	var _ = resultFuture1.then((data) {
		print("result1: $data");
	});
	_ = resultFuture2.then((data) {
		print("result2: $data");
	});
	_ = resultFuture3.then((data) {
		print("result3: $data");
	});
	_ = resultFuture4.then((data) {
		print("result4: $data");
	});
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