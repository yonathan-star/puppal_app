class Pet {


  //constructor
  Pet({required this.name, required this.isDog,
  required this.gramsOfFoodPerDay, required this.foodType});




  final String name;
  bool isDog;
  final int gramsOfFoodPerDay;
  final String foodType;
  void toggleIsDog()
  {
    isDog=!isDog;
  }
}