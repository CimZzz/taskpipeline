

void main() async {
//	final pipeline = TaskPipeline();
	final future = Future.delayed(const Duration(seconds: 2), () {
		throw 1;
	});
	future.asStream().listen((data) { print("recv1"); });
	future.asStream().listen(
		(data) {
			print("recv2");
		},
		onError: (error, StackTrace st) {
			print("error: $error, st: $st");
		}
	);
//	print(pipeline._taskContainerMap?.length ?? 0);
}