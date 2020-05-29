import 'package:taskpipeline/src/task_pipeline.dart';

/// 该示例所示范的内容:
/// Fork 一个 TaskPipeline，观察其生命周期
void main() async {
	// 实例化 TaskPipeline 对象，它控制全部 Task 执行与结束
	final masterPipeline = TaskPipeline();
  final forkPipeline = masterPipeline.fork(key: "fork");
  final resultFuture1 = forkPipeline.execInnerTask(
    key: 'test',
    leafExec: () async {
      // 等待 3 秒模拟耗时操作
      await Future.delayed(const Duration(seconds: 3)); 
      return 'hello world';
    }
  );

	// 打印结果
	print("result 1: ${await resultFuture1}");

  // 仍然是同样的任务，但是在 1 秒后会终结 master
  final resultFuture2 = forkPipeline.execInnerTask(
    key: 'test',
    leafExec: () async {
      // 等待 3 秒模拟耗时操作
      await Future.delayed(const Duration(seconds: 3)); 
      return 'hello world';
    }
  );

  // 等待 1 秒销毁 master
  await Future.delayed(const Duration(seconds: 1)); 
  masterPipeline.destroy();

  print('已销毁 Master');
	// 打印结果
	print("result 2: ${await resultFuture2}");
}
