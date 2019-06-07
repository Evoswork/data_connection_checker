/// A utility library to check for an actual internet connection
/// by opening a socket connection to a list of addresses and/or ports.
/// Defaults are provided for convenience.
library data_connection_checker;

import 'dart:io';
import 'dart:async';

enum DataConnectionStatus {
  disconnected,
  connected,
}

/// This is a singleton that can be accessed like a regular constructor
/// i.e. DataConnectionChecker() always returns the same instance.
class DataConnectionChecker {
  /// More info on why default port is 53
  /// here:
  /// - https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
  /// - https://www.google.com/search?q=dns+server+port
  static const int DEFAULT_PORT = 53;

  /// Default timeout is 10 seconds
  /// Timeout is the number of seconds before a request is dropped
  /// and an address is considered unreachable
  static const Duration DEFAULT_TIMEOUT = Duration(seconds: 10);

  /// Predefined reliable addresses. This is opinionated
  /// but should be enough for a starting point.
  ///
  /// 1.1.1.1           CloudFlare, info: https://one.one.one.one/ http://1.1.1.1
  ///
  /// 8.8.8.8           Google, info: https://developers.google.com/speed/public-dns/
  ///
  /// 8.8.4.4           Google
  ///
  /// 208.67.222.222    OpenDNS, info: https://use.opendns.com/
  ///
  /// 208.67.220.220    OpenDNS
  static final List<AddressCheckOptions> DEFAULT_ADDRESSES = List.unmodifiable([
    AddressCheckOptions(
      InternetAddress('1.1.1.1'),
      port: DEFAULT_PORT,
      timeout: DEFAULT_TIMEOUT,
    ),
    AddressCheckOptions(
      InternetAddress('8.8.4.4'),
      port: DEFAULT_PORT,
      timeout: DEFAULT_TIMEOUT,
    ),
    AddressCheckOptions(
      InternetAddress('208.67.222.222'),
      port: DEFAULT_PORT,
      timeout: DEFAULT_TIMEOUT,
    ),
  ]);

  /// This is a singleton that can be accessed like a regular constructor
  /// i.e. DataConnectionChecker() always returns the same instance.
  factory DataConnectionChecker() => _instance;
  DataConnectionChecker._();
  static final DataConnectionChecker _instance = DataConnectionChecker._();

  /// A list of internet addresses (with port and timeout) DNS Resolvers to ping.
  /// These should be globally available destinations.
  /// Default is [DEFAULT_ADDRESSES]
  /// When [hasConnection] is called,
  /// this utility class tries to ping every address in this list.
  /// The provided addresses should be good enough to test for data connection
  /// but you can, of course, you can supply your own
  /// See [AddressCheckOptions] for more info.
  List<AddressCheckOptions> addresses = DEFAULT_ADDRESSES;

  /// Ping a single address.
  Future<AddressCheckResult> isHostReachable(
    AddressCheckOptions options,
  ) async {
    Socket sock;
    try {
      sock = await Socket.connect(
        options.address,
        options.port,
        timeout: options.timeout,
      );
      sock?.destroy();
      return AddressCheckResult(options, true);
    } catch (e) {
      sock?.destroy();
      return AddressCheckResult(options, false);
    }
  }

  /// Returns the results from the last check
  /// The list is populated only when [hasConnection] (or [connectionStatus]) is called
  List<AddressCheckResult> get lastTryResults => _lastTryResults;
  List<AddressCheckResult> _lastTryResults;

  /// Initiates a request to each address in [addresses]
  /// If at least one of the addresses is reachable
  /// this means we have an internet connection and this returns true.
  /// Otherwise - false.
  Future<bool> get hasConnection async {
    // Wait all futures to complete and return true
    // if there's at least one address with isSuccess = true

    List<Future<AddressCheckResult>> requests = [];

    for (var addressOptions in addresses) {
      requests.add(isHostReachable(addressOptions));
    }
    _lastTryResults = List.unmodifiable(await Future.wait(requests));

    return _lastTryResults.map((result) => result.isSuccess).contains(true);
  }

  /// Initiates a request to each address in [addresses]
  /// If at least one of the addresses is reachable
  /// this means we have an internet connection and this returns
  /// [DataConnectionStatus.connected].
  /// [DataConnectionStatus.disconnected] otherwise.
  Future<DataConnectionStatus> get connectionStatus async {
    return await hasConnection
        ? DataConnectionStatus.connected
        : DataConnectionStatus.disconnected;
  }
}

/// This class should be pretty self-explanatory.
/// If [AddressCheckOptions.port]
/// or [AddressCheckOptions.timeout] are not specified, they both
/// default to [DEFAULT_PORT]
/// and [DEFAULT_TIMEOUT]
/// Also... yeah, I'm not great at naming things.
class AddressCheckOptions {
  final InternetAddress address;
  final int port;
  final Duration timeout;

  AddressCheckOptions(
    this.address, {
    this.port = DataConnectionChecker.DEFAULT_PORT,
    this.timeout = DataConnectionChecker.DEFAULT_TIMEOUT,
  });

  @override
  String toString() => "AddressCheckOptions($address, $port, $timeout)";
}

/// Helper class that contains the address options and indicates whether
/// opening a socket to it succeeded.
class AddressCheckResult {
  final AddressCheckOptions options;
  final bool isSuccess;

  AddressCheckResult(
    this.options,
    this.isSuccess,
  );

  @override
  String toString() => "AddressCheckResult($options, $isSuccess)";
}
