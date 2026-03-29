import 'dart:async';
import 'package:flutter/foundation.dart';

/// Base state for providers with loading states
abstract class BaseState {
  final bool isLoading;
  final String? error;
  final DateTime lastUpdated;

  BaseState({
    this.isLoading = false,
    this.error,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.fromMicrosecondsSinceEpoch(0);

  bool get hasError => error != null;
  bool get isIdle => !isLoading && !hasError;
}

/// Loading state wrapper for any data type
class DataState<T> extends BaseState {
  final T? data;

  DataState({
    this.data,
    super.isLoading = false,
    super.error,
    super.lastUpdated,
  });

  DataState<T> copyWith({
    T? data,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return DataState<T>(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  DataState<T> loading() {
    return copyWith(isLoading: true, error: null);
  }

  DataState<T> success(T data) {
    return copyWith(
      data: data,
      isLoading: false,
      error: null,
      lastUpdated: DateTime.now(),
    );
  }

  DataState<T> failure(String error) {
    return copyWith(
      isLoading: false,
      error: error,
    );
  }

  @override
  String toString() {
    return 'DataState(data: $data, isLoading: $isLoading, error: $error)';
  }
}

/// Base provider with common functionality
abstract class BaseDataProvider<T> extends ChangeNotifier {
  DataState<T> _state = DataState();
  Timer? _refreshTimer;
  StreamSubscription? _dataSubscription;

  DataState<T> get state => _state;
  T? get data => _state.data;
  bool get isLoading => _state.isLoading;
  String? get error => _state.error;
  bool get hasData => _state.data != null;
  bool get hasError => _state.hasError;

  /// Update state and notify listeners
  void setState(DataState<T> newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// Set loading state
  void setLoading() {
    setState(_state.loading());
  }

  /// Set success state with data
  void setSuccess(T data) {
    setState(_state.success(data));
  }

  /// Set error state
  void setError(String error) {
    setState(_state.failure(error));
    if (kDebugMode) {
      debugPrint('[${runtimeType}] Error: $error');
    }
  }

  /// Clear any existing error
  void clearError() {
    if (_state.hasError) {
      setState(_state.copyWith(error: null));
    }
  }

  /// Refresh data (to be implemented by subclasses)
  Future<void> refresh();

  /// Start auto-refresh with specified interval
  void startAutoRefresh(Duration interval) {
    stopAutoRefresh();
    _refreshTimer = Timer.periodic(interval, (_) => refresh());
  }

  /// Stop auto-refresh
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Watch data stream (to be implemented by subclasses)
  void watchData();

  /// Stop watching data stream
  void stopWatching() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    stopWatching();
    super.dispose();
  }
}

/// Paginated data state
class PaginatedState<T> extends BaseState {
  final List<T> items;
  final bool hasMore;
  final int currentPage;
  final int pageSize;

  PaginatedState({
    this.items = const [],
    this.hasMore = true,
    this.currentPage = 0,
    this.pageSize = 20,
    super.isLoading = false,
    super.error,
    super.lastUpdated,
  });

  PaginatedState<T> copyWith({
    List<T>? items,
    bool? hasMore,
    int? currentPage,
    int? pageSize,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  PaginatedState<T> loading({bool append = false}) {
    return copyWith(
      isLoading: true,
      error: null,
      items: append ? items : null,
    );
  }

  PaginatedState<T> success({
    required List<T> newItems,
    required bool hasMore,
    bool append = false,
  }) {
    return copyWith(
      items: append ? [...items, ...newItems] : newItems,
      hasMore: hasMore,
      currentPage: append ? currentPage + 1 : 1,
      isLoading: false,
      error: null,
      lastUpdated: DateTime.now(),
    );
  }

  PaginatedState<T> failure(String error) {
    return copyWith(
      isLoading: false,
      error: error,
    );
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get length => items.length;
}

/// Base paginated provider
abstract class BasePaginatedProvider<T> extends ChangeNotifier {
  PaginatedState<T> _state = PaginatedState();
  Timer? _refreshTimer;
  StreamSubscription? _dataSubscription;

  PaginatedState<T> get state => _state;
  List<T> get items => _state.items;
  bool get isLoading => _state.isLoading;
  bool get hasMore => _state.hasMore;
  bool get isEmpty => _state.isEmpty;
  bool get isNotEmpty => _state.isNotEmpty;
  String? get error => _state.error;

  void setState(PaginatedState<T> newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  void setLoading({bool append = false}) {
    setState(_state.loading(append: append));
  }

  void setSuccess({
    required List<T> items,
    required bool hasMore,
    bool append = false,
  }) {
    setState(_state.success(
      newItems: items,
      hasMore: hasMore,
      append: append,
    ));
  }

  void setError(String error) {
    setState(_state.failure(error));
  }

  /// Load first page
  Future<void> loadData();

  /// Load next page
  Future<void> loadMore();

  /// Refresh all data
  Future<void> refresh();

  /// Add item to beginning of list
  void prependItem(T item) {
    setState(_state.copyWith(
      items: [item, ...items],
      lastUpdated: DateTime.now(),
    ));
  }

  /// Add item to end of list
  void appendItem(T item) {
    setState(_state.copyWith(
      items: [...items, item],
      lastUpdated: DateTime.now(),
    ));
  }

  /// Update item in list
  void updateItem(T item, bool Function(T) predicate) {
    final index = items.indexWhere(predicate);
    if (index != -1) {
      final newItems = List<T>.from(items);
      newItems[index] = item;
      setState(_state.copyWith(
        items: newItems,
        lastUpdated: DateTime.now(),
      ));
    }
  }

  /// Remove item from list
  void removeItem(bool Function(T) predicate) {
    final newItems = items.where((item) => !predicate(item)).toList();
    setState(_state.copyWith(
      items: newItems,
      lastUpdated: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }
}

/// Connection state provider
enum ConnectionStatus { online, offline, unknown }

class ConnectionState extends BaseState {
  final ConnectionStatus status;
  final DateTime? lastOnlineAt;

  ConnectionState({
    this.status = ConnectionStatus.unknown,
    this.lastOnlineAt,
    super.isLoading = false,
    super.error,
    super.lastUpdated,
  });

  bool get isOnline => status == ConnectionStatus.online;
  bool get isOffline => status == ConnectionStatus.offline;

  ConnectionState copyWith({
    ConnectionStatus? status,
    DateTime? lastOnlineAt,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      lastOnlineAt: lastOnlineAt ?? this.lastOnlineAt,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}