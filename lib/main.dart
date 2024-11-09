import 'package:flutter/material.dart';
import 'package:poc_ble_timeseries_data/providers/time_series_data_provider.dart';
import 'package:poc_ble_timeseries_data/screens/home_screen.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: TimeSeriesDataProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'POC - Timeseries BLE',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
