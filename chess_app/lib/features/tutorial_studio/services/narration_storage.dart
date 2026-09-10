import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';

/// Takes on this device, under the app's support directory.
///
/// **One home for where they are**, because there are two readers: the
/// recording screen that keeps them and the export that looks for them. A path
/// written twice is a take the export cannot find the first time one of the
/// two moves.
NarrationTakeStore deviceNarrationStore() => NarrationTakeStore(() async {
      final support = await getApplicationSupportDirectory();
      return Directory('${support.path}${Platform.pathSeparator}narration');
    });
