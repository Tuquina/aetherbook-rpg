// Minimal static file server for `build/web`, with no dependency beyond
// dart:io — used by run-web-static.ps1/.sh to serve a release web build
// without Flutter's debug service (DWDS/VM Service), which only accepts
// connections from localhost and leaves a phone on the LAN stuck on a
// blank screen (`flutter run -d web-server` requires that debug connection
// to finish booting the app in debug mode).
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 8080;
  final root = Directory('build/web');
  if (!root.existsSync()) {
    stderr.writeln('build/web no existe — corré "flutter build web" primero.');
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  // ignore: avoid_print
  print('Sirviendo ${root.path} en http://0.0.0.0:$port (Ctrl+C para salir)');

  await for (final request in server) {
    var relativePath = request.uri.path;
    if (relativePath == '/' || relativePath.isEmpty) {
      relativePath = '/index.html';
    }
    var file = File('${root.path}$relativePath');
    // Flutter web is a single-page app: any path with no matching file
    // (e.g. a deep link) falls back to index.html so its own router
    // handles it, instead of a raw 404.
    if (!file.existsSync()) {
      file = File('${root.path}/index.html');
    }
    if (!file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }
    request.response.headers.contentType = _contentTypeFor(file.path);
    await request.response.addStream(file.openRead());
    await request.response.close();
  }
}

ContentType _contentTypeFor(String path) {
  if (path.endsWith('.html')) return ContentType.html;
  if (path.endsWith('.js')) return ContentType('application', 'javascript');
  if (path.endsWith('.json')) return ContentType.json;
  if (path.endsWith('.css')) return ContentType('text', 'css');
  if (path.endsWith('.wasm')) return ContentType('application', 'wasm');
  if (path.endsWith('.png')) return ContentType('image', 'png');
  if (path.endsWith('.svg')) return ContentType('image', 'svg+xml');
  if (path.endsWith('.ico')) return ContentType('image', 'x-icon');
  if (path.endsWith('.woff2')) return ContentType('font', 'woff2');
  return ContentType.binary;
}
