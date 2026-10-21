import 'package:equatable/equatable.dart';

class PRData extends Equatable {
  final double? heaviestSet;
  final double? bestRepsAtWeight;
  final int? bestRepsCount;
  final double? best1RM;
  final double? bestVolume;

  const PRData({
    this.heaviestSet,
    this.bestRepsAtWeight,
    this.bestRepsCount,
    this.best1RM,
    this.bestVolume,
  });

  const PRData.empty()
      : heaviestSet = null,
        bestRepsAtWeight = null,
        bestRepsCount = null,
        best1RM = null,
        bestVolume = null;

  @override
  List<Object?> get props =>
      [heaviestSet, bestRepsAtWeight, bestRepsCount, best1RM, bestVolume];
}
