# mohair

[![NPM version](https://badge.fury.io/js/mohair.svg)](http://badge.fury.io/js/mohair)
[![Build Status](https://travis-ci.org/snd/mohair.svg?branch=master)](https://travis-ci.org/snd/mohair/branches)
[![Dependencies](https://david-dm.org/snd/mohair.svg)](https://david-dm.org/snd/mohair)

> mohair is a simple and flexible sql builder with a fluent interface.

[mesa](https://github.com/snd/mesa) builds on top of mohair and adds
methods to execute queries, to declare and include associations (`hasOne`, `belongsTo`, `hasMany`, `hasAndBelongsToMany`) and more:
[go check it out.](https://github.com/snd/mesa)

- [install](#install)
- [use](#use)
    - [require](#require)
    - [specify a table to use](#specify-a-table-to-use)
    - [insert a record](#insert-a-record)
    - [insert with some raw sql](#insert-with-some-raw-sql)
    - [insert multiple records](#insert-multiple-records)
    - [delete](#delete)
    - [update](#update)
    - [update with some raw sql](#update-with-some-raw-sql)
    - [select](#select)
    - [select with subquery](#select-with-subquery)
    - [select without a table](#select-without-a-table)
    - [select with criteria](#select-with-criteria)
    - [order](#order)
    - [limit and offset](#limit-and-offset)
    - [join](#join)
    - [join with criteria](#join-with-criteria)
    - [group](#group)
    - [mixins](#mixins)
    - [extending](#extending)
    - [common table expressions](#common-table-expressions)
- [license: MIT](#license-mit)

## background

## get started

```
npm install mohair
```

**or**

put this line in the dependencies section of your `package.json`:

```
"mohair": "0.12.0"
```

then run:

```
npm install
```

### use

mohair has a fluent interface where every method returns a new object.
no method ever changes the state of the object it is called on.
this enables a functional programming style:

```javascript
var visibleUsers = mohair.table('user').where({is_visible: true});

var updateUser = visibleUsers.update({name: 'bob'}).where({id: 3});
updateUser.sql();       // => 'UPDATE user SET name = ? WHERE (is_visible = ?) AND (id = ?)'
updateUser.params();    // => ['bob', true, 3]

var deleteUser = visibleUsers.where({name: 'alice'}).delete();
deleteUser.sql();       // => 'DELETE FROM user WHERE (is_visible = ?) AND (name = ?)'
deleteUser.params();    // => [true, 'alice']
```

##### require

```javascript
var mohair = require('mohair');
```

##### specify the table to use

```javascript
var userTable = mohair.table('user');
```

##### insert a record

```javascript
var query = userTable.insert({name: 'alice', email: 'alice@example.com'});

query.sql();        // => 'INSERT INTO user(name, email) VALUES (?, ?)'
query.params();     // => ['alice', 'alice@example.com']
```

##### insert with some raw sql

```javascript
var query = userTable.insert({name: 'alice', created_at: mohair.raw('NOW()')});

query.sql();        // => 'INSERT INTO user(name, created_at) VALUES (?, NOW())'
query.params();     // => ['alice']
```

##### insert multiple records

```javascript
var query = userTable.insertMany([{name: 'alice'}, {name: 'bob'}]);

query.sql();        // => 'INSERT INTO user(name) VALUES (?), (?)'
query.params();     // => ['alice', 'bob']
```

all records in the argument array must have the same properties.

##### delete

```javascript
var query = userTable.where({id: 3}).delete();

query.sql();        // => 'DELETE FROM user WHERE id = ?'
query.params();     // => [3]
```

`where` can take any valid [criterion](https://github.com/snd/criterion).

##### update

```javascript
var query = userTable.where({name: 'alice'}).update({name: 'bob'});

query.sql();        // => 'UPDATE user SET name = ? WHERE name = ?'
query.params();     // => ['bob', 'alice']
```

##### update with some raw sql

```javascript
var query = userTable.where({name: 'alice'}).update({age: mohair.raw('LOG(age, ?)', 4)});

query.sql();        // => 'UPDATE user SET age = LOG(age, ?) WHERE name = ?'
query.params();     // => [4, 'alice']
```

`where` can take any valid [criterion](https://github.com/snd/criterion).

##### select

```javascript
var query = userTable.select();

query.sql();        // => 'SELECT * FROM user'
query.params();     // => []
```

you can omit `select()` if you want to select `*`. select is the default action.

```javascript
var query = userTable.select('name, timestamp AS created_at');

query.sql();        // => 'SELECT name, timestamp AS created_at FROM user'
query.params();     // => []
```

```javascript
var query = userTable.select('name', 'timestamp AS created_at');

query.sql();        // => 'SELECT name, timestamp AS created_at FROM user'
query.params();     // => []
```

```javascript
var query = userTable.select('name', {created_at: 'timestamp'});

query.sql();        // => 'SELECT name, timestamp AS created_at FROM user'
query.params();     // => []
```

```javascript
var fragment = mohair.raw('SUM(total_sales/?)', 10);
var query = mohair
    .table('regional_sales')
    .select('region', {summed_sales: fragment});

query.sql();        // => 'SELECT region, (SUM(total_sales/?)) AS summed_sales FROM regional_sales'
query.params();     // => [10]
```

##### select with subquery

```javascript
var subquery = mohair
    .table('order')
    .where('user_id = user.id')
    .select('count(1)');
var query = userTable.select('name', {order_count: subquery});

query.sql();        // => 'SELECT name, (SELECT count(1) FROM order WHERE user_id = user.id) AS order_count FROM user'
query.params();     // => []
```

##### select without a table

```javascript
var query = mohair.select('now()')

query.sql();        // => 'SELECT now()'
query.params();     // => []
```

##### select with criteria

```javascript
var query = userTable.where({id: 3}).where('name = ?', 'alice').select();

query.sql();        // => 'SELECT * FROM user WHERE (id = ?) AND (name = ?)'
query.params();     // => [3, 'alice']
```

`where` can take any valid [criterion](https://github.com/snd/criterion).
multiple calls to `where` are anded together.

##### order

```javascript
var query = userTable.order('created DESC, name ASC').select();

query.sql();        // => 'SELECT * FROM user ORDER BY created DESC, name ASC'
query.params();     // => []
```

##### limit and offset

```javascript
var query = userTable.limit(20).offset(10).select();

query.sql();        // => 'SELECT * FROM user LIMIT ? OFFSET ?'
query.params();     // => [20, 10]
```

##### join

```javascript
var query = userTable.join('JOIN project ON user.id = project.user_id');

query.sql();        // => 'SELECT * FROM user JOIN project ON user.id = project.user_id'
query.params();     // => []
```

##### join with criteria

```javascript
var query = userTable.join('JOIN project ON user.id = project.user_id', {'project.column': {$null: true}});

query.sql();        // => 'SELECT * FROM user JOIN project ON user.id = project.user_id AND (project.column IS NULL)'
query.params();     // => []
```

##### group

```javascript
var query = userTable
    .select('user.*, count(project.id) AS project_count')
    .join('JOIN project ON user.id = project.user_id')
    .group('user.id');

query.sql();        // => 'SELECT user.*, count(project.id) AS project_count FROM user JOIN project ON user.id = project.user_id GROUP BY user.id'
query.params();     // => []
```

##### mixins

```javascript
var paginate = function(page, perPage) {
    return this
        .limit(perPage)
        .offset(page * perPage);
};

var query = mohair.table('posts')
    .mixin(paginate, 10, 100)
    .where(is_public: true);

query.sql();       // => 'SELECT * FROM posts WHERE is_public = ? LIMIT ? OFFSET ?'
query.params();    // => [true, 100, 1000]
```

##### extending

```javascript
var posts = mohair.table('posts');

posts.paginate = function(page, perPage) {
    return this
        .limit(perPage)
        .offset(page * perPage);
};

var query = mohair.table('posts')
    .where(is_public: true)
    .paginate(10, 100);

query.sql();       // => 'SELECT * FROM posts WHERE is_public = ? LIMIT ? OFFSET ?'
query.params();    // => [true, 100, 1000]
```

##### common table expressions

[see the postgres documentation](http://www.postgresql.org/docs/9.2/static/queries-with.html)

```javascript
var regionalSales = mohair
    .select('region, SUM(amount) AS total_sales')
    .table('orders')
    .group('region');

var topRegions = mohair
    .select('region')
    .table('regional_sales')
    .where('total_sales > (SELECT SUM(total_sales/10 FROM regional_sales))');

var query = mohair
    .with(
        regional_sales: regionalSales
        top_regions: topRegions
    )
    .select("""
        region,
        product,
        SUM(quantity) AS product_units,
        SUM(amount) AS product_sales
    """)
    .table('orders')
    .where('region IN (SELECT region FROM top_regions)')
    .group('region, product');
```

```javascript
query.sql();
```

returns

```sql
WITH
regional_sales AS (
    SELECT region, SUM(amount) AS total_sales
    FROM orders
    GROUP BY region
 ), top_regions AS (
    SELECT region
    FROM regional_sales
    WHERE total_sales > (SELECT SUM(total_sales)/10 FROM regional_sales)
 )
SELECT
    region,
    product,
    SUM(quantity) AS product_units,
    SUM(amount) AS product_sales
FROM orders
WHERE region IN (SELECT region FROM top_regions)
GROUP BY region, product;
```

## changelog

### 0.13.0

- now uses criterion@0.4.0: criterion changelog applies to mohair as well [click here to see it](https://github.com/snd/criterion#040)
- `.from()` supports selecting from multiple tables, selecting from subqueries and has syntax for aliases
- `.sql()`
- mohair now conforms to [sql-fragment interface](https://github.com/snd/criterion#the-sql-fragment-interface)
- escapes more things that are escapable: aliases, names for common table expressions, ...
- `.mixin` renamed to `.call`

## [license: MIT](LICENSE)

## TODO

- test returning
  - test returning with params

- test that all parts of the queries get escaped
  - select DONE
  - insert
    - returning
  - update
    - returning
  - delete DONE
    - returning

- join helper for select

- better errors
  - check error message in tests for error conditions
  - test for every possible error condition
  - throw correct errors (`TypeError` for example)
- better `.table`
  - support multiple tables in `.table`
  - support alias syntax `{foo: 'table'}` in `.table`
  - support subqueries in `.table`
  - throw when insert / update / delete with multiple tables
- make `updateFrom` work
  - https://github.com/snd/mohair/pull/29/files
- support insert with subquery
  - `mohair.insert(['a', 'b', 'c'], mohair.table('user').select('id'))`
- better joins
  - think about it !!! ...

- README
  - functional, immutable

- better documentation
- better description
- better keywords

