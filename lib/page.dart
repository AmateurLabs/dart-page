library page;

import "dart:html";
import "dart:collection";
import "dart:js";
import "package:ruler/ruler.dart";
import "package:tail/tail.dart";
import "package:pencil/pencil.dart";
import "package:desk/desk.dart";

class Page {
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
  List<ActorList> _lists = new List<ActorList>();
  
  List<System> systems;
  
  Page({int width:800, int height:600}) {
    context.deleteProperty("webkitAudioContext"); //Workaround; webkit-prefixed property still exists in Chrome but is deprecated
    ruler = new Ruler();
    pencil = new Pencil.createCanvas(document.body, width, height);
    pencil.getContext().lineWidth = 1.5;
    canvas = pencil.getCanvas();
    tail = new Tail(canvas);
    desk = new Desk();
    ruler.onUpdate(update);
    ruler.start();
    actors = new ActorList(this);
    systems = new List<System>();
  }
  
  void update(num dt) {
    tail.update();
    actors.sort((Actor a, Actor b) => (a.depth - b.depth).sign);
    for (ActorList list in _lists) list._update();
    for (Actor obj in actors) obj.update(dt);
    for (ActorList list in _lists) list._update();
    
    systems.sort((System a, System b) => (a.priority - b.priority).sign);
    for (System sys in systems) sys.update(dt);
    
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
          debugShape.stroke = Color.spectrum[actor.id % Color.spectrum.length];
          pencil.move(actor.position.x, actor.position.y).rotate(actor.rotation).shape(debugShape).draw();
        }
      }
    }
  }
  
  int _nextId = 0;
  
  Actor addActor(Actor actor) {
    actor.id = _nextId++;
    actors.add(actor);
    return actor;
  }
}

class Actor<T extends Shape> {
  int id = -1;
  Vector position;
  num rotation;
  num depth;  
  T shape;
  Sprite sprite;
  
  bool visible = true;
  
  bool _destroyed = false;
  bool get destroyed => _destroyed;
  
  Actor(Page page, {Vector position, num rotation, num depth, T shape, Sprite sprite}) {
    if (position != null) this.position = new Vector.from(position);
    else this.position = Vector.zero;
    this.rotation = rotation ?? 0.0;
    this.depth = depth ?? 0;
    this.sprite = sprite ?? null;
    this.shape = shape ?? null;
    page.addActor(this);
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

class System {
  ActorList list;
  num priority;
  
  System(Page page) {
    page.systems.add(this);
  }
  
  bool isRelevant(Actor actor) { return false; }
  
  void update(num dt) {
    for (Actor actor in list) if (!isRelevant(actor)) list.remove(actor);
  }
}

class ActorList<T extends Actor> extends ListBase {
  
  ActorList(Page page) {
    page._lists.add(this);
  }
  
  List<T> _objs = new List<T>();
  List<T> _addList = new List<T>();
  Set<T> _removeList = new Set<T>();
  
  void add(T obj) => _addList.add(obj);
  
  bool remove(T obj) {
    _removeList.add(obj);
    return _objs.contains(obj);
  }
  
  int get length => _objs.length;
  void set length(int l) {
    this._objs.length = l;
  }
  
  Actor operator [](int index) => _objs[index];
  void operator []=(int index, Actor value) {
    _objs[index] = value;
  }
  
  void _update() {
    _objs.removeWhere((T obj) => obj._destroyed || _removeList.contains(obj));
    _removeList.clear();
    _objs.addAll(_addList);
    _addList.clear();
  }
  
  void destroy() {
    for (T actor in _objs) actor.destroy();
    _update();
  }
}