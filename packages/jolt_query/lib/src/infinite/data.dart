import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../foundation/query_cancellation.dart';
import '../keys/query_key.dart';
import '../query/client.dart';
import '../query/recipe.dart';

// Page values and page parameters are application-owned and may be mutable, so
// hashes are deliberately recalculated rather than cached. Deep ordered
// equality remains stable regardless of FIC's process-wide default config.
const ConfigList _infiniteDataListConfig = ConfigList(
  isDeepEquals: true,
  cacheHashCode: false,
);

/// Aligned pages and the exact parameters that produced them.
///
/// Both inputs are defensively converted to package-configured [IList] values.
/// An instance can never represent a page without its corresponding parameter.
final class InfiniteData<Page, PageParam> {
  /// Creates aligned immutable pagination data.
  factory InfiniteData({
    required Iterable<Page> pages,
    required Iterable<PageParam> pageParams,
  }) {
    final immutablePages = IList<Page>.withConfig(
      pages,
      _infiniteDataListConfig,
    );
    final immutablePageParams = IList<PageParam>.withConfig(
      pageParams,
      _infiniteDataListConfig,
    );
    if (immutablePages.length != immutablePageParams.length) {
      throw ArgumentError(
        'pages and pageParams must have equal lengths '
        '(${immutablePages.length} != ${immutablePageParams.length}).',
      );
    }
    return InfiniteData<Page, PageParam>._(
      pages: immutablePages,
      pageParams: immutablePageParams,
    );
  }

  const InfiniteData._({
    required this.pages,
    required this.pageParams,
  });

  /// Pages in fetch order.
  final IList<Page> pages;

  /// The parameter aligned with each entry in [pages].
  final IList<PageParam> pageParams;

  /// Number of aligned page/parameter pairs.
  int get length => pages.length;

  /// Whether no page has been fetched.
  bool get isEmpty => pages.isEmpty;

  /// Whether at least one page has been fetched.
  bool get isNotEmpty => pages.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfiniteData<Page, PageParam> &&
          pages == other.pages &&
          pageParams == other.pageParams;

  @override
  int get hashCode => Object.hash(
        InfiniteData,
        Page,
        PageParam,
        pages,
        pageParams,
      );

  @override
  String toString() => 'InfiniteData<$Page, $PageParam>(pages: $pages, '
      'pageParams: $pageParams)';
}

/// Direction in which a page is being resolved.
enum InfiniteDirection {
  /// Fetches after the current last page.
  forward,

  /// Fetches before the current first page.
  backward,
}

/// Capabilities supplied to one infinite-page fetch attempt.
final class InfinitePageContext<PageParam> {
  /// Creates a page context over an ordinary [QueryContext].
  const InfinitePageContext({
    required this.pageParam,
    required this.direction,
    required this.queryContext,
  });

  /// The exact current parameter, including a valid `null` value.
  final PageParam pageParam;

  /// Whether this fetch extends the beginning or end of the data.
  final InfiniteDirection direction;

  /// The underlying query attempt capabilities.
  final QueryContext queryContext;

  /// The client actually executing this page attempt.
  QueryClient get client => queryContext.client;

  /// Structural query key delegated from [queryContext].
  QueryKey get key => queryContext.key;

  /// Cooperative cancellation delegated from [queryContext].
  QueryCancellationToken get cancellationToken =>
      queryContext.cancellationToken;

  /// Immutable recipe metadata delegated from [queryContext].
  Map<String, Object?> get metadata => queryContext.metadata;
}

/// An explicit decision to continue or end pagination.
///
/// `null` is a valid value in [PageCursorMore] when [P] is nullable; it is
/// never interpreted as an end sentinel.
sealed class PageCursor<P> {
  const PageCursor._();

  /// The inference-neutral pagination end marker.
  static const PageCursor<Never> end = PageCursorEnd();

  /// Continues pagination with [pageParam], including `null` for nullable [P].
  const factory PageCursor.more(P pageParam) = PageCursorMore<P>;

  /// Whether no additional page exists in this direction.
  bool get isEnd;

  /// Whether this cursor contains another page parameter.
  bool get isMore => !isEnd;

  /// The parameter, or `null` when this is [end].
  ///
  /// Use [isMore] or pattern matching when `null` is itself a valid parameter.
  P? get pageParamOrNull;

  /// Returns the contained parameter or throws for [end].
  P requirePageParam();
}

/// The exhaustive end variant of [PageCursor].
final class PageCursorEnd extends PageCursor<Never> {
  /// Creates the canonical end variant.
  const PageCursorEnd() : super._();

  @override
  bool get isEnd => true;

  @override
  Never? get pageParamOrNull => null;

  @override
  Never requirePageParam() =>
      throw StateError('The end cursor has no page parameter.');

  @override
  bool operator ==(Object other) => other is PageCursorEnd;

  @override
  int get hashCode => Object.hash(PageCursorEnd, Never);

  @override
  String toString() => 'PageCursor.end';
}

/// The exhaustive continuation variant of [PageCursor].
final class PageCursorMore<P> extends PageCursor<P> {
  /// Creates a continuation with [pageParam].
  const PageCursorMore(this.pageParam) : super._();

  /// The next or previous page parameter, including a valid `null`.
  final P pageParam;

  @override
  bool get isEnd => false;

  @override
  P get pageParamOrNull => pageParam;

  @override
  P requirePageParam() => pageParam;

  @override
  bool operator ==(Object other) =>
      other is PageCursorMore<P> && other.pageParam == pageParam;

  @override
  int get hashCode => Object.hash(PageCursorMore, P, pageParam);

  @override
  String toString() => 'PageCursor.more($pageParam)';
}
