import 'dart:math';

class AudioFeatures {
  // Wake-word MFCC (40x44)
  static List<List<double>> extractMFCC(List<double> samples) {
    int frameSize = samples.length ~/ 44;

    List<List<double>> mfcc = List.generate(40, (_) => List.filled(44, 0.0));

    for (int frame = 0; frame < 44; frame++) {
      int start = frame * frameSize;

      for (int i = 0; i < 40; i++) {
        double sum = 0;

        int bandStart = start + (i * frameSize ~/ 40);
        int bandEnd = start + ((i + 1) * frameSize ~/ 40);

        for (int j = bandStart; j < bandEnd && j < samples.length; j++) {
          sum += samples[j] * samples[j];
        }

        mfcc[i][frame] = sqrt(sum / (bandEnd - bandStart + 1));
      }
    }

    return mfcc;
  }

  // Distress spectrogram (64x174)
  static List<List<double>> extractDistressSpectrogram(List<double> samples) {
    int rows = 64;
    int cols = 174;

    List<List<double>> spec =
        List.generate(rows, (_) => List.filled(cols, 0.0));

    int frameSize = samples.length ~/ cols;

    for (int c = 0; c < cols; c++) {
      int start = c * frameSize;

      for (int r = 0; r < rows; r++) {
        double sum = 0;

        int index = start + (r * frameSize ~/ rows);

        if (index < samples.length) {
          sum = samples[index] * samples[index];
        }

        spec[r][c] = sqrt(sum);
      }
    }

    return spec;
  }
}
