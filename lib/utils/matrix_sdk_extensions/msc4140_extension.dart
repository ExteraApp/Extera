import 'dart:convert';

import 'package:matrix/matrix.dart' as matrix;

extension Msc4140Extension on matrix.Room {
  Future<String> scheduleDelayedEvent(
    Map<String, dynamic> content, {
    required int delay,
    String type = matrix.EventTypes.Message,
    String? txid,
    matrix.Event? inReplyTo,
    String? editEventId,
    String? threadRootEventId,
    String? threadLastEventId,
  }) async {
    // PUT /_matrix/client/v3/rooms/{roomId}/delayed_event/{eventType}/{txnId}
    final requestUri = Uri(
      path: '/_matrix/client/v3/rooms/$id/delayed_event/$type/$txid',
    );
    final body = jsonEncode({'content': content, 'delay': delay});
    final response = await client.httpClient.put(
      client.baseUri!.resolveUri(requestUri),
      body: body,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      return responseBody['delay_id'] as String;
    } else {
      final errorBody = jsonDecode(response.body);
      var text = "${errorBody['errcode']}: ${errorBody['error']}";
      if (errorBody['max_delay'] != null) {
        text += " (Max delay: ${errorBody['max_delay']})";
      }
      throw Exception(text);
    }
  }

  Future<void> _manageDelayedEvent(String delayId, String action) async {
    // POST /_matrix/client/v1/delayed_events/{delay_id}/{action}
    final requestUri = Uri(
      path: '/_matrix/client/v1/delayed_events/$delayId/$action',
    );
    final response = await client.httpClient.post(
      requestUri,
      body: jsonEncode({}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    try {
      final errorBody = jsonDecode(response.body);
      final text = "${errorBody['errcode']}: ${errorBody['error']}";
      throw Exception(text);
    } catch (e) {
      throw Exception(
        'Failed to $action delayed event $delayId: ${response.statusCode}',
      );
    }
  }

  /// Send the delayed event immediately instead of waiting for the delay time.
  Future<void> sendDelayedEventNow(String delayId) async {
    return _manageDelayedEvent(delayId, 'send');
  }

  /// Cancel the delayed event so that it will never be sent.
  Future<void> cancelDelayedEvent(String delayId) async {
    return _manageDelayedEvent(delayId, 'cancel');
  }

  /// Restart the timer of a delayed event (reset to now + original_delay).
  Future<void> restartDelayedEvent(String delayId) async {
    return _manageDelayedEvent(delayId, 'restart');
  }

  /// Retrieve delayed events owned by the user.
  /// Optional `status` may be 'scheduled' or 'finalised'.
  Future<Map<String, dynamic>> getDelayedEvents({
    String? status,
    List<String>? delayIds,
    String? from,
  }) async {
    // GET /_matrix/client/v3/delayed_events
    const basePath = '/_matrix/client/v3/delayed_events';
    final queryParts = <String>[];
    if (status != null) {
      queryParts.add('status=${Uri.encodeQueryComponent(status)}');
    }
    if (delayIds != null) {
      for (final id in delayIds) {
        queryParts.add('delay_id=${Uri.encodeQueryComponent(id)}');
      }
    }
    if (from != null) queryParts.add('from=${Uri.encodeQueryComponent(from)}');

    final pathWithQuery = queryParts.isEmpty
        ? basePath
        : '$basePath?${queryParts.join('&')}';
    final requestUri = Uri(path: pathWithQuery);

    final response = await client.httpClient.get(
      client.baseUri!.resolveUri(requestUri),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded;
      } catch (e) {
        throw Exception('Failed to decode delayed events response: $e');
      }
    }
    try {
      final errorBody = jsonDecode(response.body);
      final text = "${errorBody['errcode']}: ${errorBody['error']}";
      throw Exception(text);
    } catch (e) {
      throw Exception('Failed to fetch delayed events: ${response.statusCode}');
    }
  }
}
