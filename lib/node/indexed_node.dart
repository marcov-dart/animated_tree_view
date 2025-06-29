import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:uuid/v4.dart';

import '../helpers/exceptions.dart';
import 'base/i_node.dart';
import 'base/i_node_actions.dart';

class IndexedNode extends INode implements IIndexedNodeActions {
  /// These are the children of the node.
  @override
  final List<IndexedNode> children;

  /// This is the uniqueKey of the [Node]
  @override
  final String key;

  /// This is the parent [Node]. Only the root node has a null [parent]
  @override
  IndexedNode? get parent => _parent;

  IndexedNode? _parent;

  /// The more comprehensive variant of Node that uses [List] to store the
  /// children.
  ///
  /// Default constructor that takes an optional [key] and a parent.
  /// Make sure that the provided [key] is unique to among the siblings of the node.
  /// If a [key] is not provided, then a [UniqueKey] will automatically be
  /// assigned to the [Node].
  IndexedNode({String? key, IndexedNode? parent})
    : assert(
        key == null || !key.contains(INode.pathSeperator),
        "Key should not contain the PATH_SEPARATOR '${INode.pathSeperator}'",
      ),
      children = <IndexedNode>[],
      key = key ?? const UuidV4().generate(),
      _parent = parent;

  /// Alternate factory constructor that should be used for the [root] nodes.
  factory IndexedNode.root() => IndexedNode(key: INode.rootKey);

  /// Getter to get the [root] node.
  /// If the current node is not a [root], then the getter will traverse up the
  /// path to get the [root].
  @override
  IndexedNode get root => super.root as IndexedNode;

  /// This returns the [children] as an iterable list.
  @override
  List<IndexedNode> get childrenAsList => UnmodifiableListView(children);

  /// Get the [first] child in the list
  @override
  IndexedNode get first {
    if (children.isEmpty) throw ChildrenNotFoundException(this);
    return children.first;
  }

  /// Set the [first] child in the list to [value]
  @override
  set first(IndexedNode value) {
    if (children.isEmpty) throw ChildrenNotFoundException(this);
    children.first = value;
  }

  /// Get the [last] child in the list
  @override
  IndexedNode get last {
    if (children.isEmpty) throw ChildrenNotFoundException(this);
    return children.last;
  }

  /// Set the [last] child in the list to [value]
  @override
  set last(IndexedNode value) {
    if (children.isEmpty) throw ChildrenNotFoundException(this);
    children.last = value;
  }

  /// Get the first child node that matches the criterion in the [test].
  /// An optional [orElse] function can be provided to handle the [test] is not
  /// able to find any node that matches the provided criterion.
  @override
  IndexedNode firstWhere(
    bool Function(IndexedNode element) test, {
    IndexedNode Function()? orElse,
  }) {
    return children.firstWhere(test, orElse: orElse);
  }

  /// Get the index of the first child node that matches the criterion in the
  /// [test].
  /// An optional [start] index can be provided to ignore any nodes before the
  /// index [start]
  @override
  int indexWhere(bool Function(IndexedNode element) test, [int start = 0]) {
    return children.indexWhere(test, start);
  }

  /// Get the last child node that matches the criterion in the [test].
  /// An optional [orElse] function can be provided to handle the [test] is not
  /// able to find any node that matches the provided criterion.
  @override
  IndexedNode lastWhere(
    bool Function(IndexedNode element) test, {
    IndexedNode Function()? orElse,
  }) {
    return children.lastWhere(test, orElse: orElse);
  }

  /// Add a child [value] node to the [children]. The [value] will be inserted
  /// after the last child in the list
  @override
  void add(IndexedNode value) {
    value._parent = this;
    children.add(value);
  }

  /// Add a collection of [Iterable] nodes to [children]. The [iterable] will be
  /// inserted after the last child in the list
  @override
  void addAll(Iterable<IndexedNode> iterable) {
    for (final node in iterable) {
      node._parent = this;
    }
    children.addAll(iterable);
  }

