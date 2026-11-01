/// What the stores share.
library;

/// Every row of a query, read [pageSize] rows at a time: the server returns
/// at most that many per request (PostgREST `max_rows`), without saying it
/// cut the rest. [page] reads rows [from] to [to] (inclusive) of a query
/// with a stable order.
Future<List<Map<String, dynamic>>> readAllPages(
  Future<List<Map<String, dynamic>>> Function(int from, int to) page, {
  int pageSize = 1000,
}) async {
  final rows = <Map<String, dynamic>>[];
  for (var from = 0; ; from += pageSize) {
    final batch = await page(from, from + pageSize - 1);
    rows.addAll(batch);
    if (batch.length < pageSize) return rows;
  }
}

/// The row count a counting RPC returns.
int rpcCount(Object? rpcResult) => (rpcResult as num).toInt();
