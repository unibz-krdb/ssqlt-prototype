from dataclasses import dataclass
from typing import Self

from .context_dir import ContextDir
from .context_file_paths import ContextFilePaths
from .Dataclasses import Universal
from .db_context import DbContext


@dataclass
class Context:

    source: DbContext
    target: DbContext
    universal: Universal

    def __init__(self, context_files: ContextFilePaths) -> None:

        self.source = DbContext.from_files(
            create_paths=context_files.source_creates,
            constraint_paths=context_files.source_constraints,
            mapping_paths=context_files.target_to_source_mappings,
            full_join_path=context_files.source_full_join,
        )

        self.target = DbContext.from_files(
            create_paths=context_files.target_creates,
            constraint_paths=context_files.target_constraints,
            mapping_paths=context_files.source_to_target_mappings,
            full_join_path=context_files.target_full_join,
        )

        self.universal = Universal.from_files(
            attribute_path=context_files.universal_attributes,
            from_mapping_paths=context_files.universal_mappings_from,
            to_mapping_paths=context_files.universal_mappings_to,
            source_ordering_path=context_files.universal_source_ordering,
            target_ordering_path=context_files.universal_target_ordering,
        )

    @classmethod
    def from_dir(cls, file_dir: str) -> Self:
        context_dirs = ContextDir.from_dir(file_dir)
        return cls(ContextFilePaths(context_dirs))

    def generate_target_insert(self):
        result = ""

        source_orderings = self.universal.source_ordering
        target_orderings = list(reversed(self.universal.target_ordering))

        schema = "transducer"  # TODO Hardcoded
        temp_tablename = "temp_table_join"

        # Start
        result += f"""
CREATE OR REPLACE FUNCTION {schema}.target_insert_fn()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
DECLARE
v_loop INT;
BEGIN

SELECT count(*) INTO v_loop from transducer._loop;


IF NOT EXISTS (SELECT * FROM transducer._loop, (SELECT COUNT(*) as rc_value FROM transducer._loop) AS row_count
WHERE ABS(loop_start) = row_count.rc_value) THEN
   RAISE NOTICE 'Wait %', v_loop;
   RETURN NULL;
ELSE
   RAISE NOTICE 'This should conclude with an INSERT on _EMPDEP';
        """

        # Create temp table
        result += "\n" + self.universal.create_sql(temp_tablename, temp=True)

        # TODO Temp Table Join Insert

        full_mapping_tablename = target_orderings[-1]
        full_mapping = self.universal.mappings[full_mapping_tablename].to_sql(
            primary_suffix="_INSERT_JOIN",
            secondary_suffix="_INSERT_JOIN",
            distinct=True,
        )
        result += f"\n\nINSERT INTO {temp_tablename}("
        result += full_mapping
        result += "\n where "
        result += "\n AND ".join(
            map(lambda x: x + " IS NOT NULL", self.universal.attributes)
        )
        result += "\n "
        result += ");"

        # Other inserts

        table = source_orderings[0]
        create_table = self.source.tables[table]

        mapping_str = self.universal.mappings[table].from_sql(
            universal_tablename=temp_tablename
        )
        result += f"""
\nINSERT INTO {schema}.{table} ({mapping_str}) ON CONFLICT ({", ".join(create_table.pkey)}) DO NOTHING;
INSERT INTO {schema}._loop VALUES (-1);
"""

        for table in source_orderings[1:]:
            create_table = self.source.tables[table]
            mapping_str = self.universal.mappings[table].from_sql(
                universal_tablename=temp_tablename
            )
            result += f"""INSERT INTO {schema}.{table} ({mapping_str}) ON CONFLICT ({", ".join(create_table.pkey)}) DO NOTHING;
"""

        # DELETES

        for table in target_orderings:
            result += f"\nDELETE FROM {schema}.{table}_INSERT;"

        result += "\n"

        for table in target_orderings:
            result += f"\nDELETE FROM {schema}.{table}_INSERT_JOIN;"

        result += "\n"

        result += f"""
DELETE FROM {schema}._loop;
DELETE FROM {temp_tablename};
DROP TABLE {temp_tablename};
RETURN NEW;
END IF;
END;    $$;
"""

        return result

    def generate_source_insert(self):

        schema = "transducer"  # TODO Hardcoded

        def get_insert(target: str):
            result = f"INSERT INTO {schema}.{target}"
            table = self.target.tables[target]
            join_tables = list(
                filter(lambda x: x.table != target, self.source.tables.values())
            )
            join_expressions = []
            for join_table in join_tables:
                null_expr = "AND ".join(
                    map(lambda x: x + " IS NOT NULL ", join_table.pkey)
                )
                join_expression = f"\nNATURAL LEFT OUTER JOIN {schema}.{join_table.table}_INSERT_JOIN where {null_expr}"
                join_expressions.append(join_expression)
            join_expression = f"{schema}.{target}_INSERT_JOIN" + "".join(
                join_expressions
            )
            result += (
                " ("
                + self.universal.mappings[target].from_sql(
                    universal_tablename="".join(join_expressions)
                )
                + ")"
            )
            result += f"ON CONFLICT ({', '.join(table.pkey)}) DO NOTHING;"
            return result

        return get_insert("_city_country")

    def generate_target_delete(self):
        return NotImplementedError("Target delete generation is not implemented yet.")
