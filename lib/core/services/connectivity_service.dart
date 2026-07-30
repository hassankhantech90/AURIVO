import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class ConnectivityService {
  ConnectivityService({
    Connectivity? connectivity,
    InternetConnectionChecker? internetConnectionChecker,
  }) : _connectivity = connectivity ?? Connectivity(),
       _internetConnectionChecker =
           internetConnectionChecker ?? InternetConnectionChecker.instance;

  final Connectivity _connectivity;
  final InternetConnectionChecker _internetConnectionChecker;

  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  Future<bool> get hasInternetConnection =>
      _internetConnectionChecker.hasConnection;
}
