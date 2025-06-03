import 'package:flutter_test/flutter_test.dart';
import 'package:whph/src/core/domain/shared/utilities/semantic_version.dart';

void main() {
  group('SemanticVersion', () {
    group('parsing', () {
      test('should parse basic semantic versions', () {
        final version = SemanticVersion.parse('1.2.3');

        expect(version.major, 1);
        expect(version.minor, 2);
        expect(version.patch, 3);
        expect(version.preRelease, isNull);
        expect(version.build, isNull);
      });

      test('should parse versions with pre-release', () {
        final version = SemanticVersion.parse('1.2.3-alpha.1');

        expect(version.major, 1);
        expect(version.minor, 2);
        expect(version.patch, 3);
        expect(version.preRelease, 'alpha.1');
        expect(version.build, isNull);
      });

      test('should parse versions with build metadata', () {
        final version = SemanticVersion.parse('1.2.3+build.1');

        expect(version.major, 1);
        expect(version.minor, 2);
        expect(version.patch, 3);
        expect(version.preRelease, isNull);
        expect(version.build, 'build.1');
      });

      test('should parse versions with both pre-release and build', () {
        final version = SemanticVersion.parse('1.2.3-alpha+build.1');

        expect(version.major, 1);
        expect(version.minor, 2);
        expect(version.patch, 3);
        expect(version.preRelease, 'alpha');
        expect(version.build, 'build.1');
      });

      test('should parse versions with v prefix', () {
        final version = SemanticVersion.parse('v1.2.3');

        expect(version.major, 1);
        expect(version.minor, 2);
        expect(version.patch, 3);
      });

      test('should pad missing parts with zeros', () {
        final version1 = SemanticVersion.parse('1');
        expect(version1.major, 1);
        expect(version1.minor, 0);
        expect(version1.patch, 0);

        final version2 = SemanticVersion.parse('1.2');
        expect(version2.major, 1);
        expect(version2.minor, 2);
        expect(version2.patch, 0);
      });

      test('should throw FormatException for invalid formats', () {
        expect(() => SemanticVersion.parse(''), throwsFormatException);
        expect(() => SemanticVersion.parse('abc'), throwsFormatException);
        expect(() => SemanticVersion.parse('1.2.abc'), throwsFormatException);
      });
    });

    group('comparison', () {
      test('should compare major versions correctly', () {
        final v1 = SemanticVersion.parse('1.0.0');
        final v2 = SemanticVersion.parse('2.0.0');

        expect(v1 < v2, true);
        expect(v2 > v1, true);
        expect(v1 >= v1, true);
        expect(v1 <= v1, true);
      });

      test('should compare minor versions correctly', () {
        final v1 = SemanticVersion.parse('1.1.0');
        final v2 = SemanticVersion.parse('1.2.0');

        expect(v1 < v2, true);
        expect(v2 > v1, true);
      });

      test('should compare patch versions correctly', () {
        final v1 = SemanticVersion.parse('1.1.1');
        final v2 = SemanticVersion.parse('1.1.2');

        expect(v1 < v2, true);
        expect(v2 > v1, true);
      });

      test('should handle pre-release versions correctly', () {
        final release = SemanticVersion.parse('1.0.0');
        final preRelease = SemanticVersion.parse('1.0.0-alpha');

        expect(preRelease < release, true);
        expect(release > preRelease, true);
      });

      test('should compare pre-release versions lexicographically', () {
        final alpha = SemanticVersion.parse('1.0.0-alpha');
        final beta = SemanticVersion.parse('1.0.0-beta');

        expect(alpha < beta, true);
        expect(beta > alpha, true);
      });

      test('should handle equality correctly', () {
        final v1 = SemanticVersion.parse('1.2.3');
        final v2 = SemanticVersion.parse('1.2.3');

        expect(v1 == v2, true);
        expect(v1.compareTo(v2), 0);
      });

      test('should ignore build metadata in comparison', () {
        final v1 = SemanticVersion.parse('1.2.3+build.1');
        final v2 = SemanticVersion.parse('1.2.3+build.2');

        expect(v1 == v2, true);
        expect(v1.compareTo(v2), 0);
      });
    });

    group('string representation', () {
      test('should return correct string representation', () {
        expect(SemanticVersion.parse('1.2.3').toString(), '1.2.3');
        expect(SemanticVersion.parse('1.2.3-alpha').toString(), '1.2.3-alpha');
        expect(SemanticVersion.parse('1.2.3+build.1').toString(), '1.2.3+build.1');
        expect(SemanticVersion.parse('1.2.3-alpha+build.1').toString(), '1.2.3-alpha+build.1');
      });

      test('should return core version without pre-release and build', () {
        final version = SemanticVersion.parse('1.2.3-alpha+build.1');
        expect(version.coreVersion, '1.2.3');
      });
    });

    group('properties', () {
      test('should correctly identify pre-release versions', () {
        final release = SemanticVersion.parse('1.0.0');
        final preRelease = SemanticVersion.parse('1.0.0-alpha');

        expect(release.isPreRelease, false);
        expect(preRelease.isPreRelease, true);
      });
    });

    group('edge cases', () {
      test('should handle real-world version formats', () {
        final versions = [
          '0.6.4',
          '1.0.0',
          '1.1.0-beta.1',
          '2.0.0-rc.1+build.123',
          'v3.0.0',
        ];

        for (final versionString in versions) {
          expect(() => SemanticVersion.parse(versionString), returnsNormally);
        }
      });

      test('should maintain consistency in comparisons', () {
        final versions = [
          '0.6.4',
          '0.6.5',
          '1.0.0-alpha',
          '1.0.0-beta',
          '1.0.0',
          '1.0.1',
          '1.1.0',
          '2.0.0',
        ];

        final parsedVersions = versions.map(SemanticVersion.parse).toList();

        // Verify ordering
        for (int i = 0; i < parsedVersions.length - 1; i++) {
          expect(parsedVersions[i] < parsedVersions[i + 1], true,
              reason: '${parsedVersions[i]} should be less than ${parsedVersions[i + 1]}');
        }
      });
    });
  });
}
