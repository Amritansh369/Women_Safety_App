import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'sms_service.dart';

abstract class Siren {
  bool get isPlaying;
  Future<void> start();
  Future<void> stop();
}

/// Loops a loud sound on the alarm stream, so it ignores the media volume.
class LoopingAudio implements Siren {
  LoopingAudio(this._asset, {this.maximizeVolume = false});

  final String _asset;
  final bool maximizeVolume;
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  bool get isPlaying => _playing;

  @override
  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    try {
      if (maximizeVolume) await DeviceSmsGateway.maximizeAlarmVolume();
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      ));
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(_asset));
    } catch (e) {
      _playing = false;
      debugPrint('Could not play $_asset: $e');
    }
  }

  @override
  Future<void> stop() async {
    _playing = false;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Could not stop $_asset: $e');
    }
  }
}
