import 'package:google_fonts/google_fonts.dart';

/// google_fonts downloads font files over HTTP on first use. That is not
/// possible inside `flutter test` (all requests return 400), so any test that
/// builds a theme must turn runtime fetching off first and let the fallback
/// font stand in.
void disableGoogleFontsNetwork() {
  GoogleFonts.config.allowRuntimeFetching = false;
}
