// Uint8List? webImage;
// File? mobileImage;
// final ImagePicker _picker = ImagePicker();
//
// Future<void> _pickImage()async {
//   final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
//
//   if(pickedFile != null){
//     if(kIsWeb){
//       final bytes = await pickedFile.readAsBytes();
//       setState(() {
//         webImage = bytes;
//       });
//     }else{
//       setState(() {
//         mobileImage = File(pickedFile.path);
//       });
//     }
//   }
//
// }