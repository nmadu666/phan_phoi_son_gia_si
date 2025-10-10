/// A generic class to hold paginated data from an API response.
class PaginatedResult<T> {
  /// The list of items for the current page.
  final List<T> data;

  /// The total number of items available across all pages.
  final int total;

  /// The starting index of the items on the current page.
  final int currentItem;

  /// The number of items requested per page.
  final int pageSize;

  PaginatedResult({
    required this.data,
    required this.total,
    required this.currentItem,
    required this.pageSize,
  });

  /// A convenience getter to check if there are more items to fetch.
  bool get hasMore => (currentItem + data.length) < total;
}
