import 'dart:io';

import 'package:flutter/painting.dart';

/// [source] is a filesystem path here — what Android's pickers return.
ImageProvider pickedFileImage(String source) => FileImage(File(source));
