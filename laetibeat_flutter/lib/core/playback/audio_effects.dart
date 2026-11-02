/// 音频效果控制接口。
///
/// 上层设置页只依赖这个接口；具体引擎支持时实现它。
abstract interface class AudioEffectsController {
  /// 开启/关闭均衡器。
  Future<void> setEqualizerEnabled(bool enabled);

  /// 设置某个频段的增益，单位 dB。
  Future<void> setEqualizerBandGain(int index, double gain);
}
