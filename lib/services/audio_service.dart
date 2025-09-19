import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _hapticEnabled = true;

  // Getters
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get hapticEnabled => _hapticEnabled;

  // Setters
  set soundEnabled(bool value) => _soundEnabled = value;
  set vibrationEnabled(bool value) => _vibrationEnabled = value;
  set hapticEnabled(bool value) => _hapticEnabled = value;

  /// Play success sound when QR code is successfully scanned
  Future<void> playSuccessSound() async {
    if (!_soundEnabled || kIsWeb) return;
    
    try {
      // For now, we'll use system sounds. In production, you'd add custom audio files
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('Error playing success sound: $e');
    }
  }

  /// Play error sound when scanning fails
  Future<void> playErrorSound() async {
    if (!_soundEnabled || kIsWeb) return;
    
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('Error playing error sound: $e');
    }
  }

  /// Play button click sound
  Future<void> playClickSound() async {
    if (!_soundEnabled || kIsWeb) return;
    
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('Error playing click sound: $e');
    }
  }

  /// Vibrate device on successful scan
  Future<void> vibrateSuccess() async {
    if (!_vibrationEnabled || kIsWeb) return;
    
    try {
      if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 200);
      }
    } catch (e) {
      debugPrint('Error vibrating device: $e');
    }
  }

  /// Vibrate device on error
  Future<void> vibrateError() async {
    if (!_vibrationEnabled || kIsWeb) return;
    
    try {
      if (await Vibration.hasVibrator() ?? false) {
        // Double vibration for error
        await Vibration.vibrate(duration: 100);
        await Future.delayed(const Duration(milliseconds: 100));
        await Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      debugPrint('Error vibrating device: $e');
    }
  }

  /// Light haptic feedback
  Future<void> lightHaptic() async {
    if (!_hapticEnabled) return;
    
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error with light haptic: $e');
    }
  }

  /// Medium haptic feedback
  Future<void> mediumHaptic() async {
    if (!_hapticEnabled) return;
    
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error with medium haptic: $e');
    }
  }

  /// Heavy haptic feedback
  Future<void> heavyHaptic() async {
    if (!_hapticEnabled) return;
    
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Error with heavy haptic: $e');
    }
  }

  /// Selection haptic feedback (for UI interactions)
  Future<void> selectionHaptic() async {
    if (!_hapticEnabled) return;
    
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Error with selection haptic: $e');
    }
  }

  /// Combined feedback for successful scan
  Future<void> successFeedback() async {
    await Future.wait([
      playSuccessSound(),
      vibrateSuccess(),
      heavyHaptic(),
    ]);
  }

  /// Combined feedback for error
  Future<void> errorFeedback() async {
    await Future.wait([
      playErrorSound(),
      vibrateError(),
      mediumHaptic(),
    ]);
  }

  /// Combined feedback for button click
  Future<void> clickFeedback() async {
    await Future.wait([
      playClickSound(),
      lightHaptic(),
    ]);
  }

  /// Check if device supports vibration
  Future<bool> hasVibrator() async {
    if (kIsWeb) return false;
    
    try {
      return await Vibration.hasVibrator() ?? false;
    } catch (e) {
      debugPrint('Error checking vibration support: $e');
      return false;
    }
  }

  /// Check if device supports custom vibration patterns
  Future<bool> hasCustomVibrationsSupport() async {
    if (kIsWeb) return false;
    
    try {
      return await Vibration.hasCustomVibrationsSupport() ?? false;
    } catch (e) {
      debugPrint('Error checking custom vibration support: $e');
      return false;
    }
  }

  /// Custom vibration pattern for special events
  Future<void> customVibrationPattern(List<int> pattern) async {
    if (!_vibrationEnabled || kIsWeb) return;
    
    try {
      if (await hasCustomVibrationsSupport()) {
        await Vibration.vibrate(pattern: pattern);
      } else {
        // Fallback to simple vibration
        await vibrateSuccess();
      }
    } catch (e) {
      debugPrint('Error with custom vibration pattern: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _audioPlayer.dispose();
  }
}