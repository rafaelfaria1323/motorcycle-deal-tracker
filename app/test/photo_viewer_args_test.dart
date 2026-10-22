import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/photo_viewer_args.dart';

void main() {
  group('PhotoViewerArgs', () {
    test('survives the round trip through extra', () {
      const args = PhotoViewerArgs(images: ['a.jpg', 'b.jpg'], index: 1);
      final back = PhotoViewerArgs.fromExtra(args.toExtra())!;
      expect(back.images, ['a.jpg', 'b.jpg']);
      expect(back.index, 1);
    });

    test('reads the JSON the browser history gives back', () {
      // jsonDecode gives Map<String, dynamic> and List<dynamic>.
      final extra = <String, dynamic>{
        'images': <dynamic>['a.jpg', 'b.jpg', 'c.jpg'],
        'index': 2,
      };
      final args = PhotoViewerArgs.fromExtra(extra)!;
      expect(args.images, ['a.jpg', 'b.jpg', 'c.jpg']);
      expect(args.index, 2);
    });

    test('is null without photos (a typed or reloaded address)', () {
      expect(PhotoViewerArgs.fromExtra(null), isNull);
      expect(PhotoViewerArgs.fromExtra('x'), isNull);
      expect(PhotoViewerArgs.fromExtra({'index': 0}), isNull);
      expect(PhotoViewerArgs.fromExtra({'images': <String>[]}), isNull);
      expect(
        PhotoViewerArgs.fromExtra({
          'images': ['a.jpg', 3],
        }),
        isNull,
      );
    });

    test('starts at the first photo when the index is off', () {
      for (final index in [null, -1, 2, 1.5, '1']) {
        final args = PhotoViewerArgs.fromExtra({
          'images': ['a.jpg', 'b.jpg'],
          'index': index,
        })!;
        expect(args.index, 0, reason: '$index');
      }
    });
  });
}
