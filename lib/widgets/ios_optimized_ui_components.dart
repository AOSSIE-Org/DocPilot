import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../../core/providers/base_provider.dart';
import '../theme/ios_app_theme.dart';

/// Ios-style loading state indicator widget with perfect responsive design
class IosLoadingStateWidget extends StatelessWidget {
  final String? message;
  final bool isSmall;
  final Color? color;

  const IosLoadingStateWidget({
    super.key,
    this.message,
    this.isSmall = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isSmall) {
      return SizedBox(
        width: 20.w,
        height: 20.h,
        child: CupertinoActivityIndicator(
          radius: 10.r,
          color: color ?? IosAppTheme.primaryBlue,
        ),
      );
    }

    return SafeArea(
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ScreenUtil().screenWidth * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(
                radius: 15.r,
                color: color ?? IosAppTheme.primaryBlue,
              ),
              if (message != null) ...[
                SizedBox(height: ResponsiveHelper.spacing(16)),
                AutoSizeText(
                  message!,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: IosAppTheme.systemGray,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  minFontSize: 12,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ios-style error state display widget with no overflow issues
class IosErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final bool isCompact;

  const IosErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: IosDesignConstants.standardMargin),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: IosAppTheme.systemRed.withValues(alpha: 0.1),
          border: Border.all(
            color: IosAppTheme.systemRed.withValues(alpha: 0.3),
            width: 1.w,
          ),
          borderRadius: BorderRadius.circular(IosDesignConstants.standardRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? CupertinoIcons.exclamationmark_triangle,
              color: IosAppTheme.systemRed,
              size: 18.sp,
            ),
            SizedBox(width: ResponsiveHelper.spacing(8)),
            Expanded(
              child: AutoSizeText(
                message,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: IosAppTheme.systemRed,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
                minFontSize: 10,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(width: ResponsiveHelper.spacing(8)),
              CupertinoButton(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 4.h,
                ),
                minSize: 32.h,
                onPressed: onRetry,
                color: IosAppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(6.r),
                child: AutoSizeText(
                  'Retry',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  minFontSize: 10,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return SafeArea(
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ScreenUtil().screenWidth * 0.85,
            maxHeight: ScreenUtil().screenHeight * 0.6,
          ),
          padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80.w,
                height: 80.h,
                decoration: BoxDecoration(
                  color: IosAppTheme.systemRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Icon(
                  icon ?? CupertinoIcons.exclamationmark_triangle_fill,
                  size: 40.sp,
                  color: IosAppTheme.systemRed,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(20)),
              AutoSizeText(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
                maxLines: 1,
                minFontSize: 16,
              ),
              SizedBox(height: ResponsiveHelper.spacing(12)),
              AutoSizeText(
                message,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w400,
                  color: IosAppTheme.systemGray,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                minFontSize: 12,
              ),
              if (onRetry != null) ...[
                SizedBox(height: ResponsiveHelper.spacing(24)),
                SizedBox(
                  width: double.infinity,
                  height: IosDesignConstants.buttonHeight,
                  child: CupertinoButton.filled(
                    onPressed: onRetry,
                    borderRadius: BorderRadius.circular(IosDesignConstants.standardRadius),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.refresh,
                          size: 18.sp,
                          color: Colors.white,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(8)),
                        AutoSizeText(
                          'Try Again',
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          minFontSize: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ios-style empty state display widget
class IosEmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const IosEmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ScreenUtil().screenWidth * 0.85,
            maxHeight: ScreenUtil().screenHeight * 0.6,
          ),
          padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100.w,
                height: 100.h,
                decoration: BoxDecoration(
                  color: IosAppTheme.systemGray6,
                  borderRadius: BorderRadius.circular(25.r),
                ),
                child: Icon(
                  icon ?? CupertinoIcons.doc_text,
                  size: 50.sp,
                  color: IosAppTheme.systemGray2,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(24)),
              AutoSizeText(
                title,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                minFontSize: 18,
              ),
              if (subtitle != null) ...[
                SizedBox(height: ResponsiveHelper.spacing(12)),
                AutoSizeText(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w400,
                    color: IosAppTheme.systemGray,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  minFontSize: 12,
                ),
              ],
              if (onAction != null && actionLabel != null) ...[
                SizedBox(height: ResponsiveHelper.spacing(32)),
                SizedBox(
                  width: double.infinity,
                  height: IosDesignConstants.buttonHeight,
                  child: CupertinoButton.filled(
                    onPressed: onAction,
                    borderRadius: BorderRadius.circular(IosDesignConstants.standardRadius),
                    child: AutoSizeText(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      minFontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ios-style data state builder with perfect responsive layout
class IosDataStateBuilder<T> extends StatelessWidget {
  final DataState<T> state;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, String error)? errorBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final bool Function(T? data)? isEmpty;
  final VoidCallback? onRetry;

  const IosDataStateBuilder({
    super.key,
    required this.state,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.isEmpty,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.data == null) {
      return loadingBuilder?.call(context) ??
          const IosLoadingStateWidget(message: 'Loading...');
    }

    final error = state.error;
    if (state.hasError && state.data == null && error != null) {
      return errorBuilder?.call(context, error) ??
          IosErrorStateWidget(
            message: error,
            onRetry: onRetry,
          );
    }

    if (state.data == null || (isEmpty?.call(state.data) ?? false)) {
      return emptyBuilder?.call(context) ??
          const IosEmptyStateWidget(
            title: 'No data available',
            subtitle: 'There\'s nothing to show here yet.',
          );
    }

    final data = state.data;
    if (data == null) {
      return const IosEmptyStateWidget(
        title: 'No data available',
        subtitle: 'There\'s nothing to show here yet.',
      );
    }

    return builder(context, data);
  }
}

/// Ios-style paginated list with perfect scrolling performance
class IosPaginatedListView<T> extends StatefulWidget {
  final PaginatedState<T> state;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function()? onLoadMore;
  final VoidCallback? onRefresh;
  final EdgeInsets? padding;
  final Widget? separator;
  final Widget? header;
  final Widget? footer;
  final ScrollController? controller;
  final String? emptyTitle;
  final String? emptySubtitle;
  final IconData? emptyIcon;

  const IosPaginatedListView({
    super.key,
    required this.state,
    required this.itemBuilder,
    this.onLoadMore,
    this.onRefresh,
    this.padding,
    this.separator,
    this.header,
    this.footer,
    this.controller,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyIcon,
  });

  @override
  State<IosPaginatedListView<T>> createState() => _IosPaginatedListViewState<T>();
}

class _IosPaginatedListViewState<T> extends State<IosPaginatedListView<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!widget.state.hasMore || _isLoadingMore || widget.onLoadMore == null) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = 200.h; // Responsive threshold

    if (maxScroll - currentScroll <= threshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || widget.onLoadMore == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await widget.onLoadMore!();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle loading state for initial load
    if (widget.state.isLoading && widget.state.isEmpty) {
      return const IosLoadingStateWidget(message: 'Loading items...');
    }

    // Handle error state with no data
    if (widget.state.hasError && widget.state.isEmpty) {
      return IosErrorStateWidget(
        message: widget.state.error!,
        onRetry: widget.onRefresh,
      );
    }

    // Handle empty state
    if (widget.state.isEmpty) {
      return IosEmptyStateWidget(
        title: widget.emptyTitle ?? 'No items found',
        subtitle: widget.emptySubtitle ?? 'There are no items to display.',
        icon: widget.emptyIcon,
        onAction: widget.onRefresh,
        actionLabel: 'Refresh',
      );
    }

    // Build the Ios-style list
    return widget.onRefresh != null
        ? CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  widget.onRefresh?.call();
                },
              ),
              SliverPadding(
                padding: widget.padding ??
                    EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.spacing(0),
                      vertical: ResponsiveHelper.spacing(8),
                    ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildItem(context, index),
                    childCount: _calculateItemCount(),
                  ),
                ),
              ),
            ],
          )
        : ListView.builder(
            controller: _scrollController,
            padding: widget.padding ??
                EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.spacing(0),
                  vertical: ResponsiveHelper.spacing(8),
                ),
            itemCount: _calculateItemCount(),
            itemBuilder: (context, index) => _buildItem(context, index),
          );
  }

  int _calculateItemCount() {
    int count = 0;

    if (widget.header != null) count++;
    count += widget.state.items.length;
    if (widget.separator != null && widget.state.items.length > 1) {
      count += widget.state.items.length - 1;
    }
    if (_isLoadingMore || (widget.state.isLoading && widget.state.hasMore)) count++;
    if (widget.footer != null) count++;

    return count;
  }

  Widget _buildItem(BuildContext context, int index) {
    int currentIndex = index;

    // Header
    if (widget.header != null) {
      if (currentIndex == 0) return widget.header!;
      currentIndex--;
    }

    // Items and separators
    final itemCount = widget.state.items.length;
    final hasSeparator = widget.separator != null && itemCount > 1;

    if (hasSeparator) {
      final adjustedIndex = currentIndex ~/ 2;
      final isSeparator = currentIndex % 2 == 1;

      if (adjustedIndex < itemCount) {
        if (isSeparator && adjustedIndex < itemCount - 1) {
          return widget.separator!;
        }
        if (!isSeparator) {
          return widget.itemBuilder(
            context,
            widget.state.items[adjustedIndex],
            adjustedIndex,
          );
        }
      }
      currentIndex -= (itemCount * 2 - 1);
    } else {
      if (currentIndex < itemCount) {
        return widget.itemBuilder(
          context,
          widget.state.items[currentIndex],
          currentIndex,
        );
      }
      currentIndex -= itemCount;
    }

    // Loading indicator
    if ((_isLoadingMore || (widget.state.isLoading && widget.state.hasMore)) &&
        widget.state.hasMore) {
      if (currentIndex == 0) {
        return Container(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
          alignment: Alignment.center,
          child: const IosLoadingStateWidget(
            message: 'Loading more...',
            isSmall: true,
          ),
        );
      }
      currentIndex--;
    }

    // Footer
    if (widget.footer != null) {
      if (currentIndex == 0) return widget.footer!;
    }

    return const SizedBox.shrink();
  }
}

/// Ios-style connection status indicator with perfect responsive design
class IosConnectionStatusIndicator extends StatelessWidget {
  final ConnectionStatus status;
  final bool isCompact;
  final VoidCallback? onTap;

  const IosConnectionStatusIndicator({
    super.key,
    required this.status,
    this.isCompact = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case ConnectionStatus.online:
        color = IosAppTheme.systemGreen;
        icon = CupertinoIcons.wifi;
        text = 'Online';
        break;
      case ConnectionStatus.offline:
        color = IosAppTheme.systemRed;
        icon = CupertinoIcons.wifi_slash;
        text = 'Offline';
        break;
      case ConnectionStatus.unknown:
        color = IosAppTheme.systemOrange;
        icon = CupertinoIcons.question_circle;
        text = 'Unknown';
        break;
    }

    if (isCompact) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.w),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12.sp, color: color),
              SizedBox(width: ResponsiveHelper.spacing(4)),
              AutoSizeText(
                text,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                minFontSize: 9,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: IosDesignConstants.standardMargin),
      child: CupertinoListTile(
        leading: Icon(icon, color: color, size: 24.sp),
        title: AutoSizeText(
          text,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          minFontSize: 14,
        ),
        subtitle: AutoSizeText(
          _getStatusDescription(),
          style: TextStyle(
            fontSize: 15.sp,
            color: IosAppTheme.systemGray,
          ),
          maxLines: 2,
          minFontSize: 12,
        ),
        onTap: onTap,
      ),
    );
  }

  String _getStatusDescription() {
    switch (status) {
      case ConnectionStatus.online:
        return 'Connected to the internet';
      case ConnectionStatus.offline:
        return 'No internet connection';
      case ConnectionStatus.unknown:
        return 'Connection status unknown';
    }
  }
}

/// Ios-style sync status widget with perfect layout
class IosSyncStatusWidget extends StatelessWidget {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final int pendingSyncCount;
  final VoidCallback? onSync;

