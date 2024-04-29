abstract class Memento<T> {
  T getMemento();
  void updateFromMemento(T memento);
}
