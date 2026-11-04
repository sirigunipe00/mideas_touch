import 'supabase_dns_stub.dart'
    if (dart.library.io) 'supabase_dns_io.dart' as impl;

/// Makes Supabase reachable when the network's DNS returns a wrong address
/// for `*.supabase.co` (the TLS handshake then dies). No-op on web.
void installSupabaseDns(String supabaseUrl) =>
    impl.installSupabaseDns(supabaseUrl);