  const IosSyncStatusWidget({
    super.key,
    required this.isSyncing,
    this.lastSyncTime,
    this.pendingSyncCount = 0,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: IosDesignConstants.standardMargin,
        vertical: ResponsiveHelper.spacing(8),
      ),
      padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(IosDesignConstants.standardRadius),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey4.withValues(alpha: 0.3),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: (isSyncing ? IosAppTheme.primaryBlue : IosAppTheme.systemGray3)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(
                  isSyncing ? CupertinoIcons.refresh : CupertinoIcons.checkmark_circle,
                  color: isSyncing ? IosAppTheme.primaryBlue : IosAppTheme.systemGray,
                  size: 16.sp,
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(12)),
              Expanded(
                child: AutoSizeText(
                  'Sync Status',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                  maxLines: 1,
                  minFontSize: 14,
                ),
              ),
              if (onSync != null && !isSyncing) ...[
                CupertinoButton(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  minSize: 32.h,
                  onPressed: onSync,
                  color: IosAppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(6.r),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.refresh,
                        size: 14.sp,
                        color: Colors.white,
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(4)),
                      AutoSizeText(
                        'Sync',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        minFontSize: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(12)),
          AutoSizeText(
            isSyncing
                ? 'Synchronizing data...'
                : lastSyncTime != null
                    ? 'Last synced: ${_formatSyncTime(lastSyncTime!)}'
                    : 'Never synced',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
              color: CupertinoColors.secondaryLabel,
            ),
            maxLines: 2,
            minFontSize: 12,
          ),
          if (pendingSyncCount > 0) ...[
            SizedBox(height: ResponsiveHelper.spacing(4)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8.w,
                vertical: 4.h,
              ),
              decoration: BoxDecoration(
                color: IosAppTheme.systemOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: AutoSizeText(
                '$pendingSyncCount items pending sync',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: IosAppTheme.systemOrange,
                ),
                maxLines: 1,
                minFontSize: 10,
              ),
            ),
          ],
          if (isSyncing) ...[
            SizedBox(height: ResponsiveHelper.spacing(12)),
            ClipRRect(
              borderRadius: BorderRadius.circular(2.r),
              child: LinearProgressIndicator(
                backgroundColor: IosAppTheme.systemGray5,
                valueColor: AlwaysStoppedAnimation<Color>(IosAppTheme.primaryBlue),
                minHeight: 4.h,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Ios-style section header with perfect typography
class IosSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final EdgeInsets? padding;

  const IosSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: IosDesignConstants.standardMargin,
            vertical: ResponsiveHelper.spacing(12),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AutoSizeText(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: IosAppTheme.systemGray,
              letterSpacing: -0.08,
            ),
            maxLines: 1,
            minFontSize: 10,
          ),
          if (subtitle != null) ...[
            SizedBox(height: ResponsiveHelper.spacing(4)),
            AutoSizeText(
              subtitle!,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: IosAppTheme.systemGray2,
              ),
              maxLines: 2,
              minFontSize: 10,
            ),
          ],
        ],
      ),
    );
  }
}