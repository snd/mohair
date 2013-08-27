mohair = require '../src/mohair'

module.exports =

    'throw on':

        'insert without table': (test) ->
            q = mohair.insert {name: 'foo', email: 'foo@example.com'}
            test.throws -> q.sql()

            test.done()

        'create multiple records without matching keys': (test) ->
            test.throws ->
                mohair.table('user').insertMany [
                    {name: 'foo', email: 'foo@example.com'}
                    {name: 'bar'}
                ]

            test.throws ->
                mohair.table('user').insertMany [
                    {name: 'foo', email: 'foo@example.com'}
                    {name: 'bar', id: 9}
                ]

            test.done()

    'insert':
        'simple': (test) ->
            q = mohair.table('user').insert {name: 'foo', user_id: 5}

            test.equal q.sql(), 'INSERT INTO user(name, user_id) VALUES (?, ?)'
            test.deepEqual q.params(), ['foo', 5]

            test.done()

        'with null values': (test) ->
            q = mohair.table('user').insert {name: 'foo', user_id: null}

            test.equal q.sql(), 'INSERT INTO user(name, user_id) VALUES (?, ?)'
            test.deepEqual q.params(), ['foo', null]

            test.done()

        'with raw without params': (test) ->
            q = mohair.table('user').insert
                name: 'foo',
                user_id: 5
                created_at: mohair.raw('NOW()')

            test.equal q.sql(), 'INSERT INTO user(name, user_id, created_at) VALUES (?, ?, NOW())'
            test.deepEqual q.params(), ['foo', 5]

            test.done()

        'with raw with params': (test) ->
            q = mohair.table('user').insert
                name: 'foo',
                user_id: 5
                created_at: mohair.raw('LOG(x, ?)', 3)

            test.equal q.sql(), 'INSERT INTO user(name, user_id, created_at) VALUES (?, ?, LOG(x, ?))'
            test.deepEqual q.params(), ['foo', 5, 3]

            test.done()

    'insertMany':

        'records with same key order': (test) ->
            q = mohair.table('user').insertMany [
                {name: 'foo', email: 'foo@example.com'}
                {name: 'bar', email: 'bar@example.com'}
                {name: 'baz', email: 'baz@example.com'}
            ]

            test.equal q.sql(),
                'INSERT INTO user(name, email) VALUES (?, ?), (?, ?), (?, ?)'
            test.deepEqual q.params(),
                ['foo', 'foo@example.com', 'bar', 'bar@example.com', 'baz', 'baz@example.com']

            test.done()

        'records with different key order': (test) ->
            q = mohair.table('user').insertMany [
                {name: 'foo', email: 'foo@example.com', age: 16}
                {email: 'bar@example.com', name: 'bar', age: 25}
                {age: 30, name: 'baz', email: 'baz@example.com'}
            ]

            test.equal q.sql(),
                'INSERT INTO user(name, email, age) VALUES (?, ?, ?), (?, ?, ?), (?, ?, ?)'
            test.deepEqual q.params(),
                ['foo', 'foo@example.com', 16, 'bar', 'bar@example.com', 25, 'baz', 'baz@example.com', 30]

            test.done()

        'with raw without params': (test) ->
            q = mohair.table('user').insertMany [
                {
                    name: 'foo',
                    user_id: 5
                    created_at: mohair.raw('BAR()')
                }
                {
                    user_id: 6
                    created_at: mohair.raw('BAZ()')
                    name: 'bar',
                }
                {
                    created_at: mohair.raw('FOO()')
                    name: 'baz',
                    user_id: 7
                }
            ]

            test.equal q.sql(), 'INSERT INTO user(name, user_id, created_at) VALUES (?, ?, BAR()), (?, ?, BAZ()), (?, ?, FOO())'
            test.deepEqual q.params(), ['foo', 5, 'bar', 6, 'baz', 7]

            test.done()

        'with raw with params': (test) ->
            q = mohair.table('user').insertMany [
                {
                    name: 'foo',
                    user_id: 5
                    created_at: mohair.raw('BAR(?, ?, ?)', 10, 11, 12)
                }
                {
                    user_id: 6
                    created_at: mohair.raw('BAZ(?)', 20)
                    name: 'bar',
                }
                {
                    created_at: mohair.raw('FOO(?, ?)', 30, 31)
                    name: 'baz',
                    user_id: 7
                }
            ]

            test.equal q.sql(), 'INSERT INTO user(name, user_id, created_at) VALUES (?, ?, BAR(?, ?, ?)), (?, ?, BAZ(?)), (?, ?, FOO(?, ?))'
            test.deepEqual q.params(), ['foo', 5, 10, 11, 12, 'bar', 6, 20, 'baz', 7, 30 ,31]

            test.done()

    'delete':

        'without criteria': (test) ->
            q = mohair.table('user').delete()

            test.equal q.sql(), 'DELETE FROM user'
            test.deepEqual q.params(), []

            test.done()

        'with criteria': (test) ->
            q = mohair.table('user')
                .delete()
                .where('x BETWEEN ? AND ?', 50, 55)
                .where($or: {x: 10, y: 6})

            test.equal q.sql(), 'DELETE FROM user WHERE (x BETWEEN ? AND ?) AND ((x = ?) OR (y = ?))'
            test.deepEqual q.params(), [50, 55, 10, 6]

            test.done()

    'update':

        'without criteria': (test) ->
            q = mohair.table('user').update {name: 'bar', email: 'bar@example.com'}

            test.equal q.sql(), 'UPDATE user SET name = ?, email = ?'
            test.deepEqual q.params(), ['bar', 'bar@example.com']

            test.done()

        'with criteria': (test) ->
            q = mohair.table('user')
                .where(id: 3, x: 5)
                .update {name: 'bar', email: 'bar@example.com'}

            test.equal q.sql(), 'UPDATE user SET name = ?, email = ? WHERE (id = ?) AND (x = ?)'
            test.deepEqual q.params(), ['bar', 'bar@example.com', 3, 5]

            test.done()

        'with raw without params': (test) ->
            q = mohair.table('user')
                .where(id: 3, x: 5)
                .update {
                    name: 'foo',
                    user_id: 6
                    modified_at: mohair.raw('NOW()')
                }

            test.equal q.sql(), 'UPDATE user SET name = ?, user_id = ?, modified_at = NOW() WHERE (id = ?) AND (x = ?)'
            test.deepEqual q.params(), ['foo', 6, 3, 5]

            test.done()

        'with raw with params': (test) ->
            q = mohair.table('user')
                .where(id: 3, x: 5)
                .update {
                    name: 'foo',
                    user_id: mohair.raw('LOG(user_id, ?)', 4)
                    modified_at: mohair.raw('NOW()')
                }

            test.equal q.sql(), 'UPDATE user SET name = ?, user_id = LOG(user_id, ?), modified_at = NOW() WHERE (id = ?) AND (x = ?)'
            test.deepEqual q.params(), ['foo', 4, 3, 5]

            test.done()

        'with null values': (test) ->
            q = mohair.table('user').update {name: 'foo', user_id: null}

            test.equal q.sql(), 'UPDATE user SET name = ?, user_id = ?'
            test.deepEqual q.params(), ['foo', null]

            test.done()

    'select':

        'default is select *': (test) ->
            q = mohair.table('user')

            test.equal q.sql(), 'SELECT * FROM user'
            test.deepEqual q.params(), []

            test.done()

        'all fields': (test) ->
            q = mohair.table('user').select()

            test.equal q.sql(), 'SELECT * FROM user'
            test.deepEqual q.params(), []

            test.done()

        'specific fields': (test) ->
            q = mohair.table('user').select('name, timestamp AS created_at')

            test.equal q.sql(), 'SELECT name, timestamp AS created_at FROM user'
            test.deepEqual q.params(), []

            test.done()

        'specific fields provided individually': (test) ->
            q = mohair.table('user').select('name', 'timestamp AS created_at')

            test.equal q.sql(), 'SELECT name, timestamp AS created_at FROM user'
            test.deepEqual q.params(), []

            test.done()

        'with object': (test) ->
            q = mohair.table('user').select('name', {created_at: 'timestamp'})

            test.equal q.sql(), 'SELECT name, timestamp AS created_at FROM user'
            test.deepEqual q.params(), []

            test.done()

        'with raw': (test) ->
            q = mohair.table('user').select('name', mohair.raw('count/?', 10))

            test.equal q.sql(), 'SELECT name, (count/?) FROM user'
            test.deepEqual q.params(), [10]

            test.done()

        'with raw and object': (test) ->
            q = mohair.table('user').select('name', {number: mohair.raw('count/?', 10)})

            test.equal q.sql(), 'SELECT name, (count/?) AS number FROM user'
            test.deepEqual q.params(), [10]

            test.done()

        'with subquery': (test) ->
            subquery = mohair
                .table('order')
                .where('user_id = user.id')
                .where('price > ?', 10)
                .select('count(1)')
            q = mohair
                .table('user')
                .select('name', {order_count: subquery})

            test.equal q.sql(), 'SELECT name, (SELECT count(1) FROM order WHERE (user_id = user.id) AND (price > ?)) AS order_count FROM user'
            test.deepEqual q.params(), [10]

            test.done()

        'without table': (test) ->
            q = mohair.select('now()')

            test.equal q.sql(), 'SELECT now()'
            test.deepEqual q.params(), []

            test.done()

        'with criteria': (test) ->
            q = mohair.table('user').where(id: 3).select()

            test.equal q.sql(), 'SELECT * FROM user WHERE id = ?'
            test.deepEqual q.params(), [3]

            test.done()

        'criteria are anded together': (test) ->
            q = mohair.table('user').where(id: 3).where('name = ?', 'foo').select()

            test.equal q.sql(), 'SELECT * FROM user WHERE (id = ?) AND (name = ?)'
            test.deepEqual q.params(), [3, 'foo']

            test.done()

        'order': (test) ->
            q = mohair.table('user').order('created DESC, name ASC')

            test.equal q.sql(), 'SELECT * FROM user ORDER BY created DESC, name ASC'
            test.deepEqual q.params(), []

            test.done()

        'limit': (test) ->
            q = mohair.table('user').limit(10)

            test.equal q.sql(), 'SELECT * FROM user LIMIT ?'
            test.deepEqual q.params(), [10]

            test.done()

        'offset': (test) ->
            q = mohair.table('user').offset(5)

            test.equal q.sql(), 'SELECT * FROM user OFFSET ?'
            test.deepEqual q.params(), [5]

            test.done()

        'join': (test) ->
            q = mohair.table('user')
                .join('JOIN project ON user.id = project.user_id')

            test.equal q.sql(), 'SELECT * FROM user JOIN project ON user.id = project.user_id'
            test.deepEqual q.params(), []

            test.done()

        'join with object criterion': (test) ->
            q = mohair.table('user')
                .join('JOIN project ON user.id = project.user_id', {'project.foo': {$null: true}, 'project.bar': 10})

            test.equal q.sql(),
                'SELECT * FROM user JOIN project ON user.id = project.user_id AND ((project.foo IS NULL) AND (project.bar = ?))'
            test.deepEqual q.params(), [10]

            test.done()

        'join with sql criterion': (test) ->
            q = mohair.table('user')
                .join('JOIN project ON user.id = project.user_id', 'project.foo = ?', 4)

            test.equal q.sql(),
                'SELECT * FROM user JOIN project ON user.id = project.user_id AND (project.foo = ?)'
            test.deepEqual q.params(), [4]

            test.done()

        'multiple joins': (test) ->
            q = mohair.table('user')
                .join('OUTER JOIN project ON user.id = project.user_id', 'project.foo = ?', 4)
                .join('INNER JOIN task ON project.id = task.project_id', {'task.bar': 10})

            test.equal q.sql(),
                'SELECT * FROM user OUTER JOIN project ON user.id = project.user_id AND (project.foo = ?) INNER JOIN task ON project.id = task.project_id AND (task.bar = ?)'
            test.deepEqual q.params(), [4, 10]

            test.done()

        'group': (test) ->
            q = mohair.table('user')
                .select('user.*, count(project.id) AS project_count')
                .join('JOIN project ON user.id = project.user_id')
                .group('user.id')

            test.equal q.sql(), 'SELECT user.*, count(project.id) AS project_count FROM user JOIN project ON user.id = project.user_id GROUP BY user.id'
            test.deepEqual q.params(), []

            test.done()

        'everything together': (test) ->
            q = mohair.table('user')
                .select('user.*, count(project.id) AS project_count')
                .where(id: 3)
                .where('name = ?', 'foo')
                .join('JOIN project ON user.id = project.user_id')
                .group('user.id')
                .order('created DESC, name ASC')
                .limit(10)
                .offset(20)

            test.equal q.sql(), 'SELECT user.*, count(project.id) AS project_count FROM user JOIN project ON user.id = project.user_id WHERE (id = ?) AND (name = ?) GROUP BY user.id ORDER BY created DESC, name ASC LIMIT ? OFFSET ?'
            test.deepEqual q.params(), [3, 'foo', 10, 20]

            test.done()

    'actions overwrite previous actions': (test) ->
        chain = mohair.table('user')
            .where(id: 3)
            .select('name')

        query = chain.insert(name: 'foo').table('project')

        test.equal chain.sql(), 'SELECT name FROM user WHERE id = ?'
        test.deepEqual chain.params(), [3]

        test.equal query.sql(), 'INSERT INTO project(name) VALUES (?)'
        test.deepEqual query.params(), ['foo']

        test.done()

    'immutability': (test) ->
        visible = mohair.table('project').where(is_visible: true)

        updateQuery = visible.update({name: 'i am visible'}).where(id: 3)
        test.equal updateQuery.sql(),
            'UPDATE project SET name = ? WHERE (is_visible = ?) AND (id = ?)'
        test.deepEqual updateQuery.params(), ['i am visible', true, 3]

        deleteQuery = visible.where({name: 'foo'}).delete()

        test.equal deleteQuery.sql(),
            'DELETE FROM project WHERE (is_visible = ?) AND (name = ?)'
        test.deepEqual deleteQuery.params(), [true, 'foo']

        test.done()

    'escape':
        'select': (test) ->
            query = mohair
                .escape((string) -> "\"#{string}\"")
                .table('project')
                .where(is_visible: true)

            test.equal query.sql(),
                'SELECT * FROM "project" WHERE is_visible = ?'
            test.deepEqual query.params(), [true]

            test.done()

        'insert': (test) ->
            query = mohair
                .escape((string) -> "\"#{string}\"")
                .table('project')
                .insert {first_key: 'first_value', second_key: 'second_value'}

            test.equal query.sql(),
                'INSERT INTO "project"("first_key", "second_key") VALUES (?, ?)'
            test.deepEqual query.params(), ['first_value', 'second_value']

            test.done()

        'update': (test) ->
            query = mohair
                .escape((string) -> "\"#{string}\"")
                .table('project')
                .update {first_key: 'first_value', second_key: 'second_value'}

            test.equal query.sql(),
                'UPDATE "project" SET "first_key" = ?, "second_key" = ?'
            test.deepEqual query.params(), ['first_value', 'second_value']

            test.done()

    'common table expressions':
        example: (test) ->
            regionalSales = mohair
                .select('region, SUM(amount) AS total_sales')
                .table('orders')
                .group('region')

            topRegions = mohair
                .select('region')
                .table('regional_sales')
                .where('total_sales > (SELECT SUM(total_sales)/10 FROM regional_sales)')

            query = mohair
                .with(
                    regional_sales: regionalSales
                    top_regions: topRegions
                )
                .select("region, product, SUM(quantity) AS product_units, SUM(amount) AS product_sales")
                .table('orders')
                .where('region IN (SELECT region FROM top_regions)')
                .group('region, product')

            expected = "WITH regional_sales AS (SELECT region, SUM(amount) AS total_sales FROM orders GROUP BY region), top_regions AS (SELECT region FROM regional_sales WHERE total_sales > (SELECT SUM(total_sales)/10 FROM regional_sales)) SELECT region, product, SUM(quantity) AS product_units, SUM(amount) AS product_sales FROM orders WHERE region IN (SELECT region FROM top_regions) GROUP BY region, product"

            test.equals query.sql(), expected
            test.deepEqual query.params(), []

            test.done()

        params: (test) ->
            regionalSales =
                sql: -> 'regional_sales'
                params: -> [1, 2, 3]

            topRegions =
                sql: -> 'top_regions'
                params: -> [4, 5, 6]

            query = mohair
                .with(
                    regional_sales: regionalSales
                    top_regions: topRegions
                )
                .table('orders')
                .where('type = ?', 'test')

            expected = "WITH regional_sales AS (regional_sales), top_regions AS (top_regions) SELECT * FROM orders WHERE type = ?"

            test.equals query.sql(), expected
            test.deepEqual query.params(), [1, 2, 3, 4, 5, 6, 'test']

            test.done()
