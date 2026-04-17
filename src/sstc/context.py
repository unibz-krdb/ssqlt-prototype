"""Context parsing pipeline for relational algebra definitions.

Reads a universal schema JSON file and a relational algebra text file,
runs them through the RAPT2 parser (Dependency Grammar), and separates the
resulting syntax tree into table definitions, dependency constraints, and
the special UniversalMapping assignment. The parsed artifacts are assembled
into Table instances and exposed via a Context object.
"""

import enum
import functools
import json
from typing import Self

from rapt2.rapt import Rapt
from rapt2.treebrd.node import (
    AssignNode,
    DependencyNode,
    FunctionalDependencyNode,
    InclusionEquivalenceNode,
    InclusionSubsumptionNode,
    MultivaluedDependencyNode,
    PrimaryKeyNode,
)
from rapt2.treebrd.schema import Schema

from sstc.definition import AttributeSchema

from .table import Table
from .universal_mapping import extract_join_order


class Direction(enum.StrEnum):
    """Direction of a context within a transducer."""

    SOURCE = "source"
    TARGET = "target"


UNIVERSAL_MAPPING_NAME = "universalmapping"


class Context:
    """Generic base class for source and target contexts."""

    tables: list[Table]
    schema: Schema

    def __init__(
        self,
        tables: list[Table],
        direction: Direction = Direction.SOURCE,
        dependency_nodes: list[DependencyNode] | None = None,
        universal_schema: list[AttributeSchema] | None = None,
        universal_mapping: AssignNode | None = None,
    ):
        self.tables = tables
        self.direction = direction
        self.dependency_nodes = dependency_nodes or []
        self.universal_schema = universal_schema or []
        self.universal_mapping = universal_mapping
        self.schema = Schema()
        for table in tables:
            self.schema.add(table.name, table.attributes)

    def _nodes_of_type(self, cls: type) -> list:
        """Filter dependency nodes to those matching the given type."""
        return [n for n in self.dependency_nodes if isinstance(n, cls)]

    @functools.cached_property
    def primary_keys(self) -> dict[str, list[str]]:
        return {
            node.relation_name: list(node.attributes)
            for node in self._nodes_of_type(PrimaryKeyNode)
        }

    @functools.cached_property
    def functional_dependencies(self) -> list[FunctionalDependencyNode]:
        return self._nodes_of_type(FunctionalDependencyNode)

    @functools.cached_property
    def multivalued_dependencies(self) -> list[MultivaluedDependencyNode]:
        return self._nodes_of_type(MultivaluedDependencyNode)

    @functools.cached_property
    def inclusion_equivalences(self) -> list[InclusionEquivalenceNode]:
        return self._nodes_of_type(InclusionEquivalenceNode)

    @functools.cached_property
    def inclusion_subsumptions(self) -> list[InclusionSubsumptionNode]:
        return self._nodes_of_type(InclusionSubsumptionNode)

    @functools.cached_property
    def universal_mapping_join_order(self) -> list[str]:
        """Ordered base-table names from the UniversalMapping join chain.

        The sequence mirrors the user's declared ``\\natural_join`` order.
        """
        if self.universal_mapping is None:
            raise ValueError("universal_mapping was not parsed")
        return extract_join_order(self.universal_mapping)

    @functools.cached_property
    def ordered_tables(self) -> list[Table]:
        """Tables in UniversalMapping join order."""
        by_name = {t.name: t for t in self.tables}
        return [by_name[name] for name in self.universal_mapping_join_order]

    @classmethod
    def from_file(
        cls,
        universal_path: str,
        context_path: str,
        direction: Direction = Direction.SOURCE,
    ) -> Self:
        """Parse a universal schema JSON and a relational algebra file into a Context.

        Loads the universal schema, then feeds the RA text through RAPT2's
        Dependency Grammar parser. The resulting nodes are separated into
        relation assignments (Table definitions), dependency nodes (PK, FD,
        MVD, INC constraints), and a reserved UniversalMapping assignment.
        Tables are constructed by matching each relation to its dependencies.
        """
        universal_attributes = []
        schema = {"Universal": []}
        with open(universal_path, "r") as file:
            universal_schema = json.load(file)
            for json_attr in universal_schema:
                json_attr["name"] = json_attr["name"].lower()
                universal_attributes.append(AttributeSchema.from_dict(json_attr))
                schema["Universal"].append(json_attr["name"])

        with open(context_path, "r") as file:
            content = file.read()

        relations: list[AssignNode] = []
        dependencies: list[DependencyNode] = []
        universal_mapping: None | AssignNode = None

        for node in Rapt(grammar="Dependency Grammar").to_syntax_tree(
            instring=content,
            schema=schema,
        ):
            if isinstance(node, AssignNode):
                if node.name.lower() == UNIVERSAL_MAPPING_NAME:
                    universal_mapping = node
                else:
                    relations.append(node)
            elif isinstance(node, DependencyNode):
                dependencies.append(node)
            else:
                raise ValueError(f"Unexpected node type: {type(node)}")

        if universal_mapping is None:
            raise ValueError("UniversalMapping is not defined in the input file.")

        tables = Table.from_relations_and_dependencies(
            definitions=relations,
            dependency_nodes=dependencies,
        )

        declared = {t.name for t in tables}
        mapping_tables = set(extract_join_order(universal_mapping))
        missing = declared - mapping_tables
        extra = mapping_tables - declared
        if missing or extra:
            raise ValueError(
                "UniversalMapping tables do not match declared relations "
                f"(missing from mapping: {sorted(missing)}; "
                f"extra in mapping: {sorted(extra)})"
            )

        return cls(
            tables=tables,
            direction=direction,
            dependency_nodes=dependencies,
            universal_schema=universal_attributes,
            universal_mapping=universal_mapping,
        )
