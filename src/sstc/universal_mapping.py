"""Extract structural information from a parsed UniversalMapping AssignNode.

The UniversalMapping expression encodes two pieces of information the
generator needs: the list of attributes in the universal tuple (from
the enclosing ProjectNode), and the order in which base tables are
natural-joined to reconstruct it (from the nested NaturalJoinNode tree).
"""

from rapt2.treebrd.node import (
    AssignNode,
    NaturalJoinNode,
    Node,
    ProjectNode,
    RelationNode,
)


def _inner(node: AssignNode) -> Node:
    """Peel AssignNode / ProjectNode wrappers to reach the join-or-relation root."""
    current: Node = node
    if isinstance(current, AssignNode):
        current = current.child
    if isinstance(current, ProjectNode):
        current = current.child
    return current


def extract_projection(node: AssignNode) -> list[str]:
    """Return the ProjectNode attribute list wrapping the join tree.

    Raises ValueError if the UniversalMapping is not of the expected
    shape (AssignNode -> ProjectNode -> ...).
    """
    if not isinstance(node, AssignNode):
        raise ValueError(f"Expected AssignNode, got {type(node).__name__}")
    child = node.child
    if not isinstance(child, ProjectNode):
        raise ValueError(
            "UniversalMapping must be wrapped in \\project_{...}; "
            f"got {type(child).__name__}"
        )
    return list(child.attributes.names)


def extract_join_order(node: AssignNode) -> list[str]:
    """Return the left-to-right base-table sequence from a UniversalMapping.

    Handles three shapes:
    - AssignNode -> ProjectNode -> RelationNode             (single table)
    - AssignNode -> ProjectNode -> NaturalJoinNode (tree)   (multi-table)
    - AssignNode -> RelationNode / NaturalJoinNode          (bare, no project)
    """
    if not isinstance(node, AssignNode):
        raise ValueError(f"Expected AssignNode, got {type(node).__name__}")
    return _collect(_inner(node))


def _collect(node: Node) -> list[str]:
    if isinstance(node, RelationNode):
        return [node.name]
    if isinstance(node, NaturalJoinNode):
        return _collect(node.left) + _collect(node.right)
    raise ValueError(
        "UniversalMapping inner expression must be a \\natural_join chain "
        f"of relations; got {type(node).__name__}"
    )
