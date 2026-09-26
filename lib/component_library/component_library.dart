/// Widgets and theme shared by every feature, in the Contra wireframe style.
///
/// Widgets here take primitives and callbacks, never domain models. Anything
/// only one feature uses stays in that feature until a second one needs it.
library;

export 'src/buttons/contra_button.dart';
export 'src/buttons/contra_icon_button.dart';
export 'src/containers/contra_card.dart';
export 'src/containers/contra_list_tile.dart';
export 'src/indicators/contra_amount_badge.dart';
export 'src/indicators/contra_avatar.dart';
export 'src/indicators/contra_badge.dart';
export 'src/indicators/contra_chip.dart';
export 'src/indicators/contra_empty_state.dart';
export 'src/indicators/contra_peep.dart';
export 'src/indicators/contra_progress.dart';
export 'src/inputs/contra_segmented_control.dart';
export 'src/inputs/contra_text_field.dart';
export 'src/inputs/contra_toggle.dart';
export 'src/layout/contra_app_bar.dart';
export 'src/layout/contra_bottom_sheet.dart';
export 'src/theme/app_theme.dart';
export 'src/theme/app_theme_data.dart';
export 'src/theme/dark_app_theme_data.dart';
export 'src/theme/font_size.dart';
export 'src/theme/light_app_theme_data.dart';
export 'src/theme/spacing.dart';
export 'src/theme/tone.dart';
