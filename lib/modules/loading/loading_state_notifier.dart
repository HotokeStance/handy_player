import 'package:state_notifier/state_notifier.dart';

// 参考: https://future-architect.github.io/articles/20220329a/
/// Futureオブジェクトをラップするメソッドを提供することで、非同期処理の開始と終了時にローディングの状態を変化させている。
/// インジケータの2重表示を防止するため、内部的にはローディングが要求された回数をカウントしておき、最後の要求が終了して始めてローディング状態をfalseにしている。

class LoadingStateNotifier extends StateNotifier<bool> {
  LoadingStateNotifier() : super(false);

  int _count = 0;

  Future<T> wrap<T>(Future<T> future) async {
    _present();

    try {
      return await future;
    } finally {
      _dismiss();
    }
  }

  void _present() {
    _count = _count + 1;
    // Set the state to true.
    state = true;
  }

  void _dismiss() {
    _count = _count - 1;
    // Set the state to false only if all processing requiring a loader has been completed.
    if (_count == 0) {
      state = false;
    }
  }
}
