/// Named artwork dimensions. Pages choose a semantic size instead of a raw
/// number so the whole app can be rescaled consistently.
enum AppArtworkSize {
  xxs(24),
  xs(32),
  sm(40),
  md(48),
  lg(56),
  xl(72),
  xxl(96),
  tile(160),
  feature(200),
  hero(280);

  const AppArtworkSize(this.value);

  /// Logical-pixel edge length (artwork is square).
  final double value;
}
