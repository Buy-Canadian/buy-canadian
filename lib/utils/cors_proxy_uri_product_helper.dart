import 'package:openfoodfacts/openfoodfacts.dart';

class CorsProxyUriProductHelper extends UriProductHelper {
  static const String _corsProxyUrl = 'http://tcloud9.ddns.net:3493/';

  const CorsProxyUriProductHelper({
    required super.domain,
    super.scheme,
    super.isTestMode,
    super.userInfoForPatch,
    super.defaultAddUserAgentParameters,
  });

  @override
  Uri getUri({
    required String path,
    Map<String, dynamic>? queryParameters,
    bool? addUserAgentParameters,
    String? userInfo,
    String? forcedHost,
  }) {
    // First, get the standard URI built by the superclass
    final originalUri = super.getUri(
      path: path,
      queryParameters: queryParameters,
      addUserAgentParameters: addUserAgentParameters,
      userInfo: userInfo,
      forcedHost: forcedHost,
    );
    // Prepend the CORS proxy URL to the fully constructed URI
    final proxiedUriString = '$_corsProxyUrl${originalUri.toString()}';
    return Uri.parse(proxiedUriString);
  }

  @override
  Uri getPatchUri({
    required String path,
  }) {
    // Get the original patch URI
    final originalUri = super.getPatchUri(path: path);
    // Prepend the proxy URL as well
    final proxiedUriString = '$_corsProxyUrl${originalUri.toString()}';
    return Uri.parse(proxiedUriString);
  }
}


