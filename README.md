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
INSERT INTO `project` (`name`, `owner_id`, `hidden`) VALUES (?, ?, ?);
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
UPDATE `project` SET `name` = ?, `hidden` = ? WHERE `id` = ?
```

`params()` returns:

```coffeescript
['Even more amazing project, true, 7]
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
