part of 'task_pipeline.dart';



abstract class BaseShareTask<T, Q> extends _Task<T, Q> {
    BaseShareTask(this._data);

	final T _data;
    @override
    T get data => this._data;

    /// 对外的 Completer
    /// 实际通知 TaskPipeline 的 Completer
    Map<dynamic, Completer<Q>> _completerMap;

    /// 对内的 Completer
    /// 用来执行实际 Task 并获得结果
    Completer<Q> _innerCompleter;

    /// 对内 Completer 的流订阅
    /// 用于将结果通知给 [_completer]，可以取消订阅
    StreamSubscription<Q> _subscription;


    /// 外部调用来停止该程序的执行
    /// 直接返回 `null` 作为执行结果
    @override
    void _stop(dynamic key) {
	    _completeData(null);
    }
    
    /// 执行 Task
    /// 第一次会实例化 Completer 并实际执行 Task 逻辑
    @override
    Future<Q> _execute(dynamic key) {
    	Completer<Q> completer;
    	if(_completerMap == null) {
		    _completerMap = Map();
	    }

	    completer = _completerMap.putIfAbsent(key, () => Completer<Q>());

	    if(_innerCompleter == null) {
		    _innerCompleter = Completer();
		    _innerCompleter.complete(execute());
		    _subscription = _innerCompleter.future.asStream().listen(
				    (recvData) {
				    _completeData(recvData);
			    },
			    onError: (error, stackTrace) {
				    _completeError(error, stackTrace);
			    }
		    );
	    }

	    return completer.future;
    }

    /// 完成 [_completer] 并返回指定数据
    /// 完成之后会回收 [_innerCompleter] 和 [_subscription]
    void _completeData(Q data) {
	    if(_completer != null && !_completer.isCompleted) {
		    _completer.complete(data);
		    _destroy();
	    }
    }

    /// 完成 [_completer] 并返回指定错误
    /// 完成之后会回收 [_innerCompleter] 和 [_subscription]
    void _completeError(dynamic error, StackTrace stackTrace) {
	    if(_completer != null && !_completer.isCompleted) {
		    _completer.completeError(error, stackTrace);
		    _destroy();
	    }
    }

    /// 回收 Task 中的 [_innerCompleter] 和 [_subscription]
    void _destroy() {
	    _innerCompleter = null;
	    if(_subscription != null) {
		    _subscription.cancel();
		    _subscription = null;
	    }
    }

    
    Future<Q> execute();
}