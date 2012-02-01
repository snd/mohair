# mohair

sql query builder for nodejs

**very early alpha, the api will most likely change a lot!**

## Usage

### insert

```coffeescript
{insert, sql, params} = require('mohair')()

insert 'project',
    name: 'Amazing Project'
    owner_id: 5
    hidden: false
```

`sql()` returns:

```sql
INSERT INTO project (name, owner_id, hidden) VALUES (?, ?, ?);
```

`params()` returns:

```coffeescript
['Amazing Project', 5, false]
```

### update

```coffeescript
mohair = {update, where, sql, params} = require('mohair')()

changes =
    name: 'Even more amazing project'
    hidden: true

update 'project', changes, ->
    where -> mohair.eq 'id', 7
```

`sql()` returns:

```sql
UPDATE project SET name = ?, hidden = ? WHERE id = ?;
```

`params()` returns:

```coffeescript
['Even more amazing project, true, 7]
```

### select

#### implicit star

```coffeescript
mohair = {select, sql, params} = require('mohair')()

select 'project'
```

`sql()` returns:

```sql
SELECT * FROM project;
```

`params()` returns:

```coffeescript
[]
```

#### explicit column list and where clause

```coffeescript
mohair = {select, where, sql, params} = require('mohair')()

select 'project', ['name', 'id'], -> where 'hidden', true
```

`sql()` returns:

```sql
SELECT name, id FROM project WHERE hidden = ?;
```

`params()` returns:

```coffeescript
[true]
```

#### join and group by

```coffeescript
mohair = {select, join, group, sql, params} = require('mohair')()

select 'project', ['count(task.id) AS taskCount', 'project.*'], ->
    join.left 'task', 'project.id' , 'task.project_id'
    group 'project.id'
```

**Note:** use `join`, `join.left`, `join.right`, and `join.inner` as needed.

`sql()` returns:

```sql
SELECT
    count(task.id) AS taskCount,
    project.*
FROM project
LEFT JOIN task ON project.id = task.project_id
GROUP BY project.id;
```

`params()` returns:

```coffeescript
[]
```

### delete

```coffeescript
mohair = {delete, where, sql, params} = require('mohair')()

delete 'project', ->
    where ->
        mohair.eq 'id', 7
        mohair.and()
        mohair.eq 'hidden', true
```

`sql()` returns:

```sql
DELETE FROM project WHERE id = ? AND hidden = ?;
```

`params()` returns:

```coffeescript
[7, true]
```

## Examples

### use it with node-mysql

```coffeescript

mysql = require 'mysql'

client = mysql.createClient
    user: 'root'
    password: 'root'

{insert, sql, params} = require('mohair')()

insert 'project',
    name: 'Amazing Project'
    owner_id: 5
    hidden: false

client.query sql(), params(), (err, result) ->
    console.log result
```
