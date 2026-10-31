import 'package:equatable/equatable.dart';

/// Something the image model may have seen in a listing's photos (P.2,
/// `listings.photo_hints`): a [code] ('fallen', 'scratches', ...), the
/// photo it is likeliest in ([photo], the listing's images from 0) and how
/// much of that photo went to it ([share], 0.5-1). A hint, never part of a
/// score.
class const PhotoHint({
  required final String code,
  required final int photo,
  required final double share,
}) extends Equatable {
  @override
  List<Object?> get props => [code, photo, share];
}
