/// Flutter checkout for Wing Bank online payment. Re-exports `dart_wing`,
/// so one import gives both the widgets and the API client.
library;

export 'package:dart_wing/dart_wing.dart';
export 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show InAppWebViewController;
export 'src/wing_checkout_result.dart';
export 'src/wing_checkout_view.dart';
