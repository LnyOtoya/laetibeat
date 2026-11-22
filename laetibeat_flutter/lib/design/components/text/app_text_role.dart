import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// Semantic text roles from the Material 3 type scale.
enum AppTextRole {
  displayLarge,
  displayMedium,
  displaySmall,
  headlineLarge,
  headlineMedium,
  headlineSmall,
  titleLarge,
  titleMedium,
  titleSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  labelLarge,
  labelMedium,
  labelSmall,
}

extension AppTextRoleX on AppTextRole {
  TextStyle styleOf(M3ETypeScale scale) {
    return switch (this) {
      AppTextRole.displayLarge => scale.displayLarge,
      AppTextRole.displayMedium => scale.displayMedium,
      AppTextRole.displaySmall => scale.displaySmall,
      AppTextRole.headlineLarge => scale.headlineLarge,
      AppTextRole.headlineMedium => scale.headlineMedium,
      AppTextRole.headlineSmall => scale.headlineSmall,
      AppTextRole.titleLarge => scale.titleLarge,
      AppTextRole.titleMedium => scale.titleMedium,
      AppTextRole.titleSmall => scale.titleSmall,
      AppTextRole.bodyLarge => scale.bodyLarge,
      AppTextRole.bodyMedium => scale.bodyMedium,
      AppTextRole.bodySmall => scale.bodySmall,
      AppTextRole.labelLarge => scale.labelLarge,
      AppTextRole.labelMedium => scale.labelMedium,
      AppTextRole.labelSmall => scale.labelSmall,
    };
  }
}
