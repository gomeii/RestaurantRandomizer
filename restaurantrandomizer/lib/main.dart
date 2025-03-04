// import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:filter_list/filter_list.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

Future<void> main() async{
  await dotenv.load(fileName: ".env"); // Load environment variables

  runApp(const MyApp());
}


// Main Class Widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green[700],
      ),
      home: const RestaurantFinder(),
    );
  }
}

// Restaurant Finder Widget
class RestaurantFinder extends StatefulWidget {
  const RestaurantFinder({super.key});

  @override
  State<RestaurantFinder> createState() => _RestaurantFinderState();
}

// Restaurant Finder State
class _RestaurantFinderState extends State<RestaurantFinder> {
  
  final Map<String, Marker> _markers = {};
  late GoogleMapController _mapController;
  LatLng _currentLocation = const LatLng(37.7749, -122.4194);
  double _radius = 5000;
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _restaurants = [];
  List<Map<String, dynamic>> _filteredRestaurants = [];
  Set<String> _selectedFilters = {};
  bool _isLoading = false;
  Color _buttonColor = Colors.white;

  // Creates Google Maps View
  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
  }

  // Search Location and Restaurant Function 
  Future<void> _searchLocationAndRestaurants(String text) async {
    final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    String searchQuery = text;

    final String geocodingUrl = 'https://maps.googleapis.com/maps/api/geocode/json?address=$searchQuery&key=$apiKey';

    try {
      final locationResponse = await http.get(Uri.parse(geocodingUrl));

      if (locationResponse.statusCode == 200) {
        // Decodes the HTTP Response from Google Maps API
        final locationData = json.decode(locationResponse.body);
        if (locationData['status'] == "OK") {
          final double lat = locationData['results'][0]['geometry']['location']['lat'];
          final double lng = locationData['results'][0]['geometry']['location']['lng'];
          _currentLocation = LatLng(lat, lng);

          // Recenter the map
          _mapController.animateCamera(CameraUpdate.newLatLng(_currentLocation));
          // Now search for restaurants within the new radius
          await _searchRestaurants();

          // Reapply filters to new restaurants
          _applyFilters();

        } else {
          print('Location not found. Query: $searchQuery');
        }
      } else {
        print(
            'Failed to fetch location. Status Code: ${locationResponse.statusCode}, Response: ${locationResponse.body}');
      }
    } catch (e) {
      print('Error occurred while fetching location: $e');
    }
  }

  // Search Restaurant Function (Based on _currentLocation, i.e. center of radius)
  Future<void> _searchRestaurants() async {
    final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    const String baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

    final String url = '$baseUrl?location=${_currentLocation.latitude},${_currentLocation.longitude}&radius=$_radius&type=restaurant&key=$apiKey';

    try {
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        print('Error: ${response.statusCode}, ${response.body}');
      }
      if (response.statusCode == 200) {
        // Decodes the HTTP Response from Google Maps API
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> results = data['results'];

        // Set State Callback Function
        setState(() {
          // Clear any markers and restaurants whenever a valid API Call
          _markers.clear();
          _restaurants.clear();

          // Iterate through API results and create a Marker
          for (var result in results) {
            
            // Initialize Marker Class
            final marker = Marker(
              markerId: MarkerId(result['name']),
              position: LatLng(result['geometry']['location']['lat'], result['geometry']['location']['lng']),
              infoWindow: InfoWindow(
                title: result['name'],
                snippet: result['vicinity'],
              ),
            );
            
            // Set Marker information 
            _markers[result['name']] = marker;

            // Add restaurant details to the list
            _restaurants.add({
              'name': result['name'],
              'position': [ result['geometry']['location']['lat'], result['geometry']['location']['lng'] ],
              'vicinity': result['vicinity'],
              'price_level': result['price_level'] ?? 'N/A',
              'rating': result['rating'] ?? 'N/A',
              'types': result['types'].join(', '),
            });

            _applyFilters();
     
          }
        });


      } else {
        print('Failed to fetch restaurants. Status Code: ${response.statusCode}, Response: ${response.body}');
      }
    } catch (e) {
      print('Error occurred while fetching restaurants: $e');
    }
  }

  // Update Search Radius callback function (Changes to position location, or changes in radius size)
  void _updateSearchRadius(LatLng position) {

    // Set State Callback Function
    setState(() {
      _currentLocation = position;
      _markers['customLocation'] = Marker(
        markerId: MarkerId('customLocation'),
        position: _currentLocation,
        infoWindow: const InfoWindow(title: 'Selected Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
      _searchRestaurants();

    });
  }
  
  // Update Marker to Filtered Restaurants
  void _updateMarkers() {
    setState(() {
      _markers.clear(); // Clear existing markers
      for (var restaurant in _filteredRestaurants) {
        final position = LatLng(
          restaurant['position'][0], 
          restaurant['position'][1]
        );
        final marker =  Marker(
              markerId: MarkerId(restaurant['name']),
              position: position,
              infoWindow: InfoWindow(
                title: restaurant['name'],
                snippet: restaurant['vicinity'],
              ),
            );
        _markers[restaurant['name']] = marker;
      }
    });
}

  // Sets _filteredRestaurants based on passed in category
  // Calling this function toggles the category on or off
  void _filterRestaurants(String category) {
    setState(() {
      // Toggle selection
      if (_selectedFilters.contains(category)) {
        _selectedFilters.remove(category);
      } else {
        _selectedFilters.add(category);
      }

      // Apply filters
      if (_selectedFilters.isEmpty) {
        _filteredRestaurants = _restaurants; // Show all restaurants
      } else {
        _filteredRestaurants = _restaurants
            .where((restaurant) =>
                _selectedFilters.any((filter) => restaurant['types'].contains(filter)))
            .toList();
      }

      // Update map markers
      _updateMarkers();
    });
  }


  void _applyFilters() {

    setState(() {
      _filteredRestaurants.clear();
      List<String> filterList = _selectedFilters.toList();
      if (filterList.isEmpty) {
        _filteredRestaurants = List.from(_restaurants);
      } else {
        _filteredRestaurants = _restaurants
            .where((restaurant) =>
                filterList.any((category) => restaurant['types'].contains(category)))
            .toList();
            
        _updateMarkers();
      }
    });
  }
  
  // Calls Random Restaurant Dialog Box
  void _randomRestaurantSelection() {
    if (_filteredRestaurants.isNotEmpty && _filteredRestaurants.length > 1) {
      // Convert Restaurants to Fortune Wheel Items
      List<FortuneItem> _convertedFortuneItems = _filteredRestaurants.map((restaurant) {
        return FortuneItem(
          child: Text(restaurant['name'], style: TextStyle(color:Colors.white)),
          style: FortuneItemStyle(
            color: Colors.blueAccent,
            borderWidth: 2,
            borderColor:Colors.white,
          ),
        );        
        }).toList();
      // Select Random Index from the list
      final randomIndex = Random().nextInt(_convertedFortuneItems.length);
      final selectedRestaurant = _filteredRestaurants[randomIndex];
      
      showDialog(
        context: context,
        builder: (context) {
        return FortuneWheel(
          items: _convertedFortuneItems,
          selected: Stream.value(randomIndex),
          onAnimationEnd:() {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Random Restaurant'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: ${selectedRestaurant['name']}'),
                      Text('Address: ${selectedRestaurant['vicinity']}'),
                      Text('Rating: ${selectedRestaurant['rating']}'),
                      Text('Price Level: ${selectedRestaurant['price_level']}'),
                      Text('Cuisine: ${selectedRestaurant['types']}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        // Close both dialogs
                        Navigator.of(context).pop(); // Close the restaurant details dialog
                        Navigator.of(context).pop(); // Close the FortuneWheel dialog
                      },
                      child: const Text('OK'),
                    ),
                  ],
                );
              },
            );
          },);
        },
      );

    }
  }


  void openFilterDialog() async {
    Set<String> uniqueCuisines = {};
    for (var restaurant in _restaurants) {
      List<String> cuisines = restaurant['types'].split(', ');
      uniqueCuisines.addAll(cuisines);
    }
    List<String> cuisineList = uniqueCuisines.toList();

     await FilterListDialog.display<String>(
      context,
      listData: cuisineList,
      selectedListData: _selectedFilters.toList(),
      choiceChipLabel: (cuisine) => cuisine!,
      validateSelectedItem: (list, val) => list!.contains(val),
      onItemSearch: (cuisine, query) => cuisine!.toLowerCase().contains(query.toLowerCase()),
      onApplyButtonClick: (selectedList) {
        if (selectedList != null) {
          setState(() {
            _selectedFilters = selectedList.toSet();
          });
          _applyFilters(); // ✅ Call here
          for (String filter in _selectedFilters){
            _filterRestaurants(filter);
          }
        }
        Navigator.pop(context);
      },
    );
  }

  Widget _buildFilterButton(String display, String category) {
    return ElevatedButton(
      onPressed: () {
        _filterRestaurants(category);
      },
      onLongPress: () {
        _filterRestaurants(category);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedFilters.contains(category)
            ? Colors.blue // Darker color for selected
            : Colors.blueGrey, // Default color
        foregroundColor: Colors.white,
      ),
      child: GestureDetector(
        onTap: () => {
          print("Quick filter tapped!"),
          // You can perform any additional actions here.
          _filterRestaurants(category)
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 5),
          child: Text(display),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Find a Restaurant'),
          elevation: 2,
        ),
        body: Column(
          children: [
            // The Top Search Bar and Slider
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onSubmitted: (String value) async {_searchLocationAndRestaurants(value);},
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for location',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _searchLocationAndRestaurants(_searchController.text),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                // Radius Slider
                Expanded(
                  child: Slider(
                    value: _radius,
                    min: 1000,
                    max: 10000,
                    divisions: 10,
                    label: '${(_radius / 1000).toStringAsFixed(1)} mi',
                    onChanged: (value) => setState(() {
                      _radius = value;
                      _updateSearchRadius(_currentLocation);
                    }),
                  ),
                ),

                Wrap(
                  spacing: 8.0, // Space between buttons
                  children: [
                    _buildFilterButton("Takeout",'meal_takeaway'),
                    _buildFilterButton("Cafe",'cafe'),
                    ElevatedButton(
                      onPressed: openFilterDialog,
                      child: Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
            // Expanded to prevent infinite height issues
            Expanded(
              child:
              // Layout Builder to conditionally render as a column or row depending on max width 
              LayoutBuilder(
                builder: (context, constraints){
                  bool isWideScreen = constraints.maxWidth > 600;
                  double TwoThirdsHeight = constraints.maxHeight/ 3 * 2; 
                  return isWideScreen ?
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start, // Prevent unbounded height
                      children: [
                        // Google Map - Set height properly
                        Expanded(
                          child: SizedBox(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : GoogleMap(
                                    onMapCreated: _onMapCreated,
                                    initialCameraPosition: CameraPosition(
                                      target: _currentLocation,
                                      zoom: 12,
                                    ),
                                    myLocationButtonEnabled: false,
                                    markers: _markers.values.toSet(),
                                    onTap: (LatLng tappedLocation){ _updateSearchRadius(tappedLocation);},
                                    onLongPress:(LatLng tappedLocation){ _updateSearchRadius(tappedLocation);},
                                    
                                    circles: {
                                      Circle(
                                        circleId: const CircleId('radius'),
                                        center: _currentLocation,
                                        radius: _radius,
                                        fillColor: Colors.blue.withOpacity(0.1),
                                        strokeColor: Colors.blue,
                                        consumeTapEvents: false,
                                      ),
                                    },
                                  ),
                          ),
                        ),

                        // Restaurant List - Use Flexible to allow resizing
                        Expanded(
                          child: _filteredRestaurants.isEmpty
                              ? const Center(child: Text('No restaurants found'))
                              : ListView.builder(
                                  itemCount: _filteredRestaurants.length,
                                  itemBuilder: (context, index) {
                                    final restaurant = _filteredRestaurants[index];
                                    return ListTile(
                                      
                                      leading: CircleAvatar(child: Text('${index + 1}')),
                                      title: Text(restaurant['name']),
                                      subtitle: Text(
                                        'Rating: ${restaurant['rating']}, Price: ${restaurant['price_level']}\n'
                                        'Cuisine: ${restaurant['types']}',
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ) 
                    :
                    Column(
                      children: [
                        // Google Maps
                        SizedBox(
                          height: TwoThirdsHeight,// ✅ Define a proper height
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : GoogleMap(
                                  onMapCreated: _onMapCreated,
                                  initialCameraPosition: CameraPosition(
                                    target: _currentLocation,
                                    zoom: 12,
                                  ),
                                  markers: _markers.values.toSet(),
                                  onTap: (LatLng tappedLocation){ _updateSearchRadius(tappedLocation);},
                                  onLongPress:(LatLng tappedLocation){ _updateSearchRadius(tappedLocation);},
                                  circles: {
                                    Circle(
                                      circleId: const CircleId('radius'),
                                      center: _currentLocation,
                                      radius: _radius,
                                      fillColor: Colors.blue.withOpacity(0.1),
                                      strokeColor: Colors.blue,
                                      consumeTapEvents: false
                                    ),
                                  },
                                ),
                        ),
                      
                        // Restaurant List - Use Flexible to allow resizing
                        Flexible(
                          child: _filteredRestaurants.isEmpty
                              ? const Center(child: Text('No restaurants found'))
                              : ListView.builder(
                                  itemCount: _filteredRestaurants.length,
                                  itemBuilder: (context, index) {
                                    final restaurant = _filteredRestaurants[index];
                                    return ListTile(
                                      leading: CircleAvatar(child: Text('${index + 1}')),
                                      title: Text(restaurant['name']),
                                      subtitle: Text(
                                        'Rating: ${restaurant['rating']}, Price: ${restaurant['price_level']}\n'
                                        'Cuisine: ${restaurant['types']}',
                                      ),
                                    );
                                  },
                                ),
                        ),
                                
                        ],
                    );  
                }
              ),
            
            ),
          
            // Random Restaurant Button (Rendered only if restaurants exist)
            if (_filteredRestaurants.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: MouseRegion(
                  onEnter: (_) {
                    // Change color when hovered
                    setState(() {
                      _buttonColor = Colors.green; // Change to green when hovered
                    });
                  },
                  onExit: (_) {
                    // Reset color when not hovered
                    setState(() {
                      _buttonColor = Colors.white; // Or any other default color
                    });
                  },
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(_buttonColor), // Use the color that changes on hover
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 75, vertical: 40)), // Increase padding to make it bigger
                      textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 25)), // Adjust font size
                    ),
                    onPressed: _randomRestaurantSelection,
                    child: const Text('Pick a Restaurant'),
                  ),
                ),
              ),
          ],
        ),
      );
  }

}