# mohair

sql builder

[the readme for version 0.7.6 is still available here](https://github.com/snd/mohair/tree/7f6da92158ecbbc09fd45b03b94124f9a833a2a2)

### install

    npm install mohair

### use

##### use a table

```coffeescript
mohair = require 'mohair'

user = mohair.table 'user'  # will be used in all the following examples
```

##### insert a record

```coffeescript
query = user.insert {name: 'foo', email: 'foo@example.com'}

query.sql()     # 'INSERT INTO user(name, email) VALUES (?, ?)'
query.params()  # ['foo', 'foo@example.com']
```

##### insert multiple records

```coffeescript
query = user.insert [{name: 'foo'}, {name: 'bar'}]

query.sql()     # 'INSERT INTO user(name) VALUES (?), (?)'
query.params()  # ['foo', 'bar']
```

all records in the argument array must have the same keys.

##### update

```coffeescript
query = user.where({name: 'foo'}).update({name: 'bar'})

query.sql()     # 'UPDATE user SET name = ? WHERE name = ?'
query.params()  # ['bar', 'foo']
```

`where` can take any valid [criterion](https://github.com/snd/criterion).

##### delete

```coffeescript
user.where(id: 3).delete()

query.sql()     # 'DELETE FROM user WHERE id = ?'
query.params()  # [3]
```

##### select

```coffeescript
query = user.select()

query.sql()       # 'SELECT * FROM user'
query.params()    # []
```

you can omit `select()` if you want to select `*` since select is the default action.

##### select specific fields

```coffeescript
query = user.select('name, timestamp AS created_at')

query.sql()     # 'SELECT name, timestamp AS created_at FROM user'
query.params()  # []
```

##### select with criteria

```coffeescript
query = user.where(id: 3).where('name = ?', 'foo').select()

query.sql()   # 'SELECT * FROM user WHERE id = ? AND name = ?'
query.params()    # [3, 'foo']
```

multiple calls to `where` are anded together.

##### order

```coffeescript
query = user.order('created DESC, name ASC').select()

query.sql()     # 'SELECT * FROM user ORDER BY created DESC, name ASC'
query.params()  # []
```

##### limit and offset

```coffeescript
query = user.limit(20).offset(10).select()

query.sql()     # 'SELECT * FROM user LIMIT ? offset ?'
query.params()  # [20, 10]
```

##### join

```coffeescript
query = user.join('JOIN project ON user.id = project.user_id')

query.sql()     # 'SELECT * FROM user JOIN user ON user.id = project.user_id'
query.params()  # []
```

##### group

```coffeescript
query = user
    .select('user.*, count(project.id) AS project_count')
    .join('JOIN project ON user.id = project.user_id')
    .group('user.id')

query.sql()
# 'SELECT user.*, count(project.id) AS project_count FROM user JOIN project ON user.id = project.user_id GROUP BY user.id'
query.params()
# []
```

#### immutability

mohair objects are immutable.
every method call returns a new object.
no method call ever changes the state of the object it is called on.

this means you can do stuff like this:

```coffeescript
visible = mohair.table('user').where(is_visible: true)

updateQuery = visible.update({name: 'i am visible'}).where(id: 3)
updateQuery.sql()       # 'UPDATE user SET name = ? WHERE is_visible = ? AND id = ?'
updateQuery.params()    # ['i am visible', true, 3]

deleteQuery = visible.where({name: 'foo'}).delete()

deleteQuery.sql()       # 'DELETE FROM user WHERE is_visible = ? AND name = ?'
deleteQuery.params()    # [true, 'foo']
```

all query methods can be chained at will!

#### license: MIT
