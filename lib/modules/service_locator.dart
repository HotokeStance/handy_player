import 'package:get_it/get_it.dart';
import 'package:handy_player/modules/player/audio_handler.dart';

GetIt getIt = GetIt.instance;

Future<void> initServiceLocator() async {
  getIt.registerSingleton<AudioServiceHandler>(await initAudioService());
}
