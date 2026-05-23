import 'package:music_room/core/widgets/responsive_layout.dart';

class ProfileLayout {
  const ProfileLayout(this.screenSize);

  final ScreenSize screenSize;

  bool get isCompact => screenSize == ScreenSize.compact;

  double get horizontalPadding => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 32,
  };

  double get verticalPadding => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 28,
  };

  double get contentMaxWidth => switch (screenSize) {
    ScreenSize.compact => double.infinity,
    ScreenSize.medium => 980,
    ScreenSize.expanded => 1240,
  };

  double get headerSpacing => switch (screenSize) {
    ScreenSize.compact => 20,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 28,
  };

  double get sectionGap => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 20,
    ScreenSize.expanded => 24,
  };

  double get fieldGap => switch (screenSize) {
    ScreenSize.compact => 12,
    ScreenSize.medium => 14,
    ScreenSize.expanded => 16,
  };

  double get columnsGap => switch (screenSize) {
    ScreenSize.compact => 0,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 32,
  };

  double get actionGap => switch (screenSize) {
    ScreenSize.compact => 12,
    ScreenSize.medium => 14,
    ScreenSize.expanded => 16,
  };

  double get sectionLabelGap => switch (screenSize) {
    ScreenSize.compact => 10,
    ScreenSize.medium => 12,
    ScreenSize.expanded => 12,
  };

  double get themeOptionGap => switch (screenSize) {
    ScreenSize.compact => 10,
    ScreenSize.medium => 12,
    ScreenSize.expanded => 12,
  };

  double get genreSpacing => switch (screenSize) {
    ScreenSize.compact => 10,
    ScreenSize.medium => 12,
    ScreenSize.expanded => 14,
  };

  double get genreRunSpacing => switch (screenSize) {
    ScreenSize.compact => 10,
    ScreenSize.medium => 12,
    ScreenSize.expanded => 14,
  };

  double get titleFontSize => switch (screenSize) {
    ScreenSize.compact => 28,
    ScreenSize.medium => 32,
    ScreenSize.expanded => 36,
  };

  double get welcomeSpacing => switch (screenSize) {
    ScreenSize.compact => 8,
    ScreenSize.medium => 10,
    ScreenSize.expanded => 12,
  };

  double get welcomeFontSize => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 17,
    ScreenSize.expanded => 18,
  };

  double get cardPadding => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 18,
    ScreenSize.expanded => 20,
  };

  double get cardRadius => switch (screenSize) {
    ScreenSize.compact => 20,
    ScreenSize.medium => 20,
    ScreenSize.expanded => 22,
  };

  double get cardInnerGap => switch (screenSize) {
    ScreenSize.compact => 12,
    ScreenSize.medium => 14,
    ScreenSize.expanded => 16,
  };

  double get cardCopyGap => switch (screenSize) {
    ScreenSize.compact => 4,
    ScreenSize.medium => 4,
    ScreenSize.expanded => 6,
  };

  double get bodyFontSize => switch (screenSize) {
    ScreenSize.compact => 14,
    ScreenSize.medium => 15,
    ScreenSize.expanded => 15,
  };

  double get sectionTitleFontSize => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 16,
    ScreenSize.expanded => 17,
  };

  double get avatarRadius => switch (screenSize) {
    ScreenSize.compact => 28,
    ScreenSize.medium => 30,
    ScreenSize.expanded => 32,
  };

  double get avatarIconSize => switch (screenSize) {
    ScreenSize.compact => 24,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 26,
  };

  double get avatarLoaderSize => switch (screenSize) {
    ScreenSize.compact => 20,
    ScreenSize.medium => 22,
    ScreenSize.expanded => 22,
  };

  double get chevronSize => switch (screenSize) {
    ScreenSize.compact => 22,
    ScreenSize.medium => 22,
    ScreenSize.expanded => 24,
  };

  double get actionsMaxWidth => switch (screenSize) {
    ScreenSize.compact => double.infinity,
    ScreenSize.medium => 520,
    ScreenSize.expanded => 560,
  };
}
