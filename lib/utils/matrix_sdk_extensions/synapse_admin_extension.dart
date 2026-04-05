import 'dart:convert';

import 'package:http/http.dart';
import 'package:matrix/matrix.dart' as matrix;

extension SynapseAdmin on matrix.Client {
  Future<List<dynamic>> getEventReports({int from = 0, int limit = 10}) async {
    final requestUri = Uri(
      path: '/_synapse/admin/v1/event_reports',
      query: 'from=$from&limit=$limit&order_by=received_ts&dir=b',
    );

    if (baseUri == null) return [];

    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer $accessToken';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['event_reports'];
  }

  Future<matrix.Event?> getReportedEvent(int id) async {
    final requestUri = Uri(path: '/_synapse/admin/v1/event_reports/$id');

    if (baseUri == null) return null;
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer $accessToken';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);

    final room = getRoomById(json['room_id']);

    if (room == null) return null;

    return matrix.Event(
      content: json['event_json']['content'],
      type: json['event_json']['type'],
      eventId: json['event_id'],
      senderId: json['sender'],
      originServerTs: DateTime.fromMillisecondsSinceEpoch(
        json['event_json']['origin_server_ts'],
      ),
      room: room,
    );
  }

  Future<bool> isSynapseAdministrator() async {
    print('Checking if I am admin...');
    print('User ID: $userID');
    if (userID == null) return false;
    final requestUri = Uri(path: '/_synapse/admin/v1/users/$userID/admin');

    print('Base URL: ${baseUri.toString()}');
    if (baseUri == null) return false;
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer $accessToken';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    print('Response from endpoint: $responseString');
    return json['admin'];
  }
}
