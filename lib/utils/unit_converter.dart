const double _kgToLbs = 2.20462;

double toDisplayWeight(double kg, bool useLbs) =>
    useLbs ? kg * _kgToLbs : kg;

double fromDisplayWeight(double value, bool useLbs) =>
    useLbs ? value / _kgToLbs : value;

String unitLabel(bool useLbs) => useLbs ? 'lbs' : 'kg';

String formatWeight(double kg, bool useLbs) {
  final val = toDisplayWeight(kg, useLbs);
  return '${val.toStringAsFixed(1)} ${unitLabel(useLbs)}';
}
