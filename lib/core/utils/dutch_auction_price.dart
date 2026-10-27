import 'dart:math';

double dutchAuctionPrice({
  required double startingPrice,
  required DateTime startTime,
  required DateTime currentTime,
}) {
  if (!startingPrice.isFinite || startingPrice <= 0) {
    throw ArgumentError.value(startingPrice, 'startingPrice');
  }

  final elapsedSteps = max(
    0,
    currentTime.difference(startTime).inSeconds ~/ 30,
  );
  final dropPerStep = max(1, (startingPrice * 0.03).floor());
  final floorPrice = (startingPrice / 2).floor();
  return max(
    floorPrice.toDouble(),
    startingPrice - elapsedSteps * dropPerStep,
  );
}
