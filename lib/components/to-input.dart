import 'package:chofer/states/app-state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:search_map_place/search_map_place.dart';

class ToInput extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    String firstName = appState.name.split(' ')[0];
    return Container(
        margin: EdgeInsets.only(top: 70),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SingleChildScrollView(
                child: SearchMapPlaceWidget(
                  darkMode: false,
                  iconColor: Colors.grey[700],
              apiKey: "AIzaSyB6TIHbzMpZYQs8VwYMuUZaMuk4VaKudeY",
              placeholder: "Hola $firstName, ¿A dónde quieres ir?",
              // The language of the autocompletion
              language: 'es',
              // The position used to give better recomendations. In this case we are using the user position
              location: appState.initialPosition,
              radius: 30000,
              onSelected: (Place place) async {
                final geolocation = await place.geolocation;
                // Will animate the GoogleMap camera, taking us to the selected position with an appropriate zoom
                appState.sendRequest(place.description);
                appState.destinationController.text = place.description;
                final GoogleMapController controller = appState.mapController;
                controller.animateCamera(
                    CameraUpdate.newLatLng(geolocation.coordinates));
                controller.animateCamera(
                    CameraUpdate.newLatLngBounds(geolocation.bounds, 0));
              },
            )),
          ],
        ));
  }
}
