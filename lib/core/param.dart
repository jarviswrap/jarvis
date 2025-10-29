class Info {
  String? name;
  String? description;
  String? icon;
  Info( {this.name, this.description, this.icon});
}

class Param extends Info {
  final String type;
  final String? value;
  
  Param(this.type, {super.description, super.icon, super.name, this.value});
}