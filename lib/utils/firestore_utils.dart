import 'package:cloud_firestore/cloud_firestore.dart';

/// Newest first by the Timestamp in [field]. Sorting on the device means the
/// queries need no composite index in the Firebase console. Documents whose
/// timestamp is still pending (just written) count as newest.
List<QueryDocumentSnapshot> sortNewestFirst(
  List<QueryDocumentSnapshot> docs,
  String field,
) {
  int millis(QueryDocumentSnapshot doc) {
    final value = (doc.data() as Map<String, dynamic>)[field];
    return value is Timestamp ? value.millisecondsSinceEpoch : 1 << 62;
  }

  return docs.toList()..sort((a, b) => millis(b).compareTo(millis(a)));
}