  /// Insert an [element] in the children list at [index]
  @override
  void insert(int index, IndexedNode element) {
    element._parent = this;
    children.insert(index, element);
  }

  /// Insert an [element] in the children list after the node [after]
  @override
  int insertAfter(IndexedNode after, IndexedNode element) {
    final index = children.indexWhere((node) => node.key == after.key);
    if (index < 0) throw NodeNotFoundException.fromNode(after);
    insert(index + 1, element);
    return index + 1;
  }

  /// Insert an [element] in the children list before the node [before]
  @override
  int insertBefore(IndexedNode before, IndexedNode element) {
    final index = children.indexWhere((node) => node.key == before.key);
    if (index < 0) throw NodeNotFoundException.fromNode(before);
    insert(index, element);
    return index;
  }

  /// Insert a collection of [Iterable] nodes in the children list at [index]
  @override
  void insertAll(int index, Iterable<IndexedNode> iterable) {
    for (final node in iterable) {
      node._parent = this;
    }
    children.insertAll(index, iterable);
  }

  /// Delete [this] node
  @override
  void delete() {
    if (parent == null) {
      root.clear();
    } else {
      parent?.remove(this);
    }
  }

  /// Remove a child [value] node from the [children]
  @override
  void remove(IndexedNode value) {
    final index = children.indexWhere((node) => node.key == value.key);
    if (index < 0) throw NodeNotFoundException(key: key);
    children.removeAt(index);
  }

  /// Remove the child node at the [index]
  @override
  IndexedNode removeAt(int index) {
    final node = children.removeAt(index);
    return node;
  }

  /// Remove all the [Iterable] nodes from the [children]
  @override
  void removeAll(Iterable<IndexedNode> iterable) {
    for (final node in iterable) {
      remove(node);
    }
  }

  /// Remove all the child nodes from the [children] that match the criterion
  /// in the given [test]
  @override
  void removeWhere(bool Function(IndexedNode element) test) {
    children.removeWhere(test);
  }

  /// Clear all the child nodes from [children]. The [children] will be empty
  /// after this operation.
  @override
  void clear() {
    children.clear();
  }

  /// * Utility method to get a child node at the [path].
  /// Get any item at [path] from the [root]
  /// The keys of the items to be traversed should be provided in the [path]
  ///
  /// For example in a TreeView like this
  ///
  /// ```dart
  /// Node get mockNode1 => Node.root()
  ///   ..addAll([
  ///     Node(key: "0A")..add(Node(key: "0A1A")),
  ///     Node(key: "0B"),
  ///     Node(key: "0C")
  ///       ..addAll([
  ///         Node(key: "0C1A"),
  ///         Node(key: "0C1B"),
  ///         Node(key: "0C1C")
  ///           ..addAll([
  ///             Node(key: "0C1C2A")
  ///               ..addAll([
  ///                 Node(key: "0C1C2A3A"),
  ///                 Node(key: "0C1C2A3B"),
  ///                 Node(key: "0C1C2A3C"),
  ///               ]),
  ///           ]),
  ///       ]),
  ///   ]);
  ///```
  ///
  /// In order to access the Node with key "0C1C", the path would be
  ///   0C.0C1C
  ///
  /// Note: The root node [rootKey] does not need to be in the path
  @override
  IndexedNode elementAt(String path) {
    IndexedNode currentNode = this;
    for (final nodeKey in path.splitToNodes) {
      if (nodeKey == currentNode.key) {
        continue;
      } else {
        final index = currentNode.children.indexWhere(
          (node) => node.key == nodeKey,
        );
        if (index < 0) {
          throw NodeNotFoundException(parentKey: path, key: nodeKey);
        }
        final nextNode = currentNode.children[index];
        currentNode = nextNode;
      }
    }
    return currentNode;
  }

  /// Returns the child node at the [index]
  @override
  IndexedNode at(int index) => children[index];

  /// Overloaded operator for [elementAt]
  @override
  IndexedNode operator [](String path) => elementAt(path);

  @override
  String toString() =>
      'IndexedNode{children: $children, key: $key, parent: $parent}';
}
