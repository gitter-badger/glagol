var getTree = module.exports = function getTree (node) {

  // from file, . points to parent and .. to grandparent;
  // from dir, .. points to parent and . to self.

  if (node.type === "Script") {

    if (!node.parent) ERR_NO_PARENT(node);
    return getTree(node.parent);

  } else {

    var tree = {};
    tree._ = tree;
    Object.keys(node.nodes).map(function (name) {
      Object.defineProperty(tree, translate(name), {
        configurable: true,
        enumerable: true,
        get: getter.bind(node.nodes[name]),
        set: setter.bind(node.nodes[name])
      })
    });
    if (node.parent) tree.__ = getTree(node.parent);
    return tree;

  }

};

function getter (node) {
  return node.type === "Script"
    ? node.value
    : node.type === "ScriptDirectory"
      ? getTree(node)
      : ERR_UNKNOWN_TYPE(node);
}

function setter (node, value) {
  ERR_CANT_SET();
}

function translate (name) {
  // TODO: replace hyphen with camelCase
  return name;
}

// TODO
//(defn- setter [i n]
  //(fn [args]
    //(if (not (vector? args)) (throw (Error. (str
        //"pass a [operation arg1 arg2 ... argN] vector "
        //"when writing to a notion"))))
      //(let [operation (aget args 0)]
        //(cond
          //(= operation :watch)
            //(cond
              //(= n.type "Notion")
                //(n.value (aget args 1))
              //(= n.type "NotionDirectory")
                //(.map (keys n.notions) (fn [i]
                  //(.value (aget n.notions i) (aget args 1)))))
          //:else (throw (Error. (str
            //operation " is not a valid operation, "
            //"unlike :watch"))))
        //nil)))

function ERR_NO_PARENT (node) {
  throw Error("node " + node.name + " is not connected to a tree");
}

function ERR_UNKNOWN_TYPE (node) {
  throw Error("foreign body in script tree, possible name: " + node.name);
}

function ERR_CANT_SET () {
  throw Error("setting values of tree nodes is not implemented yet")
}
