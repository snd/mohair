# mohair

[![Build Status](https://travis-ci.org/snd/mohair.png)](https://travis-ci.org/snd/mohair)

mohair is an sql builder for nodejs

### install

    npm install mohair

### use

##### use a table

```coffeescript

mohair = require 'mohair'
mysql = require 'mysql'

data =
  name: 'test'
  create: '2012'
conn = mysql.createConnection
    host: 'localhost'
    database: 'test'
    user: 'root'
    password: '123456'
conn.connect

mohair
  .connect(conn)
  .table('test')
  .insert(data)
  .exec (err, result) ->
    console.log result

```

##### insert a record

mohair
  .connect(conn)
  .table('test')
  .insert(data)
  .exec (err, result) ->
    console.log result
```
##### delete a record

```coffeescript
mohair
  .connect(conn)
  .table('test')
  .where(id:1)
  .delete()
  .exec (err, result) ->
    console.log result

```
##### update

```coffeescript
mohair
  .connect(conn)
  .table('test')
  .where({name: 'foo'})
  .update({name: 'bar'})
  .exec (err, result) ->
    console.log result

```

##### select

```coffeescript
mohair
  .connect(conn)
  .table('test')
  .select()
  .exec (err, result) ->
    console.log result

```


##### select specific fields

```coffeescript
mohair
  .connect(conn)
  .table('test')
  .select('name as n')
  .exec (err, result) ->
    console.log result
```

##### order by
```coffeescript
mohair
  .connect(conn)
  .table('test')
  .select('name as n')
  .order('id desc')
  .exec (err, result) ->
    console.log result
```
##### offset limit
```coffeescript
mohair
  .connect(conn)
  .table('test')
  .select('name as n')
  .order('id desc')
  .limit(20)
  .offset(10)
  .exec (err, result) ->
    console.log result
```
##### join group
```coffeescript
mohair
  .connect(conn)
  .table('test t1')
  .select('name as n')
  .join('LEFT JOIN table t2 ON t1.id = t2.row_id')
  .group('t1.type_id')
  .order('id desc')
  .limit(20)
  .offset(10)
  .exec (err, result) ->
    console.log result
```
