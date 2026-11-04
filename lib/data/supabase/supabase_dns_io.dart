import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Asks Cloudflare for the real address of the Supabase host (HTTPS to
/// 1.1.1.1, so it does not depend on the network's DNS) and connects there.
/// The certificate is still checked against the real host name.
void installSupabaseDns(String supabaseUrl) {
  final host = Uri.tryParse(supabaseUrl)?.host ?? '';
  if (host.isEmpty) return;
  HttpOverrides.global = _SupabaseDns(host);
}

class _SupabaseDns extends HttpOverrides {
  _SupabaseDns(this.host);

  final String host;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      final port = uri.hasPort
          ? uri.port
          : (uri.scheme == 'http' ? 80 : 443);
      final secure = uri.scheme != 'http';
      if (proxyHost != null || uri.host != host) {
        final target = proxyHost ?? uri.host;
        final targetPort = proxyHost != null ? proxyPort! : port;
        return _plain(target, targetPort, secure: secure && proxyHost == null);
      }
      final ips = await _addresses(host);
      Object? lastError;
      for (final ip in ips) {
        try {
          return await _plain(ip, port, secure: secure, serverName: host);
        } catch (e) {
          lastError = e;
        }
      }
      try {
        return await _plain(host, port, secure: secure);
      } catch (e) {
        throw lastError ?? e;
      }
    };
    return client;
  }

  Future<ConnectionTask<Socket>> _plain(String address, int port,
      {required bool secure, String? serverName}) async {
    if (!secure) {
      return await Socket.startConnect(address, port);
    }
    final socket = await Socket.connect(address, port,
        timeout: const Duration(seconds: 20));
    final tls = await SecureSocket.secure(socket, host: serverName ?? address);
    return ConnectionTask.fromSocket(Future<Socket>.value(tls), tls.destroy);
  }
}

List<String>? _cached;
DateTime? _cachedUntil;
Future<List<String>>? _inFlight;

/// Addresses for [host], refreshed every few minutes.
Future<List<String>> _addresses(String host) {
  final until = _cachedUntil;
  if (_cached != null && until != null && DateTime.now().isBefore(until)) {
    return Future.value(_cached);
  }
  return _inFlight ??= _query(host).whenComplete(() => _inFlight = null);
}

Future<List<String>> _query(String host) async {
  for (final resolver in const ['1.1.1.1', '1.0.0.1']) {
    try {
      final ips = await _doh(resolver, host);
      if (ips.isNotEmpty) {
        _cached = ips;
        _cachedUntil = DateTime.now().add(const Duration(minutes: 5));
        return ips;
      }
    } catch (_) {
      // try the other resolver
    }
  }
  return _cached ?? const [];
}

Future<List<String>> _doh(String resolverIp, String host) async {
  final raw = await Socket.connect(resolverIp, 443,
      timeout: const Duration(seconds: 10));
  final socket =
      await SecureSocket.secure(raw, host: 'cloudflare-dns.com');
  socket.write('GET /dns-query?name=${Uri.encodeQueryComponent(host)}&type=A '
      'HTTP/1.1\r\n'
      'Host: cloudflare-dns.com\r\n'
      'Accept: application/dns-json\r\n'
      'Connection: close\r\n\r\n');
  final bytes = await socket
      .fold<BytesBuilder>(BytesBuilder(), (b, chunk) => b..add(chunk))
      .then((b) => b.takeBytes());
  final text = utf8.decode(bytes, allowMalformed: true);
  final body = _httpBody(text);
  final json = jsonDecode(body) as Map<String, dynamic>;
  final answers = json['Answer'];
  if (answers is! List) return const [];
  return [
    for (final a in answers)
      if (a is Map && a['type'] == 1 && a['data'] is String) a['data'] as String
  ];
}

/// The JSON body of a small HTTP/1.1 response, chunked or not.
String _httpBody(String message) {
  final split = message.split('\r\n\r\n');
  if (split.length < 2) return message;
  final headers = split.first.toLowerCase();
  final raw = split.sublist(1).join('\r\n\r\n');
  if (!headers.contains('transfer-encoding: chunked')) return raw.trim();
  final out = StringBuffer();
  var rest = raw;
  while (rest.isNotEmpty) {
    final lineEnd = rest.indexOf('\r\n');
    if (lineEnd < 0) break;
    final size = int.tryParse(rest.substring(0, lineEnd).trim(), radix: 16);
    if (size == null || size == 0) break;
    final start = lineEnd + 2;
    out.write(rest.substring(start, start + size));
    rest = rest.substring(start + size + 2);
  }
  return out.toString();
}
