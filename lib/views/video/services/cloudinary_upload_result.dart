class CloudinaryVideoUploadResult {
  final String secureUrl;
  final String publicId;
  final int? bytes;

  const CloudinaryVideoUploadResult({
    required this.secureUrl,
    required this.publicId,
    this.bytes,
  });
}
