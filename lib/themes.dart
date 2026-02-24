import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/utils.dart';

/// The light and dark variants of a green theme.
({FThemeData light, FThemeData dark}) get greenTheme {
  FThemeData light = FThemeData(
    colors: FColors(
      brightness: .light,
      systemOverlayStyle: .dark,
      barrier: const Color(0x33000000),
      background: const Color(0xFFF1F1F2),
      foreground: const Color(0xFF09090B),
      primary: Colors.green.shade800,
      primaryForeground: Colors.white,
      secondary: const Color(0xFFF1F1F2),
      secondaryForeground: const Color(0xFF18181B),
      muted: const Color(0xFFF4F4F5),
      mutedForeground: const Color(0xFF71717A),
      destructive: const Color(0xFFEF4444),
      destructiveForeground: const Color(0xFFFAFAFA),
      error: const Color(0xFFEF4444),
      errorForeground: const Color(0xFFFAFAFA),
      card: const Color(0xFFFFFFFF),
      border: const Color(0xFFE3E3E6),
    ),
  );
  FThemeData dark = FThemeData(
    colors: const FColors(
      brightness: .dark,
      systemOverlayStyle: .light,
      barrier: Color(0x7A000000),
      background: Color(0xFF0C0A09),
      foreground: Color(0xFFF2F2F2),
      primary: Colors.green,
      primaryForeground: Color(0xFF052E16),
      secondary: Color(0xFF27272A),
      secondaryForeground: Color(0xFFFAFAFA),
      muted: Color(0xFF262626),
      mutedForeground: Color(0xFFA1A1AA),
      destructive: Color(0xFF7F1D1D),
      destructiveForeground: Color(0xFFFEF2F2),
      error: Color(0xFF7F1D1D),
      errorForeground: Color(0xFFFEF2F2),
      card: Color(0xFF18181B),
      border: Color(0xFF27272A),
    ),
  );
  BoxShadow tileShadow = BoxShadow(
    color: Colors.grey.withValues(alpha: 0.3),
    spreadRadius: 1,
    blurRadius: 4,
    offset: const Offset(0, 2),
  );
  return (
    light: light.copyWith(
      headerStyles: _adaptHeaderStyles(
        originalPadding: light.headerStyles.base.padding,
        actionHoverColor: Colors.black54,
        bottomBorderColor: const Color(0xFFE3E3E6),
      ),
      tileGroupStyle: .delta(
        decoration: .delta(
          boxShadow: [tileShadow],
        ),
        tileStyles: _adaptTileStyles(
          backgroundColor: Colors.white,
          hoveredBackgroundColor: const Color(0xFF71717A),
        ),
      ),
      tileStyles: _adaptTileStyles(
        backgroundColor: Colors.white,
        hoveredBackgroundColor: const Color(0xFFF5F5F5),
        boxShadow: [tileShadow],
      ),
      buttonStyles: _adaptButtonStyles(
        secondaryColor: light.buttonStyles.resolve({FButtonVariant.secondary}).base.decoration.base.color,
      ),
      textFieldStyle: _adaptTextFieldStyle(
        labelTextStyle: FThemes.zinc.light.textFieldStyle.labelTextStyle,
        contentTextStyle: FThemes.zinc.light.textFieldStyle.contentTextStyle,
        fillColor: Colors.white,
      ),
      selectStyle: _adaptSelectStyle(
        labelTextStyle: FThemes.zinc.light.textFieldStyle.labelTextStyle,
      ),
      popoverMenuStyle: _adaptPopoverMenuStyle(
        hoveredBackgroundColor: Colors.black12,
        boxShadow: [tileShadow],
      ),
      style: _adaptGeneralStyle(
        shadow: [tileShadow],
      ),
    ),
    dark: dark.copyWith(
      headerStyles: _adaptHeaderStyles(
        originalPadding: dark.headerStyles.base.padding,
        actionHoverColor: Colors.white60,
      ),
      tileGroupStyle: .delta(
        tileStyles: _adaptTileStyles(),
      ),
      tileStyles: _adaptTileStyles(),
      buttonStyles: _adaptButtonStyles(
        secondaryColor: dark.buttonStyles.resolve({FButtonVariant.secondary}).base.decoration.base.color,
        highlightAmount: 0.025,
      ),
      textFieldStyle: _adaptTextFieldStyle(
        labelTextStyle: FThemes.zinc.dark.textFieldStyle.labelTextStyle,
        contentTextStyle: FThemes.zinc.dark.textFieldStyle.contentTextStyle,
        fillColor: Colors.black,
      ),
      popoverMenuStyle: _adaptPopoverMenuStyle(
        hoveredBackgroundColor: Colors.white12,
      ),
      style: _adaptGeneralStyle(),
    ),
  );
}

