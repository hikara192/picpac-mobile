import 'dart:math' as math;

import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  PhotoAnalysis analysis({
    double lumaMean = 0.46,
    double p1 = 0.02,
    double p99 = 0.98,
    double r = 0.5,
    double g = 0.5,
    double b = 0.5,
    double chroma = 0.15,
    double highlights = 0,
    int pixels = 1000,
  }) => PhotoAnalysis(
    lumaMean: lumaMean,
    lumaP1: p1,
    lumaP99: p99,
    meanR: r,
    meanG: g,
    meanB: b,
    chromaMean: chroma,
    highlightFraction: highlights,
    pixelCount: pixels,
  );

  group('PhotoAnalysis', () {
    test('derives luma, percentiles and grey-world gains from a histogram', () {
      final histogram = List<int>.filled(256, 0)
        ..[64] = 2
        ..[128] = 90
        ..[200] = 8;
      final stats = FrameStats(
        lumaHistogram: histogram,
        meanR: 0.6,
        meanG: 0.5,
        meanB: 0.4,
        meanChroma: 0.2,
        highlightFraction: 0.01,
        sampleCount: 100,
      );
      final result = PhotoAnalysis.of(stats);
      expect(result.lumaP1, closeTo(64 / 255, 1e-9));
      expect(result.lumaP99, closeTo(200 / 255, 1e-9));
      expect(result.lumaMean, closeTo(132.48 / 255, 1e-6));
      expect(result.greyWorldGainR, closeTo(0.5 / 0.6, 1e-9));
      expect(result.greyWorldGainB, closeTo(0.5 / 0.4, 1e-9));
      expect(result.pixelCount, 100);
    });

    test('rejects a malformed histogram instead of guessing', () {
      const broken = FrameStats(
        lumaHistogram: <int>[1, 2, 3],
        meanR: 0.5,
        meanG: 0.5,
        meanB: 0.5,
        meanChroma: 0.1,
      );
      expect(PhotoAnalysis.tryOf(broken), isNull);
      expect(() => PhotoAnalysis.of(broken), throwsArgumentError);
    });

    test('an empty histogram means "unknown", not "black"', () {
      final empty = FrameStats(
        lumaHistogram: List<int>.filled(256, 0),
        meanR: 0.5,
        meanG: 0.5,
        meanB: 0.5,
        meanChroma: 0.1,
      );
      final result = PhotoAnalysis.of(empty);
      expect(result.pixelCount, 0);
      expect(AutoEnhance.propose(result).isNeutral, isTrue);
    });

    test('pre-computed percentiles win over the histogram', () {
      final stats = FrameStats(
        lumaHistogram: List<int>.filled(256, 1),
        meanR: 0.5,
        meanG: 0.5,
        meanB: 0.5,
        meanChroma: 0.1,
        p1: 10,
        p99: 240,
      );
      final result = PhotoAnalysis.of(stats);
      expect(result.lumaP1, closeTo(10 / 255, 1e-9));
      expect(result.lumaP99, closeTo(240 / 255, 1e-9));
    });
  });

  group('AutoEnhance.propose', () {
    test('does not touch a correctly exposed frame', () {
      final proposal = AutoEnhance.propose(analysis());
      expect(proposal.exposure, 0, reason: 'mid-grey must stay untouched');
      expect(proposal.isNeutral || proposal.temperature == 0, isTrue);
    });

    test('brightens a dark frame, within the skin-safe range', () {
      final proposal = AutoEnhance.propose(analysis(lumaMean: 0.12));
      expect(proposal.exposure, greaterThan(0.5));
      expect(proposal.exposure, lessThanOrEqualTo(1));
    });

    test('darkens a bright frame but never below −1 EV', () {
      final proposal = AutoEnhance.propose(analysis(lumaMean: 0.9));
      expect(proposal.exposure, lessThan(0));
      expect(proposal.exposure, greaterThanOrEqualTo(-1));
    });

    test('never lifts exposure on a frame with clipped highlights', () {
      final proposal = AutoEnhance.propose(
        analysis(lumaMean: 0.2, highlights: 0.1),
      );
      expect(proposal.exposure, 0);
      expect(proposal.contrast, lessThanOrEqualTo(8));
    });

    test('raises contrast on a flat frame, inside the skin-safe ceiling', () {
      final proposal = AutoEnhance.propose(analysis(p1: 0.25, p99: 0.55));
      expect(proposal.contrast, greaterThan(0));
      expect(proposal.contrast, lessThanOrEqualTo(35));
    });

    test('warms a blue cast and cools a red cast', () {
      final blue = AutoEnhance.propose(analysis(r: 0.35, g: 0.45, b: 0.62));
      expect(blue.temperature, greaterThan(0));
      final red = AutoEnhance.propose(analysis(r: 0.62, g: 0.48, b: 0.38));
      expect(red.temperature, lessThan(0));
      expect(blue.temperature.abs(), lessThanOrEqualTo(20));
      expect(red.temperature.abs(), lessThanOrEqualTo(20));
    });

    test('a neutral grey frame gets no white-balance correction', () {
      final proposal = AutoEnhance.propose(analysis(r: 0.5, g: 0.5, b: 0.5));
      expect(proposal.temperature, 0);
      expect(proposal.tint, 0);
    });

    test('lifts saturation only on a grey frame', () {
      final grey = AutoEnhance.propose(analysis(chroma: 0.05));
      final colourful = AutoEnhance.propose(analysis(chroma: 0.4));
      expect(grey.saturation, greaterThan(0));
      expect(grey.saturation, lessThanOrEqualTo(12));
      expect(colourful.saturation, 0);
    });

    test('never proposes a negative saturation or an out-of-range stack', () {
      final random = math.Random(20261112);
      for (var i = 0; i < 20; i++) {
        final frame = analysis(
          lumaMean: random.nextDouble(),
          p1: random.nextDouble() * 0.4,
          p99: 0.6 + random.nextDouble() * 0.4,
          r: random.nextDouble(),
          g: random.nextDouble(),
          b: random.nextDouble(),
          chroma: random.nextDouble(),
          highlights: random.nextDouble() * 0.3,
        );
        final proposal = AutoEnhance.propose(frame);
        expect(proposal.saturation, greaterThanOrEqualTo(0));
        expect(proposal, proposal.clamped());
        expect(proposal.exposure.abs(), lessThanOrEqualTo(1));
        expect(proposal.contrast, inInclusiveRange(-20, 35));
        expect(proposal.temperature.abs(), lessThanOrEqualTo(20));
        expect(proposal.tint.abs(), lessThanOrEqualTo(15));
      }
    });

    test('is deterministic on 20 different frames', () {
      final random = math.Random(4711);
      for (var i = 0; i < 20; i++) {
        final frame = analysis(
          lumaMean: random.nextDouble(),
          p1: random.nextDouble() * 0.5,
          p99: 0.5 + random.nextDouble() * 0.5,
          r: random.nextDouble(),
          g: random.nextDouble(),
          b: random.nextDouble(),
          chroma: random.nextDouble(),
          highlights: random.nextDouble() * 0.2,
        );
        final first = AutoEnhance.propose(frame);
        final second = AutoEnhance.propose(frame);
        expect(second.toJson(), first.toJson());
        expect(second, first);
      }
    });

    test('subtracts the look already applied to the photo', () {
      final plain = AutoEnhance.propose(analysis(r: 0.35, g: 0.45, b: 0.62));
      final withLook = AutoEnhance.propose(
        analysis(r: 0.35, g: 0.45, b: 0.62),
        lookId: 'warm',
      );
      expect(withLook.temperature, lessThan(plain.temperature));
      final unknown = AutoEnhance.propose(
        analysis(r: 0.35, g: 0.45, b: 0.62),
        lookId: 'from-the-future',
      );
      expect(unknown.temperature, plain.temperature);
    });

    test('proposes the same document for the same photo twice', () {
      final document = tenPhotoProject();
      final command = CompositeCommand(<DesignCommand>[
        for (final asset in document.assets)
          SetPhotoAdjustment(
            photoId: asset.id,
            field: PhotoAdjustmentField.exposure,
            value: AutoEnhance.propose(analysis(lumaMean: 0.2)).exposure,
          ),
      ]);
      final first = command.apply(document);
      final second = command.apply(document);
      expect(second.toJson(), first.toJson());
    });
  });
}
