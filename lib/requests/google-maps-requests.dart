import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const apiKey = "AIzaSyB6TIHbzMpZYQs8VwYMuUZaMuk4VaKudeY";

class GoogleMapsServices {
  Future<Map> getRouteDistanceAndDuration(LatLng l1, LatLng l2) async {
    String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${l1.latitude},${l1.longitude}&destination=${l2.latitude},${l2.longitude}&key=$apiKey";
    http.Response response = await http.get(url);
    Map values = jsonDecode(response.body);

    Map answer = {
      'route': values["routes"][0]["overview_polyline"]["points"],
      'distanceText': values["routes"][0]["legs"][0]["distance"]["text"],
      'durationText': values["routes"][0]["legs"][0]["duration"]["text"],
      'distanceValue': values["routes"][0]["legs"][0]["distance"]["value"],
      'durationValue': values["routes"][0]["legs"][0]["duration"]["value"]
    };

    return answer;
  }

  Future<int> getDistanceValue(LatLng l1, LatLng l2) async {
    String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${l1.latitude},${l1.longitude}&destination=${l2.latitude},${l2.longitude}&key=$apiKey";
    http.Response response = await http.get(url);
    Map values = jsonDecode(response.body);
    return values["routes"][0]["legs"][0]["distance"]["value"];
  }
}
