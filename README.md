# mohair

sql query builder for nodejs

*write elegant code to generate sql queries - instead of concatenating strings and pushing to endless parameter lists*

### Install

    npm install mohair

### Use mohair with node-mysql

```coffeescript

mysql = require 'mysql'

connection = mysql.createConnection
    user: 'mysql-username'
    password: 'mysql-password'
    database: 'mysql-database'

connection.connect()

m = require('mohair')()

m.insert 'project',
    name: 'Amazing Project'
    owner_id: 5
    hidden: false

client.query m.sql(), m.params(), (err, result) ->
    throw err if err?
    console.log result

client.end()
```

### Queries

#### insert a single row

```coffeescript
m = require('mohair')()

m.insert 'project',
    name: 'Amazing Project'
    owner_id: 5
    hidden: false
```

`m.sql()` returns:

```sql
INSERT INTO `project` (`name`, `owner_id`, `hidden`) VALUES (?, ?, ?);
```

`m.params()` returns:

```coffeescript
['Amazing Project', 5, false]
```

#### insert multiple rows at once

```coffeescript
{insert, sql, params} = require('mohair')()

insert 'project', [
    {name: 'First project', hidden: true},
    {name: 'Second project', hidden: false}
]
```

`sql()` returns:

```sql
INSERT INTO `project` (`name`, `hidden`) VALUES (?, ?), (?, ?);
```

`params()` returns:

```coffeescript
['First project', true, 'Second project', false]
```

**Note:** all inserted objects must have the same keys.

#### call some sql function inside the insert

```coffeescript
m = require('mohair')()

m.insert 'project',
    name: 'Another Project'
    created_on: -> m.raw 'NOW()'
    user_id: -> m.raw 'LAST_INSERT_ID()'
```

`m.sql()` returns:

```sql
INSERT INTO `project` (`name,` `created_on`, `user_id`) VALUES (?, NOW(), LAST_INSERT_ID());
```

`m.params()` returns:

```coffeescript
['Another Project']
```

#### upsert

```coffeescript
m = require('mohair')()

m.upsert 'project', {id: 'foo'},
    name: 'bar'
```

`m.sql()` returns:

```sql
INSERT INTO `project` (`id`, `name`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `id` = ?, `name` = ?;
```

`m.params()` returns:

```coffeescript
['foo', 'bar', 'foo', 'bar']
```

**Note:** the first argument is a seperate mapping for the key of the table.
It isn't needed for the special mysql syntax `ON DUPLICATE KEY UPDATE` but for upserts in postgres.

#### update a row

```coffeescript
m = require('mohair')()

m.update 'project', {
    name: 'Even more amazing project'
    hidden: true
}, {id: 7}
```

**Note:** the last argument is a query object. see section `Query language` below for details.

`m.sql()` returns:

```sql
UPDATE `project` SET `name` = ?, `hidden` = ? WHERE `id` = ?;
```

`m.params()` returns:

```coffeescript
['Even more amazing project', true, 7]
```

#### select everything

```coffeescript
m = require('mohair')()

m.select 'project'
```

`m.sql()` returns:

```sql
SELECT * FROM `project`;
```

`m.params()` returns:

```coffeescript
[]
```

#### select specific columns with a condition

```coffeescript
m = require('mohair')()

m.select 'project', ['name', 'id'], {hidden: true}
```

**Note:** the last argument is a query object. see section `Query language` below for details.

**Note:** the second argument can also be a string.

`m.sql()` returns:

```sql
SELECT name, id FROM `project` WHERE `hidden` = ?;
```

`m.params()` returns:

```coffeescript
[true]
```

#### join, groupBy and orderBy

```coffeescript
m = require('mohair')()

m.select 'project', ['count(task.id) AS taskCount', 'project.*'], ->
    m.leftJoin 'task', 'project.id' , 'task.project_id'
    m.where {'project.visible': true}
    m.groupBy 'project.id'
    m.orderBy {$desc: 'project.created_on'}
    m.limit 5
    m.skip -> m.raw '6'
```

`m.sql()` returns:

```sql
SELECT
    count(task.id) AS taskCount,
    project.*
FROM `project`
LEFT JOIN `task` ON `project`.`id` = `task`.`project_id`
WHERE `project`.`visible` = ?
GROUP BY `project`.`id`
ORDER BY `project`.`created_on` DESC
LIMIT ?
SKIP 6;
```

`m.params()` returns:

```coffeescript
[true, 5]
```

**Note:** use `join`, `leftJoin`, `rightJoin`, and `innerJoin` as needed.

