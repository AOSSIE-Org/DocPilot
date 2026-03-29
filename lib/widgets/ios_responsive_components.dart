import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';

/// Ios-style responsive layout utilities to prevent overflow issues
class ResponsiveLayout {
  /// Get safe content width that prevents overflow
  static double getContentWidth(BuildContext context) {
    final screenWidth = ScreenUtil().screenWidth;
    final sidePadding = 32.w; // 16.w on each side
    return screenWidth - sidePadding;
  }

  /// Get maximum text width for a given container
  static double getMaxTextWidth(BuildContext context, {double? containerWidth}) {
    final contentWidth = containerWidth ?? getContentWidth(context);
    return contentWidth * 0.85; // Leave 15% buffer
  }

  /// Calculate responsive grid columns
  static int getGridColumns(BuildContext context) {
    final screenWidth = ScreenUtil().screenWidth;
    if (screenWidth < 400) return 1;
    if (screenWidth < 600) return 2;
    if (screenWidth < 900) return 3;
    return 4;
  }

  /// Get Ios-standard spacing based on screen size
  static double getAdaptiveSpacing(double baseSpacing) {
    final screenWidth = ScreenUtil().screenWidth;
    if (screenWidth < 400) return baseSpacing * 0.8;
    if (screenWidth > 600) return baseSpacing * 1.2;
    return baseSpacing;
  }
}

/// Ios-style list tile that works with all Flutter versions
class IosListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const IosListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Container(
            padding: padding ?? EdgeInsets.all(16.w),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: 12.w),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null) title!,
                      if (subtitle != null) ...[
                        SizedBox(height: 4.h),
                        subtitle!,
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: 12.w),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ios-style search text field
class IosSearchTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSuffixTap;
  final TextStyle? style;
  final TextStyle? placeholderStyle;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const IosSearchTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.onSuffixTap,
    this.style,
    this.placeholderStyle,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? CupertinoColors.tertiarySystemFill,
        borderRadius: borderRadius ?? BorderRadius.circular(10.r),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: style ?? TextStyle(fontSize: 16.sp),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: placeholderStyle ?? TextStyle(
            fontSize: 16.sp,
            color: CupertinoColors.placeholderText,
          ),
          prefixIcon: Icon(
            CupertinoIcons.search,
            size: 20.sp,
            color: CupertinoColors.placeholderText,
          ),
          suffixIcon: (controller?.text.isNotEmpty ?? false)
              ? GestureDetector(
                  onTap: onSuffixTap ?? () => controller?.clear(),
                  child: Icon(
                    CupertinoIcons.clear_circled_solid,
                    size: 20.sp,
                    color: CupertinoColors.placeholderText,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: padding ?? EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
        ),
      ),
    );
  }
}

/// Responsive text widget that prevents overflow
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final double minFontSize;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final double? maxWidth;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.minFontSize = 12,
    this.textAlign,
    this.overflow,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? ResponsiveLayout.getContentWidth(context),
      ),
      child: AutoSizeText(
        text,
        style: style,
        maxLines: maxLines,
        minFontSize: minFontSize,
        textAlign: textAlign,
        overflow: overflow ?? TextOverflow.ellipsis,
      ),
    );
  }
}

/// Ios-style card container
class IosCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const IosCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 4.h,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? CupertinoColors.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(borderRadius ?? 10.r),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: CupertinoColors.systemGrey4.withValues(alpha: 0.3),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Container(
        padding: padding ?? EdgeInsets.all(16.w),
        child: child,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Ios-style button with perfect responsive design
class IosButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final Widget? icon;
  final bool isLoading;

  const IosButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.fontWeight,
    this.padding,
    this.borderRadius,
    this.width,
    this.height,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height ?? 50.h,
      child: CupertinoButton(
        onPressed: isLoading ? null : onPressed,
        color: backgroundColor ?? CupertinoColors.activeBlue,
        borderRadius: borderRadius ?? BorderRadius.circular(10.r),
        padding: padding ?? EdgeInsets.symmetric(
          horizontal: 20.w,
          vertical: 12.h,
        ),
        child: isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: const CupertinoActivityIndicator(color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    SizedBox(width: 8.w),
                  ],
                  Flexible(
                    child: ResponsiveText(
                      text,
                      style: TextStyle(
                        fontSize: fontSize ?? 17.sp,
                        fontWeight: fontWeight ?? FontWeight.w600,
                        color: textColor ?? Colors.white,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Ios-style section with header and content
class IosSection extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  const IosSection({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.margin,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 8.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveText(
                    title!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: CupertinoColors.secondaryLabel,
                      letterSpacing: -0.08,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 4.h),
                    ResponsiveText(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: CupertinoColors.tertiaryLabel,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
          ],
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: backgroundColor ?? CupertinoColors.secondarySystemGroupedBackground,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              children: children.asMap().entries.map((entry) {
                final index = entry.key;
                final child = entry.value;

                return Container(
                  decoration: BoxDecoration(
                    border: index < children.length - 1
                        ? Border(
                            bottom: BorderSide(
                              color: CupertinoColors.separator,
                              width: 0.5.h,
                            ),
                          )
                        : null,
                  ),
                  child: child,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ios-style badge
class IosBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;

  const IosBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8.w,
        vertical: 4.h,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? CupertinoColors.systemRed,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ResponsiveText(
        text,
        style: TextStyle(
          fontSize: fontSize ?? 12.sp,
          fontWeight: FontWeight.w600,
          color: textColor ?? Colors.white,
        ),
      ),
    );
  }
}

/// Ios-style divider
class IosDivider extends StatelessWidget {
  final double? height;
  final double? thickness;
  final Color? color;
  final EdgeInsets? margin;

  const IosDivider({
    super.key,
    this.height,
    this.thickness,
    this.color,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: height ?? 1.h,
      color: color ?? CupertinoColors.separator,
    );
  }
}

/// Utility functions for Ios-style interactions
class IosUtils {
  /// Show Ios-style alert dialog
  static void showAlert(
    BuildContext context, {
    required String title,
    String? message,
    List<CupertinoDialogAction>? actions,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: ResponsiveText(
          title,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: message != null
            ? ResponsiveText(
                message,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: CupertinoColors.secondaryLabel,
                ),
                maxLines: 5,
              )
            : null,
        actions: actions ?? [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: ResponsiveText(
              'OK',
              style: TextStyle(
                fontSize: 17.sp,
                color: CupertinoColors.activeBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show Ios-style action sheet
  static void showActionSheet(
    BuildContext context, {
    String? title,
    String? message,
    required List<CupertinoActionSheetAction> actions,
    CupertinoActionSheetAction? cancelButton,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: title != null
            ? ResponsiveText(
                title,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        message: message != null
            ? ResponsiveText(
                message,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: CupertinoColors.secondaryLabel,
                ),
                maxLines: 3,
                textAlign: TextAlign.center,
              )
            : null,
        actions: actions,
        cancelButton: cancelButton,
      ),
    );
  }

  /// Show Ios-style loading indicator
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(),
            if (message != null) ...[
              SizedBox(height: 16.h),
              ResponsiveText(
                message,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: CupertinoColors.secondaryLabel,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}