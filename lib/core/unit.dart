import 'param.dart';

class Unit extends Info {
  
  Unit( {super.name, super.description, super.icon});

  List<Param>? process(List<Param>? params) {
    return params;  
  }

  bool display(List<Param>? params) {
    return false;
  }
}