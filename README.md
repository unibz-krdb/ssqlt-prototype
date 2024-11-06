# Semantic SQL Transducer Prototype

This is a Python-based prototype for the [Semantic SQL Transducer](https://github.com/unibz-krdb/SemanticSQLTransducer).

## Requirements

- [Python3.8](https://www.python.org/) or greater 
- [PostgreSQL](https://www.postgresql.org/)

## Usage

*Setup*

```shell
python3 -m venv venv
./venv/bin/activate
pip3 install .
```

*Testing*

```shell
pytest
```

## Explanation

### Input

#### Structure

SQL files are taken as input to the program. 
The basic structure is as follows.

```
input
L constraints
|   L source
|   L target
L create
|   L source
|   L target
L mappings
    L source
    L target
```

#### Naming

There is a strict naming convention for the inputted SQL files.
This is so metadata can be stored within the name itself, removing the need for an additional metadata file.

*constraints*

```
%SCHEMA%.%TABLENAME%.%TYPE%.%ID%.%INSERT/DELETE%.sql
```

*create*

```
%SCHEMA%.%TABLENAME%.sql
```

*mappings*

```
%SCHEMA%.%TARGET%.%SOURCE1%.%SOURCE2%.%SOURCEN%.sql
```

#### Example

Check `test/resources/input` for an example input directory.
Running `pytest` will execute the Semantic SQL Transudcer on this directory, resulting in `output.sql` being produced in the project directory.