**Note:** `orderBy` can also take an array of orderings.
an ordering is either the fieldname as a string or an object
describing the direction like this: `{$desc: 'fieldname'}` or `{$asc: 'fieldname'}`.

**Note:** `where` takes a query object. see section `Query language` below for details.

#### delete

```coffeescript
m = require('mohair')()

m.delete 'project', {id: 7, hidden: true}
```

`m.sql()` returns:

```sql
DELETE FROM `project` WHERE `id` = ? AND `hidden` = ?;
```

`m.params()` returns:

```coffeescript
[7, true]
```

**Note:** the last argument is a query object. see section `Query language` below for details.

#### transactions

```coffeescript
m = require('mohair')()

m.transaction ->
    m.remove 'project', {id: 7}
    m.update 'project', {name: 'New name'}, {id: 8}
```

`m.sql()` returns:

```sql
BEGIN;
DELETE FROM `project` WHERE `id` = ?;
UPDATE `project` SET `name` = ? WHERE `id` = ?;
COMMIT;
```

`m.params()` returns:

```coffeescript
[7, 'New name', 8]
```
#### fall back to raw sql with optional parameter bindings

```coffeescript
m = require('mohair')()

m.raw 'SELECT * FROM `project` WHERE `id` = ?;', 7
```

`m.sql()` returns:

```sql
SELECT * FROM `project` WHERE `id` = ?;
```

`m.params()` returns:

```coffeescript
[7]
```

### Query language

inspired by the [mongo query language](http://www.mongodb.org/display/DOCS/Advanced+Queries)

#### query objects

sql is generated from query objects by using the keys as column names,
binding or calling the values and interspersing 'AND':

```coffeescript
m = require('mohair')()

m.query
    id: 7
    hidden: true
    name: -> m.quoted 'Another project'
```

`m.sql()` returns:

```sql
`id` = ? AND `hidden` = ? AND `name` = 'Another project'
```

`m.params()` returns:

```coffeescript
[7, true]
```

#### comparison operators

you can change the default comparison operator '=' as follows:

```coffeescript
m = require('mohair')()

m.query
    id: 7
    name: {$ne: -> quoted 'Another project'}
    owner_id: {$lt: 10}
    category_id: {$lte: 4}
    deadline: {$gt: -> m.raw 'NOW()'}
    cost: {$gte: 7000}
```

`m.sql()` returns:

```sql
`id` = ? AND
`name` != 'Another project' AND
`owner_id` < ? AND
`category_id` <= ? AND
`deadline` > NOW() AND
`cost` >= ?
```

`params()` returns:

```coffeescript
[7, 10, 4, 7000]
```

##### $in

select rows where column `id` has one of the values: `3, 5, 8, 9`:

```coffeescript
m = require('mohair')()

m.query
    id: {$in: [3, 5, 8, 9]}
```

`m.sql()` returns:

```sql
`id` IN (?, ?, ?, ?)
```

`m.params()` returns:

```coffeescript
[3, 5, 8, 9]
```

##### $nin = not in

##### $not

the special key `$not` takes a query object and negates it:

```coffeescript
m = require('mohair')()

m.query
    $not: {id: {$in: [3, 5, 8, 9]}}
```

`m.sql()` returns:

```sql
NOT (`id` IN (?, ?, ?, ?))
```

`m.params()` returns:

```coffeescript
[3, 5, 8, 9]
```

##### $or

the special key `$or` takes an array of query objects and generates a querystring
where only one of the queries must match:

```coffeescript
m = require('mohair')()

m.query
    $or: [
        {id: 7}
        {name: -> quoted 'Another project'}
        {owner_id: 10}
    ]
```

`m.sql()` returns:

```sql
`id` = ? OR `name` = 'Another project' OR `owner_id` = ?
```

`m.params()` returns:

```coffeescript
[7, 10]
```

##### $nor

shorthand for `{$not: {$or: ...}}`

##### $and

the special key `$and` takes an array of query objects and generates a querystring
where all of the queries must match.
`$and` and `$or` can be nested:

```coffeescript
m = require('mohair')()

m.query
    id: 7
    $or: [
        {owner_id: 10}
        $and: [
            {cost: {$gt: 500}}
            {cost: {$lt: 1000}}
        ]
    ]
```

`m.sql()` returns:

```sql
`id` = ? AND (`owner_id` = ? OR `cost` > ? AND `cost` < ?)
```

`m.params()` returns:

```coffeescript
[7, 10, 500, 1000]
```

### License: MIT
