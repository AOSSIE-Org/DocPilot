import 'package:flutter/material.dart';

import '../../core/providers/base_provider.dart';

/// Loading state indicator widget
class LoadingStateWidget extends StatelessWidget {
  final String? message;
  final bool isSmall;
  final Color? color;

  const LoadingStateWidget({
    super.key,
    this.message,
    this.isSmall = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isSmall) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? theme.primaryColor,
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? theme.primaryColor,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state display widget
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final bool isCompact;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon ?? Icons.error_outline,
              color: theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state display widget
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 64,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Data state builder for handling loading, error, and empty states
class DataStateBuilder<T> extends StatelessWidget {
  final DataState<T> state;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, String error)? errorBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final bool Function(T? data)? isEmpty;
  final VoidCallback? onRetry;

  const DataStateBuilder({
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
             const LoadingStateWidget(message: 'Loading...');
    }

    if (state.hasError && state.data == null) {
      return errorBuilder?.call(context, state.error!) ??
             ErrorStateWidget(
               message: state.error!,
               onRetry: onRetry,
             );
    }

    if (state.data == null || (isEmpty?.call(state.data) ?? false)) {
      return emptyBuilder?.call(context) ??
             const EmptyStateWidget(
               title: 'No data available',
               subtitle: 'There\'s nothing to show here yet.',
             );
    }

    return builder(context, state.data!);
  }
}

/// Paginated list widget with automatic loading
class PaginatedListView<T> extends StatefulWidget {
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

  const PaginatedListView({
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
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
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
    const threshold = 200; // Load more when 200px from bottom

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
      return const LoadingStateWidget(message: 'Loading items...');
    }

    // Handle error state with no data
    if (widget.state.hasError && widget.state.isEmpty) {
      return ErrorStateWidget(
        message: widget.state.error!,
        onRetry: widget.onRefresh,
      );
    }

    // Handle empty state
    if (widget.state.isEmpty) {
      return EmptyStateWidget(
        title: widget.emptyTitle ?? 'No items found',
        subtitle: widget.emptySubtitle ?? 'There are no items to display.',
        onAction: widget.onRefresh,
        actionLabel: 'Refresh',
      );
    }

    // Build the list
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh?.call();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        itemCount: _calculateItemCount(),
        itemBuilder: (context, index) {
          return _buildItem(context, index);
        },
      ),
    );
  }

  int _calculateItemCount() {
    int count = 0;

    if (widget.header != null) count++;
    count += widget.state.items.length;
    if (widget.separator != null && widget.state.items.length > 1) {
      count += widget.state.items.length - 1;
    }
    if (_isLoadingMore || widget.state.isLoading) count++; // Loading indicator
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
    final hasSeperator = widget.separator != null && itemCount > 1;

    if (hasSeperator) {
      final adjustedIndex = currentIndex ~/ 2;
      final isSeparator = currentIndex % 2 == 1;

      if (adjustedIndex < itemCount) {
        if (isSeparator && adjustedIndex < itemCount - 1) {
          return widget.separator!;
        }
        if (!isSeparator) {
          return widget.itemBuilder(context, widget.state.items[adjustedIndex], adjustedIndex);
        }
      }
      currentIndex -= (itemCount * 2 - 1);
    } else {
      if (currentIndex < itemCount) {
        return widget.itemBuilder(context, widget.state.items[currentIndex], currentIndex);
      }
      currentIndex -= itemCount;
    }

    // Loading indicator
    if ((_isLoadingMore || widget.state.isLoading) && widget.state.hasMore) {
      if (currentIndex == 0) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: LoadingStateWidget(
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

/// Connection status indicator
class ConnectionStatusIndicator extends StatelessWidget {
  final ConnectionStatus status;
  final bool isCompact;
  final VoidCallback? onTap;

  const ConnectionStatusIndicator({
    super.key,
    required this.status,
    this.isCompact = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color color;
    IconData icon;
    String text;

    switch (status) {
      case ConnectionStatus.online:
        color = Colors.green;
        icon = Icons.wifi;
        text = 'Online';
        break;
      case ConnectionStatus.offline:
        color = Colors.red;
        icon = Icons.wifi_off;
        text = 'Offline';
        break;
      case ConnectionStatus.unknown:
        color = Colors.orange;
        icon = Icons.help_outline;
        text = 'Unknown';
        break;
    }

    if (isCompact) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text),
      subtitle: Text(_getStatusDescription()),
      onTap: onTap,
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

/// Sync status widget
class SyncStatusWidget extends StatelessWidget {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final int pendingSyncCount;
  final VoidCallback? onSync;

  const SyncStatusWidget({
    super.key,
    required this.isSyncing,
    this.lastSyncTime,
    this.pendingSyncCount = 0,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSyncing ? Icons.sync : Icons.sync_disabled,
                  color: isSyncing ? theme.primaryColor : theme.disabledColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sync Status',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (onSync != null && !isSyncing) ...[
                  TextButton.icon(
                    onPressed: onSync,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Sync Now'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isSyncing
                ? 'Synchronizing data...'
                : lastSyncTime != null
                  ? 'Last synced: ${_formatSyncTime(lastSyncTime!)}'
                  : 'Never synced',
              style: theme.textTheme.bodyMedium,
            ),
            if (pendingSyncCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$pendingSyncCount items pending sync',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            if (isSyncing) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ),
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