library page;

import "dart:html";
import "dart:collection";
import "package:ruler/ruler.dart";
import "package:tail/tail.dart";
import "package:pencil/pencil.dart";
import "package:desk/desk.dart";

abstract class Page {
  CanvasElement canvas;
  Ruler ruler;
  Tail tail;
  Pencil pencil;
  Desk desk;
  
  bool debug = false;
  
  Color clearColor = null;
  
  int get width => canvas.width;
  int get height => canvas.height;
  
  Box get bounds => new Box(width, height, position: new Vector(width / 2, height / 2));
  
  bool contains(Vector p) => p.x >= 0 && p.y >= 0 && p.x < width && p.y < height;
  
  ActorList<Actor> actors;
  SystemList<System> systems;
  SafeList<ActorList> lists;
  
  List<SafeList> _lists;
  
  bool _started = false;
  
  Page({int width:640, int height:480}) {
    ruler = new Ruler();
    pencil = new Pencil.createCanvas(document.body, width, height);
    pencil.getContext().lineWidth = 1.5;
    canvas = pencil.getCanvas();
    tail = new Tail(canvas);
    desk = new Desk();
    ruler.onUpdate(_update);
    _lists = new List<SafeList>();
    actors = new ActorList();
    actors.page = this;
    systems = new SystemList();
    systems.page = this;
    lists = new SafeList<ActorList>();
    lists.page = this;
    _lists.addAll([actors, systems, lists]);
    ruler.start();
  }

  int _nextId = 0;
  
  void _update(num dt) {
    if (!_started) {
      _started = true;
      start();
    }
    tail.update();
    for (SafeList list in _lists) list._update();
    for (Actor obj in actors) {
      if (obj._id == null) obj._id = _nextId++;
      obj.update(dt);
    }
    update(dt);
    for (System sys in systems) sys.update(dt);
    for (SafeList list in _lists) list._update();
    
    _draw();
  }
  
  void _draw() {
    if (clearColor != null) pencil.clear(clearColor);
    else pencil.clear();
    for (Actor actor in actors) {
      if (!actor.visible) continue;
      if (actor.sprite != null) pencil.move(actor.position.x, actor.position.y).rotate(actor.rotation).sprite(actor.sprite).draw();
      if (actor.shape != null) pencil.move(actor.position.x, actor.position.y).rotate(actor.rotation).shape(actor.shape).draw();
      if (debug) {
        Shape debugShape = (actor.shape ?? actor.sprite?.getBounds());
        if (debugShape is Label) debugShape = null;
        if (debugShape != null) {
          debugShape = debugShape.clone();
          debugShape.fill = null;
          debugShape.stroke = Color.spectrum[actor._id % Color.spectrum.length];
          pencil.move(actor.position.x, actor.position.y).rotate(actor.rotation).shape(debugShape).draw();
        }
      }
    }
  }
  
  void start();
  void update(num dt);
}

class Actor<T extends Shape> extends SafeListItem {
  int _id;
  Vector position;
  num rotation;
  num depth;
  num get priority => depth;
  void set priority(num v) { priority = v; }
  T shape;
  Sprite sprite;
  
  bool visible = true;
  
  bool _destroyed = false;
  bool get destroyed => _destroyed;
  
  Actor({Vector position, num rotation, num depth, T shape, Sprite sprite}) {
    if (position != null) this.position = new Vector.from(position);
    else this.position = Vector.zero;
    this.rotation = rotation ?? 0.0;
    this.depth = depth ?? 0;
    this.sprite = sprite ?? null;
    this.shape = shape ?? null;
  }
  
  void destroy() {
    _destroyed = true;
  }
  
  Shape getWorldShape() {
    Shape a = shape.clone();
    a.position = position + Vector.rotate(a.position, rotation);
    a.rotation += rotation;
    return a;
  }
  
  bool intersects(Actor other) => HitTest.intersects(getWorldShape(), other.getWorldShape());
  bool contains(Vector p) => HitTest.contains(getWorldShape(), p);
  
  void update(num dt) { }
}

class System extends SafeListItem {
  ActorList list;
  num priority = 0.0;
  
  bool isRelevant(Actor actor) { return false; }
  
  void update(num dt) {
    for (Actor actor in list) if (!isRelevant(actor)) list.remove(actor);
  }
}

class ActorList<T extends Actor> extends SafeList<T> {  
  void _update() {
    _removeList.addAll(_objs.where((T obj) => obj._destroyed));
    super._update();
  }
  
  void setVisible(bool visible) {
    for (T actor in _objs) actor.visible = visible;
  }
  
  void destroy() {
    for (T actor in _objs) actor.destroy();
  }
}

class SystemList<T extends System> extends SafeList<T> {
  
}

class SafeListItem {
  Page page;
  num priority = 0.0;
}

class SafeList<T extends SafeListItem> extends ListBase with SafeListItem {
  List<T> _objs = new List<T>();
  List<T> _addList = new List<T>();
  Set<T> _removeList = new Set<T>();
  
  void add(T obj) {
    obj.page = page;
    _addList.add(obj);
  }
  
  bool remove(T obj) {
    bool contains = _objs.contains(obj);
    if (contains) _removeList.add(obj);
    return contains;
  }
  
  int get length => _objs.length;
  void set length(int l) {
    this._objs.length = l;
  }
  
  T operator [](int index) => _objs[index];
  void operator []=(int index, T value) {
    _objs[index] = value;
  }
  
  void _update() {
    _objs.removeWhere((T obj) => _removeList.contains(obj));
    _removeList.clear();
    _objs.addAll(_addList);
    _addList.clear();
    _objs.sort((T a, T b) => (a.priority - b.priority).sign);
  }
}