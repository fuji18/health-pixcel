/// 体重の記録(時刻・kg)から最新の値を返す。記録が無ければ null。
/// 同時刻の記録が複数あれば、列挙順で後のものを採る。
double? pickLatestWeight(Iterable<({DateTime at, num kg})> records) {
  DateTime? latestAt;
  num? latest;
  for (final r in records) {
    if (latestAt == null || !r.at.isBefore(latestAt)) {
      latestAt = r.at;
      latest = r.kg;
    }
  }
  return latest?.toDouble();
}
