import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Open Peeps drawings that ship with the app, by asset path.
///
/// Named for what they show rather than for where they are used, so a
/// feature picks a drawing the way it picks an icon.
abstract class PeepAssets {
  static const _dir = 'assets/peeps';

  /// A group of four chatting, black on white. The kit's cover image.
  static const groupChatting = '$_dir/composition-peep-1.svg';

  /// A group of three, one waving.
  static const groupWaving = '$_dir/composition-peep-2.svg';

  static const standingGrumpy = '$_dir/peep-standing-1.svg';
  static const standingPointing = '$_dir/peep-standing-4.svg';
  static const standingHat = '$_dir/peep-standing-5.svg';
  static const standingSmiling = '$_dir/peep-standing-7.svg';
  static const standingSunglasses = '$_dir/peep-standing-15.svg';
  static const standingArmsCrossed = '$_dir/peep-standing-18.svg';
  static const standingCasual = '$_dir/peep-standing-29.svg';

  static const sittingLaughing = '$_dir/peep-sit-1.svg';
  static const sittingRelaxed = '$_dir/peep-sit-2.svg';
  static const crouching = '$_dir/peep-sit-3.svg';

  /// Head-and-shoulders portraits.
  static const portraits = [
    '$_dir/peep-01.svg',
    '$_dir/peep-02.svg',
    '$_dir/peep-03.svg',
    '$_dir/peep-04.svg',
    '$_dir/peep-05.svg',
    '$_dir/peep-06.svg',
    '$_dir/peep-07.svg',
    '$_dir/peep-08.svg',
    '$_dir/peep-09.svg',
    '$_dir/peep-10.svg',
  ];

  /// Portraits in coloured circles.
  static const avatars = [
    '$_dir/avatar-1.svg',
    '$_dir/avatar-2.svg',
    '$_dir/avatar-3.svg',
    '$_dir/avatar-4.svg',
    '$_dir/avatar-5.svg',
  ];

  /// Wide scenes, for the top of a page.
  static const sceneStanding = '$_dir/big-standing-1.svg';
  static const sceneSitting = '$_dir/big-standing-2.svg';
  static const landscape1 = '$_dir/landscape-1.svg';
  static const landscape2 = '$_dir/landscape-2.svg';

  static const all = [
    groupChatting,
    groupWaving,
    standingGrumpy,
    standingPointing,
    standingHat,
    standingSmiling,
    standingSunglasses,
    standingArmsCrossed,
    standingCasual,
    sittingLaughing,
    sittingRelaxed,
    crouching,
    ...portraits,
    ...avatars,
    sceneStanding,
    sceneSitting,
    landscape1,
    landscape2,
  ];
}

/// One Open Peeps drawing, sized by height and keeping its shape.
class ContraPeep extends StatelessWidget {
  const ContraPeep({
    required this.asset,
    this.height,
    this.width,
    this.semanticLabel,
    super.key,
  });

  /// One of [PeepAssets].
  final String asset;
  final double? height;
  final double? width;

  /// Decorative unless the caller says otherwise.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    asset,
    height: height,
    width: width,
    fit: BoxFit.contain,
    semanticsLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
  );
}