/// Adapts the header styles.
FVariantsDelta<FHeaderVariantConstraint, FHeaderVariant, FHeaderStyle, FHeaderStyleDelta> _adaptHeaderStyles({
  required EdgeInsetsGeometry originalPadding,
  Color? actionHoverColor,
  Color bottomBorderColor = Colors.transparent,
}) => .delta(
  [
    .match(
      {.nested},
      .delta(
        actionStyle: .delta(
          iconStyle: .delta(
            [
              .match({.hovered}, .delta(color: actionHoverColor)),
            ],
          ),
        ),
        padding: .value(
          .symmetric(
            vertical: originalPadding.vertical / 2,
            horizontal: originalPadding.horizontal / 2,
          ),
        ),
        decoration: .delta(
          border: BoxBorder.fromLTRB(
            bottom: BorderSide(color: bottomBorderColor),
          ),
        ),
      ),
    ),
  ],
);

/// Adapts the tile styles.
FVariantsDelta<FItemVariantConstraint, FItemVariant, FTileStyle, FTileStyleDelta> _adaptTileStyles({
  Color? backgroundColor,
  Color? hoveredBackgroundColor,
  List<BoxShadow>? boxShadow,
}) => .delta(
  [
    .base(
      .delta(
        focusedOutlineStyle: () => null,
        backgroundColor: .delta(
          [
            .base(null),
          ],
        ),
        decoration: .delta(
          [
            .base(
              .delta(
                color: backgroundColor,
              ),
            ),
            if (boxShadow != null)
              .all(
                .delta(
                  boxShadow: boxShadow,
                ),
              ),
          ],
        ),
        contentStyle: .delta(
          titleTextStyle: .delta(
            [
              .match(
                {.disabled},
                .delta(color: hoveredBackgroundColor),
              ),
            ],
          ),
        ),
      ),
    ),
  ],
);

/// Adapts the button styles.
FVariantsDelta<FButtonVariantConstraint, FButtonVariant, FButtonSizeStyles, FButtonSizesDelta> _adaptButtonStyles({
  Color? secondaryColor,
  double highlightAmount = 0.075,
}) => .delta(
  [
    .match(
      {.secondary},
      .delta(
        [
          .base(
            .delta(
              decoration: .delta(
                [
                  .base(
                    .delta(color: secondaryColor?.highlight(amount: highlightAmount)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    .match(
      {.ghost},
      .delta(
        [
          .all(
            .delta(
              decoration: .delta(
                [
                  .match(
                    {.hovered},
                    const .delta(color: Colors.black12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ],
);

/// Adapts the text field styles.
FTextFieldStyleDelta _adaptTextFieldStyle({
  FVariantsDelta<FFormFieldVariantConstraint, FFormFieldVariant, TextStyle, TextStyleDelta>? labelTextStyle,
  FVariantsDelta<FTextFieldVariantConstraint, FTextFieldVariant, TextStyle, TextStyleDelta>? contentTextStyle,
  Color? fillColor,
}) => .delta(
  labelTextStyle: labelTextStyle,
  contentTextStyle: contentTextStyle,
  color: .delta(
    [
      .base(fillColor),
    ],
  ),
);

/// Adapts the select styles.
FSelectStyleDelta _adaptSelectStyle({
  FVariantsDelta<FFormFieldVariantConstraint, FFormFieldVariant, TextStyle, TextStyleDelta>? labelTextStyle,
}) => .delta(
  fieldStyle: .delta(
    labelTextStyle: labelTextStyle,
  ),
);

/// Adapts the popover menu styles.
FPopoverMenuStyleDelta _adaptPopoverMenuStyle({
  Color? hoveredBackgroundColor,
  List<BoxShadow>? boxShadow,
}) => .delta(
  decoration: .delta(
    boxShadow: boxShadow,
  ),
  itemGroupStyle: .delta(
    itemStyles: .delta(
      [
        .all(
          .delta(
            decoration: .delta(
              [
                .match(
                  {.hovered},
                  .delta(color: hoveredBackgroundColor),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);

/// Adapts the general styles.
FStyleDelta _adaptGeneralStyle({
  List<BoxShadow>? shadow,
}) => .delta(
  pagePadding: const .value(.all(kBigSpace)),
  shadow: shadow,
);
