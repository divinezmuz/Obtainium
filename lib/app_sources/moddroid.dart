import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:obtainium/custom_errors.dart';
import 'package:obtainium/providers/source_provider.dart';

class Moddroid extends AppSource {
  Moddroid() {
    hosts = ['moddroid.com'];
  }

  @override
  String sourceSpecificStandardizeURL(String url, {bool forSelection = false}) {
    RegExp pattern = RegExp(
        r'https?://(?:www\.)?moddroid\.com/(apps|games)/([^/]+)/([^/]+)/?.*');
    var match = pattern.firstMatch(url);
    
    if (match != null) {
      return 'https://moddroid.com/${match.group(1)}/${match.group(2)}/${match.group(3)}/';
    }
    
    throw ObtainiumError('Invalid Moddroid URL format');
  }

  @override
  Future<APKDetails> getLatestAPKDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    try {
      Response mainRes = await sourceRequest(standardUrl, additionalSettings);
      if (mainRes.statusCode != 200) throw getObtainiumHttpError(mainRes);
      
      var mainHtml = parse(mainRes.body);
      var baseUrl = Uri.parse(standardUrl);
      
      String? intermediateUrl;
      for (var link in mainHtml.querySelectorAll('a')) {
        var href = link.attributes['href'];
        if (href != null) {
          // FIX: Use standard Dart Uri resolution instead of missing helper
          var url = baseUrl.resolve(href).toString();
          
          if (RegExp(r'moddroid\.com/(apps|games)/.+/[A-Za-z0-9]+/$').hasMatch(url)) {
            intermediateUrl = url;
            break;
          }
        }
      }
      
      if (intermediateUrl == null) {
        throw NoReleasesError(note: 'Could not find download page');
      }
      
      Response intRes = await sourceRequest(intermediateUrl, additionalSettings);
      if (intRes.statusCode != 200) throw getObtainiumHttpError(intRes);
      
      var intHtml = parse(intRes.body);
      
      String? apkUrl;
      for (var link in intHtml.querySelectorAll('a')) {
        var href = link.attributes['href'];
        if (href != null && RegExp(r'cdn\.topmongo\.com/.*\.apk$').hasMatch(href)) {
          apkUrl = href;
          break;
        }
      }
      
      if (apkUrl == null) {
        throw NoReleasesError(note: 'Could not find APK download link');
      }
      
      var versionMatch = RegExp(r'\d+\.\d+(\.\d+)?').firstMatch(apkUrl);
      String version = versionMatch?.group(0) ?? apkUrl.hashCode.abs().toString();
      
      var title = mainHtml.querySelector('title')?.text ?? 'Moddroid App';
      String appName = title
          .replaceAll(' MOD APK', '')
          .replaceAll(RegExp(r' v?[\d\.]+.*'), '')
          .trim();
      if (appName.isEmpty) appName = 'Moddroid App';
      
      var fileName = Uri.parse(apkUrl).pathSegments.last;
      
      return APKDetails(
        version,
        [MapEntry('${apkUrl.hashCode}-$fileName', apkUrl)],
        AppNames(appName, appName),
      );
      
    } catch (e) {
      if (e is ObtainiumError) rethrow;
      throw ObtainiumError('Failed to get Moddroid app details: $e');
    }
  }
}
