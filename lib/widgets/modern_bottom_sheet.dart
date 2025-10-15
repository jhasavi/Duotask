import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

/// Modern bottom sheet with improved design
class ModernBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showDragHandle;
  final bool isScrollControlled;
  final double? initialChildSize;
  final double? minChildSize;
  final double? maxChildSize;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const ModernBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.showDragHandle = true,
    this.isScrollControlled = false,
    this.initialChildSize,
    this.minChildSize,
    this.maxChildSize,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surface,
        borderRadius: borderRadius ?? const BorderRadius.vertical(
          top: Radius.circular(AppConstants.largeBorderRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          if (showDragHandle) ...[
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Header
          if (title != null || actions != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
              ),
              child: Row(
                children: [
                  if (title != null) ...[
                    Expanded(
                      child: Text(
                        title!,
                        style: AppTheme.titleStyle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (actions != null) ...[
                    ...actions!,
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Content
          Flexible(
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Modern bottom sheet with draggable content
class ModernDraggableBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showDragHandle;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const ModernDraggableBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.showDragHandle = true,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 0.95,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: (context, scrollController) {
        return ModernBottomSheet(
          title: title,
          actions: actions,
          showDragHandle: showDragHandle,
          backgroundColor: backgroundColor,
          borderRadius: borderRadius,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.only(
              left: AppConstants.defaultPadding,
              right: AppConstants.defaultPadding,
              bottom: AppConstants.largePadding,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Modern bottom sheet with list content
class ModernListBottomSheet extends StatelessWidget {
  final List<Widget> children;
  final String? title;
  final List<Widget>? actions;
  final bool showDragHandle;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const ModernListBottomSheet({
    super.key,
    required this.children,
    this.title,
    this.actions,
    this.showDragHandle = true,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ModernBottomSheet(
      title: title,
      actions: actions,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.only(
          left: AppConstants.defaultPadding,
          right: AppConstants.defaultPadding,
          bottom: AppConstants.largePadding,
        ),
        itemCount: children.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

/// Modern bottom sheet item
class ModernBottomSheetItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final Color? leadingIconColor;
  final Color? trailingIconColor;
  final bool isDestructive;

  const ModernBottomSheetItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailingIcon,
    this.onTap,
    this.leadingIconColor,
    this.trailingIconColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: AppConstants.smallPadding,
      ),
      leading: leadingIcon != null
          ? Icon(
              leadingIcon,
              color: leadingIconColor ?? 
                  (isDestructive ? Colors.red : colorScheme.primary),
              size: 24,
            )
          : null,
      title: Text(
        title,
        style: AppTheme.bodyStyle.copyWith(
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTheme.captionStyle,
            )
          : null,
      trailing: trailingIcon != null
          ? Icon(
              trailingIcon,
              color: trailingIconColor ?? Colors.grey.shade400,
              size: 20,
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
    );
  }
}

/// Modern bottom sheet with form content
class ModernFormBottomSheet extends StatelessWidget {
  final List<Widget> formFields;
  final String? title;
  final List<Widget>? actions;
  final Widget? submitButton;
  final bool showDragHandle;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const ModernFormBottomSheet({
    super.key,
    required this.formFields,
    this.title,
    this.actions,
    this.submitButton,
    this.showDragHandle = true,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ModernDraggableBottomSheet(
      title: title,
      actions: actions,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Form fields
          ...formFields.map((field) => Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
            child: field,
          )),
          
          // Submit button
          if (submitButton != null) ...[
            const SizedBox(height: AppConstants.largePadding),
            submitButton!,
          ],
        ],
      ),
    );
  }
}

/// Show modern bottom sheet
Future<T?> showModernBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  List<Widget>? actions,
  bool showDragHandle = true,
  bool isScrollControlled = false,
  double? initialChildSize,
  double? minChildSize,
  double? maxChildSize,
  Color? backgroundColor,
  BorderRadius? borderRadius,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (context) => ModernBottomSheet(
      title: title,
      actions: actions,
      showDragHandle: showDragHandle,
      isScrollControlled: isScrollControlled,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      child: child,
    ),
  );
}

/// Show modern list bottom sheet
Future<T?> showModernListBottomSheet<T>({
  required BuildContext context,
  required List<Widget> children,
  String? title,
  List<Widget>? actions,
  bool showDragHandle = true,
  Color? backgroundColor,
  BorderRadius? borderRadius,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (context) => ModernListBottomSheet(
      title: title,
      actions: actions,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      children: children,
    ),
  );
}

/// Show modern form bottom sheet
Future<T?> showModernFormBottomSheet<T>({
  required BuildContext context,
  required List<Widget> formFields,
  String? title,
  List<Widget>? actions,
  Widget? submitButton,
  bool showDragHandle = true,
  Color? backgroundColor,
  BorderRadius? borderRadius,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (context) => ModernFormBottomSheet(
      title: title,
      actions: actions,
      submitButton: submitButton,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      formFields: formFields,
    ),
  );
}
