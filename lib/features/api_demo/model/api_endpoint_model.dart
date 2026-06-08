enum EndpointGroup {
  system,
  tripCrud,
  externalData,
  combinedOutput,
  optionalAuth,
}

class ApiEndpointModel {
  const ApiEndpointModel({
    required this.method,
    required this.path,
    required this.description,
    required this.group,
    this.optional = false,
  });

  final String method;
  final String path;
  final String description;
  final EndpointGroup group;
  final bool optional;
}
