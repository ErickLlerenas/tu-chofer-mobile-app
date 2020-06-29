import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:chofer/requests/google-maps-requests.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:location/location.dart' as l;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppState with ChangeNotifier {
  static LatLng _initialPosition;
  LatLng _lastPosition = _initialPosition;
  bool locationServiceActive = true;
  Set<Marker> _markers;
  Set<Polyline> _polyLines;
  GoogleMapController _mapController;
  GoogleMapsServices _googleMapsServices = GoogleMapsServices();
  TextEditingController locationController = TextEditingController();
  TextEditingController destinationController = TextEditingController();
  LatLng get initialPosition => _initialPosition;
  LatLng get lastPosition => _lastPosition;
  GoogleMapsServices get googleMapsServices => _googleMapsServices;
  GoogleMapController get mapController => _mapController;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polyLines => _polyLines;
  LatLng destination;
  LatLng origin;
  String distance;
  String duration;
  int distanceValue;
  int durationValue;
  int precio;
  bool isLoadingPrices;
  l.Location location = new l.Location();
  bool serviceEnabled = true;
  l.PermissionStatus _permissionGranted;
  String _phone;
  String _name;
  File image;
  File carImage;
  String downloadURL;
  String address;
  String carName;
  String carModel;
  TextEditingController nameController;
  TextEditingController addressController;
  TextEditingController carNameController;
  TextEditingController carModelController;
  String _locality;
  final picker = ImagePicker();
  int costoBase = 1;
  double costoKilometro = 3.07;
  double costoMinuto = 1.6;

  get phone => _phone;
  get name => _name;

  AppState() {
    hasAlreadyPermissionsAndService();
    getPhoneNumber();
    getUserName();
  }
  // GETS THE USER PHONE NUMBER
  Future getPhoneNumber() async {
    _phone = await readPhoneNumber();
    downloadProfilePicture(_phone);
    notifyListeners();
  }

  //GETS THE USER NAME
  Future getUserName() async {
    _name = await readName();
    notifyListeners();
  }

  //  TO GET THE USERS LOCATION
  void getUserLocation() async {
    try {
      Position position = await Geolocator()
          .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemark = await Geolocator()
          .placemarkFromCoordinates(position.latitude, position.longitude);
      _initialPosition = LatLng(position.latitude, position.longitude);
      locationController.text = placemark[0].thoroughfare +
          " " +
          placemark[0].name +
          ", " +
          placemark[0].subLocality +
          ", " +
          placemark[0].locality +
          ", " +
          placemark[0].administrativeArea +
          ", " +
          placemark[0].country;
    } catch (error) {
      print(error);
      getUserLocation();
    }
    notifyListeners();
  }

  //  TO CREATE ROUTE
  void createRoute(String encondedPoly) {
    _polyLines = {};
    _polyLines.add(Polyline(
        polylineId: PolylineId(Uuid().v1()),
        width: 3,
        points: _convertToLatLng(_decodePoly(encondedPoly)),
        color: Colors.black));
    notifyListeners();
  }

  //  ADD A MARKER ON THE MAP
  void _addMarker(LatLng location, String address) {
    _markers = {};
    _markers.add(Marker(
        markerId: MarkerId(Uuid().v1()),
        position: location,
        infoWindow: InfoWindow(title: "Destino", snippet: address),
        icon: BitmapDescriptor.defaultMarker));
    notifyListeners();
  }

  //  CREATE LAGLNG LIST
  List<LatLng> _convertToLatLng(List points) {
    List<LatLng> result = <LatLng>[];
    for (int i = 0; i < points.length; i++) {
      if (i % 2 != 0) {
        result.add(LatLng(points[i - 1], points[i]));
      }
    }
    return result;
  }

  // DECODE POLY (THIS FUNCTION IS PROVIDED BY GOOGLE)
  List _decodePoly(String poly) {
    var list = poly.codeUnits;
    var lList = new List();
    int index = 0;
    int len = poly.length;
    int c = 0;
    do {
      var shift = 0;
      int result = 0;

      do {
        c = list[index] - 63;
        result |= (c & 0x1F) << (shift * 5);
        index++;
        shift++;
      } while (c >= 32);
      if (result & 1 == 1) {
        result = ~result;
      }
      var result1 = (result >> 1) * 0.00001;
      lList.add(result1);
    } while (index < len);

    for (var i = 2; i < lList.length; i++) lList[i] += lList[i - 2];

    print(lList.toString());

    return lList;
  }

  //  SEND REQUEST
  void sendRequest(String intendedLocation) async {
    isLoadingPrices = false;
    precio = 30;
    costoBase = 1;
    origin = _initialPosition;
    List<Placemark> placemark =
        await Geolocator().placemarkFromAddress(intendedLocation);
    double latitude = placemark[0].position.latitude;
    double longitude = placemark[0].position.longitude;
    destination = LatLng(latitude, longitude);
    _addMarker(destination, intendedLocation);
    String route = await _googleMapsServices.getRouteCoordinates(
        _initialPosition, destination);
    distance =
        await _googleMapsServices.getDistance(_initialPosition, destination);
    duration =
        await _googleMapsServices.getDuration(_initialPosition, destination);
    durationValue = await _googleMapsServices.getDurationValue(
        _initialPosition, destination);
    distanceValue = await _googleMapsServices.getDistanceValue(
        _initialPosition, destination);

    if (distanceValue > 3000) {
      _locality = placemark[0].locality;
      if (_locality == "Comala") {
        costoBase += 10;
      }
      precio += ((((distanceValue - 3000) / 1000) * costoKilometro) +
              costoBase +
              (durationValue / 60 * costoMinuto))
          .toInt();
    }
    isLoadingPrices = true;
    createRoute(route);
    notifyListeners();
  }

  //  ON CAMERA MOVE
  void onCameraMove(CameraPosition position) {
    _lastPosition = position.target;
    notifyListeners();
  }

  //  ON MAP CREATED
  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    String _mapStyle =
        '[{"elementType":"geometry","stylers":[{"color":"#ebe3cd"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#523735"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#f5f1e6"}]},{"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#c9b2a6"}]},{"featureType":"administrative.land_parcel","elementType":"geometry.stroke","stylers":[{"color":"#dcd2be"}]},{"featureType":"administrative.land_parcel","elementType":"labels","stylers":[{"visibility":"off"}]},{"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#ae9e90"}]},{"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#dfd2ae"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#dfd2ae"}]},{"featureType":"poi","elementType":"labels.text","stylers":[{"visibility":"off"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#93817c"}]},{"featureType":"poi.business","stylers":[{"visibility":"off"}]},{"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#a5b076"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#447530"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#f5f1e6"}]},{"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#fdfcf8"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#f8c967"}]},{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#e9bc62"}]},{"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#e98d58"}]},{"featureType":"road.highway.controlled_access","elementType":"geometry.stroke","stylers":[{"color":"#db8555"}]},{"featureType":"road.local","elementType":"labels","stylers":[{"visibility":"off"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#806b63"}]},{"featureType":"transit","stylers":[{"visibility":"off"}]},{"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#dfd2ae"}]},{"featureType":"transit.line","elementType":"labels.text.fill","stylers":[{"color":"#8f7d77"}]},{"featureType":"transit.line","elementType":"labels.text.stroke","stylers":[{"color":"#ebe3cd"}]},{"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#dfd2ae"}]},{"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#b9d3c2"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#92998d"}]}]';
    _mapController.setMapStyle(_mapStyle);
    notifyListeners();
  }

  // CHANGES THE ORIGIN OF THE ROUTE
  void changeOrigin(LatLng origen) async {
    origin = origen;
    isLoadingPrices = false;
    precio = 30;
    costoBase = 1;
    List<Placemark> placemark =
        await Geolocator().placemarkFromAddress(destinationController.text);
    String route =
        await _googleMapsServices.getRouteCoordinates(origen, destination);
    createRoute(route);
    distance = await _googleMapsServices.getDistance(origen, destination);
    duration = await _googleMapsServices.getDuration(origen, destination);
    durationValue =
        await _googleMapsServices.getDurationValue(origen, destination);
    distanceValue =
        await _googleMapsServices.getDistanceValue(origen, destination);
    if (distanceValue > 3000) {
      _locality = placemark[0].locality;
      if (_locality == "Comala") {
        costoBase += 10;
      }
      precio += ((((distanceValue - 3000) / 1000) * costoKilometro) +
              costoBase +
              (durationValue / 60 * costoMinuto))
          .toInt();
    }
    isLoadingPrices = true;
    notifyListeners();
  }

  // CHANGES THE DESTINATION OF THE ROUTE
  void changeDestination(LatLng dest, intendedLocation) async {
    destination = dest;
    isLoadingPrices = false;
    precio = 30;
    costoBase = 1;
    List<Placemark> placemark =
        await Geolocator().placemarkFromAddress(intendedLocation);
    String route = await _googleMapsServices.getRouteCoordinates(origin, dest);
    createRoute(route);
    distance = await _googleMapsServices.getDistance(origin, dest);
    duration = await _googleMapsServices.getDuration(origin, dest);
    durationValue = await _googleMapsServices.getDurationValue(origin, dest);
    distanceValue = await _googleMapsServices.getDistanceValue(origin, dest);
    if (distanceValue > 3000) {
      _locality = placemark[0].locality;
      if (_locality == "Comala") {
        costoBase += 10;
      }
      precio += ((((distanceValue - 3000) / 1000) * costoKilometro) +
              costoBase +
              (durationValue / 60 * costoMinuto))
          .toInt();
    }
    isLoadingPrices = true;
    _addMarker(dest, intendedLocation);
    notifyListeners();
  }

  // CHECKS IF THE USER HAS PERMISSIONS AND THE LOCATION ACTIVE
  void hasAlreadyPermissionsAndService() async {
    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == l.PermissionStatus.granted) {
      serviceEnabled = await location.serviceEnabled();
      if (serviceEnabled) {
        getUserLocation();
      }
    }
  }

  // GET THE LOCAL PATH TO SAVE THE PHONE NUMBER
  Future<String> get _localPathNumber async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  //GET THE LOCAL PATH WITH FILE TO SAVE THE PHONE NUMBER
  Future<File> get _localFileNumber async {
    final path = await _localPathNumber;
    return File('$path/login_number.txt');
  }

  // WRITE THE PHONE NUMBER TO THE FILE
  Future<File> writePhone(String phoneNumber) async {
    final file = await _localFileNumber;
    return file.writeAsString('$phoneNumber');
  }

  // READ THE PHONE NUMBER FROM THE FILE
  Future<String> readPhoneNumber() async {
    try {
      final file = await _localFileNumber;
      return await file.readAsString();
    } catch (e) {
      return "";
    }
  }

  // GET THE LOCAL PATH TO SAVE THE USER NAME
  Future<String> get _localPathName async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  //GET THE LOCAL PATH WITH FILE TO SAVE THE USER NAME
  Future<File> get _localFileName async {
    final path = await _localPathName;
    return File('$path/login_name.txt');
  }

  // WRITE THE USER NAME TO THE FILE
  Future<File> writeName(String userName) async {
    final file = await _localFileName;
    return file.writeAsString('$userName');
  }

  // READ THE USER NAME FROM THE FILE
  Future<String> readName() async {
    try {
      final file = await _localFileName;
      return await file.readAsString();
    } catch (e) {
      return "";
    }
  }

  // SAVE THE NAME TO FIREBASE
  Future saveName(String id, String newName) async {
    _name = newName;
    await writeName(newName);
    await Firestore.instance
        .collection('Users')
        .document(id)
        .updateData({'name': newName});
    notifyListeners();
  }

  // GET THE IMAGE FROM FIREBASE
  Future getImage() async {
    final pickedFile = await picker.getImage(
        source: ImageSource.gallery,
        imageQuality: 10,
        maxHeight: 2048,
        maxWidth: 2048);
    if (pickedFile != null) image = File(pickedFile.path);
    notifyListeners();
  }

  Future getCarImage() async {
    final pickedFile = await picker.getImage(
        source: ImageSource.gallery,
        imageQuality: 10,
        maxHeight: 2048,
        maxWidth: 2048);
    if (pickedFile != null) carImage = File(pickedFile.path);
    notifyListeners();
  }

  //DOWNLOADS THE IMAGE FROM FIREBASE
  Future downloadProfilePicture(number) async {
    StorageReference storageReference =
        FirebaseStorage.instance.ref().child(number);
    downloadURL = await storageReference.getDownloadURL();
    notifyListeners();
  }

  //SAVES THE IMAGE TO FIREBASE
  Future savePicture(BuildContext context, String phone) async {
    StorageReference storageReference =
        FirebaseStorage.instance.ref().child(phone);
    if (image != null) {
      _cargandoDialog(context);
      StorageUploadTask uploadTask = storageReference.putFile(image);
      await uploadTask.onComplete;
      if (uploadTask.isComplete) {
        Navigator.pop(context);
      }
    }
    notifyListeners();
  }

  void _cargandoDialog(context) {
    // flutter defined function
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  "Guardando foto...",
                  style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: LinearProgressIndicator());
      },
    );
    notifyListeners();
  }

  // THIS IS FOR THE FLOATING ACTION BUTTON TO GET THE ACTUAL LOCATION
  void currentLocation() async {
    l.LocationData currentLocation;
    var location = new l.Location();
    try {
      currentLocation = await location.getLocation();
    } on Exception {
      currentLocation = null;
    }

    _mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        bearing: 0,
        target: LatLng(currentLocation.latitude, currentLocation.longitude),
        zoom: 15.0,
      ),
    ));
    notifyListeners();
  }

  // SEND A DRIVER REQUEST TO FIREBASE
  Future nextScreen(String name, String _address) async {
    address = _address;
    _name = name;
    notifyListeners();
  }

  // SEND A DRIVER REQUEST TO FIREBASE
  Future saveDriverDataRequest(String id, String name, String _address,
      String carName, String carModel, BuildContext context) async {
    try {
      writeName(name);
      //writeCarName(carName);
      //writeCarModel(carModel);

      await Firestore.instance
          .collection('Users')
          .document(id)
          .updateData({'name': name});

      await Firestore.instance.collection('Drivers').document(id).setData({
        'name': name,
        'address': _address,
        'carName': carName,
        'carModel': carModel,
        'isAccepted': false,
        'isActive': false,
        'phone': phone
      });

      notifyListeners();
    } catch (error) {
      print("ERROR: " + error);
      saveDriverDataRequest(id, name, _address, carName, carModel, context);
    }
  }

  //SAVES THE IMAGE TO FIREBASE
  Future saveCarPicture(BuildContext context, String phone) async {
    StorageReference storageReference =
        FirebaseStorage.instance.ref().child("driver" + phone);
    if (carImage != null) {
      _cargandoDialog(context);
      StorageUploadTask uploadTask = storageReference.putFile(carImage);
      await uploadTask.onComplete;
      if (uploadTask.isComplete) {
        Navigator.pop(context);
      }
    }
    notifyListeners();
  }
}
