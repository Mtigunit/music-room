import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

ImageProvider getPlatformCoverImage(XFile file) => FileImage(File(file.path));
